/*
 * Copyright (C) 2026 Anupam Sengupta <anupamsg@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Anupam Sengupta <anupamsg@gmail.com>
 */

#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>
#include <gdk/macos/gdkmacos.h>

#include "macos-window.h"
#import <objc/runtime.h>

/* Height of GTK's header bar, in points.  The titlebar is made this tall and
 * the buttons are centred in it, so they line up with the toolbar items. */
static int header_height = 0;

static void
center_standard_buttons (NSWindow *win)
{
  if (header_height <= 0)
    return;

  NSView *titlebar  = [[win standardWindowButton: NSWindowCloseButton] superview];
  NSView *container = [titlebar superview];
  NSView *frame     = [container superview];
  if (titlebar == nil || container == nil || frame == nil)
    return;

  NSRect rect = [container frame];
  rect.size.height = header_height;
  rect.origin.y    = [frame bounds].size.height - header_height;
  [container setFrame: rect];
  [titlebar setFrame: [container bounds]];

  NSWindowButton buttons[] = { NSWindowCloseButton, NSWindowMiniaturizeButton, NSWindowZoomButton };
  for (int i = 0; i < 3; i++)
    {
      NSButton *button = [win standardWindowButton: buttons[i]];
      NSRect    f      = [button frame];
      [button setFrameOrigin: NSMakePoint (f.origin.x, ([titlebar bounds].size.height - f.size.height) / 2)];
    }
}

/* GDK hides the standard buttons of its borderless windows, and does so again
 * whenever the window changes state, so show them after each such change. */
static void
show_standard_buttons (NSWindow *win)
{
  if (([win styleMask] & NSWindowStyleMaskFullScreen) != 0)
    return;

  NSWindowButton buttons[] = { NSWindowCloseButton, NSWindowMiniaturizeButton, NSWindowZoomButton };
  for (int i = 0; i < 3; i++)
    {
      NSButton *button = [win standardWindowButton: buttons[i]];
      [button setHidden: NO];
      [button setAlphaValue: 1.0];
    }
  center_standard_buttons (win);
}

/* GDK starts a window move from the header bar by calling AppKit's
 * performWindowDragWithEvent: with the last event it saw.  On current macOS that
 * call does not move the window (or moves it a few points and stalls), so the
 * header bar cannot be used to move the window.  Follow the pointer ourselves
 * instead: remember where the pointer and the window were, and place the window
 * at the same offset until the mouse button is released. */
static id window_move_monitor = nil;

static void
install_window_drag_fix (NSWindow *win)
{
  static BOOL installed = NO;
  if (installed)
    return;
  installed = YES;

  Class cls = [win class];
  Method method = class_getInstanceMethod (cls, @selector (beginManualMove));
  if (method == NULL)
    return;
  Ivar in_move   = class_getInstanceVariable (cls, "inMove");
  Ivar in_manual = class_getInstanceVariable (cls, "inManualMove");
  Ivar in_resize = class_getInstanceVariable (cls, "inManualResize");
  if (in_move == NULL || in_manual == NULL || in_resize == NULL)
    return;

  method_setImplementation (method, imp_implementationWithBlock (^(id self_) {
    char *base = (char *) (__bridge void *) self_;
    if (*(BOOL *) (base + ivar_getOffset (in_move)) ||
        *(BOOL *) (base + ivar_getOffset (in_manual)) ||
        *(BOOL *) (base + ivar_getOffset (in_resize)) ||
        window_move_monitor != nil)
      return;

    NSWindow *window = (NSWindow *) self_;
    NSPoint   start  = [NSEvent mouseLocation];
    NSPoint   origin = [window frame].origin;

    /* GDK swallows the drag events while this is set and clears it on mouse-up */
    *(BOOL *) (base + ivar_getOffset (in_manual)) = YES;

    window_move_monitor = [NSEvent addLocalMonitorForEventsMatchingMask: (NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp)
                                                                handler: ^NSEvent *(NSEvent *event) {
      BOOL finished = ([event type] == NSEventTypeLeftMouseUp) || (([NSEvent pressedMouseButtons] & 1) == 0);
      if ([event type] == NSEventTypeLeftMouseDragged && !finished)
        {
          NSPoint now   = [NSEvent mouseLocation];
          NSRect  frame = [window frame];
          frame.origin  = NSMakePoint (origin.x + (now.x - start.x), origin.y + (now.y - start.y));
          [window setFrame: [window constrainFrameRect: frame toScreen: [window screen]] display: NO];
          return nil;
        }
      if (finished)
        {
          [NSEvent removeMonitor: window_move_monitor];
          window_move_monitor = nil;
        }
      return event;
    }];
  }));
}

gboolean
minder_macos_window_use_native_controls (GtkWindow *window)
{
  static NSMutableSet *observed = nil;

  @autoreleasepool
    {
      GtkNative  *native  = GTK_NATIVE (window);
      GdkSurface *surface = (native != NULL) ? gtk_native_get_surface (native) : NULL;
      if (surface == NULL || !GDK_IS_MACOS_SURFACE (surface))
        return FALSE;

      NSWindow *win = (__bridge NSWindow *) gdk_macos_surface_get_native_window (GDK_MACOS_SURFACE (surface));
      if (win == nil)
        return FALSE;

      install_window_drag_fix (win);

      [win setStyleMask: [win styleMask] | NSWindowStyleMaskTitled
                                         | NSWindowStyleMaskClosable
                                         | NSWindowStyleMaskMiniaturizable
                                         | NSWindowStyleMaskResizable
                                         | NSWindowStyleMaskFullSizeContentView];
      [win setTitlebarAppearsTransparent: YES];
      [win setTitleVisibility: NSWindowTitleHidden];
      show_standard_buttons (win);

      if (observed == nil)
        observed = [[NSMutableSet alloc] init];
      if (![observed containsObject: [NSValue valueWithNonretainedObject: win]])
        {
          [observed addObject: [NSValue valueWithNonretainedObject: win]];
          NSArray<NSNotificationName> *names = @[ NSWindowDidExitFullScreenNotification,
                                                  NSWindowDidResizeNotification,
                                                  NSWindowDidBecomeKeyNotification,
                                                  NSWindowDidEndLiveResizeNotification ];
          for (NSNotificationName name in names)
            {
              [[NSNotificationCenter defaultCenter]
                addObserverForName: name
                            object: win
                             queue: [NSOperationQueue mainQueue]
                        usingBlock: ^(NSNotification *note) {
                          NSWindow *w = note.object;
                          /* GDK hides them after the notification, so wait a turn */
                          dispatch_async (dispatch_get_main_queue (), ^{ show_standard_buttons (w); });
                        }];
            }
        }
      return TRUE;
    }
}

void
minder_macos_set_reopen_handler (MinderReopenFunc callback, gpointer user_data)
{
  id delegate = [NSApp delegate];
  if (delegate == nil || callback == NULL)
    return;

  /* GTK's application delegate does not implement the reopen event */
  SEL sel = @selector (applicationShouldHandleReopen:hasVisibleWindows:);
  BOOL (^block) (id, NSApplication *, BOOL) = ^BOOL (id self_, NSApplication *app, BOOL has_visible) {
    if (!has_visible)
      callback (user_data);
    return YES;
  };
  IMP imp = imp_implementationWithBlock (block);
  if (!class_addMethod ([delegate class], sel, imp, "c@:@c"))
    class_replaceMethod ([delegate class], sel, imp, "c@:@c");
}

void
minder_macos_register_bundled_fonts (void)
{
  @autoreleasepool
    {
      NSString *dir = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"fonts"];
      NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: dir error: nil];
      for (NSString *file in files)
        {
          NSString *ext = [[file pathExtension] lowercaseString];
          if (![ext isEqualToString: @"ttf"] && ![ext isEqualToString: @"otf"])
            continue;
          NSURL *url = [NSURL fileURLWithPath: [dir stringByAppendingPathComponent: file]];
          CTFontManagerRegisterFontsForURL ((__bridge CFURLRef) url, kCTFontManagerScopeProcess, NULL);
        }
    }
}

void
minder_macos_note_recent_document (const char *path)
{
  if (path == NULL)
    return;
  NSURL *url = [NSURL fileURLWithPath: [NSString stringWithUTF8String: path]];
  [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: url];
}

void
minder_macos_clear_recent_documents (void)
{
  [[NSDocumentController sharedDocumentController] clearRecentDocuments: nil];
}

void
minder_macos_window_set_edited (GtkWindow *window, gboolean edited)
{
  GtkNative  *native  = GTK_NATIVE (window);
  GdkSurface *surface = (native != NULL) ? gtk_native_get_surface (native) : NULL;
  if (surface == NULL || !GDK_IS_MACOS_SURFACE (surface))
    return;
  NSWindow *win = (__bridge NSWindow *) gdk_macos_surface_get_native_window (GDK_MACOS_SURFACE (surface));
  if (win != nil)
    [win setDocumentEdited: edited];
}

/* The tabs shown in the Dock menu, and what to do when one is chosen */
static NSArray<NSString *> *dock_titles = nil;
static int                  dock_current = -1;

@interface MinderDockTarget : NSObject
@property (nonatomic) MinderDockSelectFunc callback;
@property (nonatomic) gpointer             user_data;
- (void) choose: (NSMenuItem *) item;
@end

@implementation MinderDockTarget
- (void) choose: (NSMenuItem *) item
{
  if (self.callback != NULL)
    self.callback ((int) [item tag], self.user_data);
}
@end

static MinderDockTarget *dock_target = nil;

void
minder_macos_set_dock_tabs (const char * const *titles, int n_titles, int current)
{
  NSMutableArray<NSString *> *list = [NSMutableArray array];
  for (int i = 0; i < n_titles; i++)
    [list addObject: [NSString stringWithUTF8String: titles[i]]];
  dock_titles  = list;
  dock_current = current;
}

void
minder_macos_set_dock_handler (MinderDockSelectFunc callback, gpointer user_data)
{
  id delegate = [NSApp delegate];
  if (delegate == nil || callback == NULL)
    return;

  dock_target = [[MinderDockTarget alloc] init];
  dock_target.callback  = callback;
  dock_target.user_data = user_data;

  /* The menu is built each time the Dock asks for it */
  SEL sel = @selector (applicationDockMenu:);
  NSMenu *(^block) (id, NSApplication *) = ^NSMenu *(id self_, NSApplication *app) {
    NSMenu *menu = [[NSMenu alloc] init];
    for (NSUInteger i = 0; i < [dock_titles count]; i++)
      {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle: dock_titles[i]
                                                      action: @selector (choose:)
                                               keyEquivalent: @""];
        item.target = dock_target;
        item.tag    = (NSInteger) i;
        item.state  = ((int) i == dock_current) ? NSControlStateValueOn : NSControlStateValueOff;
        [menu addItem: item];
      }
    return menu;
  };
  IMP imp = imp_implementationWithBlock (block);
  if (!class_addMethod ([delegate class], sel, imp, "@@:@"))
    class_replaceMethod ([delegate class], sel, imp, "@@:@");
}

void
minder_macos_window_set_titlebar_height (GtkWindow *window, int height)
{
  GtkNative  *native  = GTK_NATIVE (window);
  GdkSurface *surface = (native != NULL) ? gtk_native_get_surface (native) : NULL;
  if (surface == NULL || !GDK_IS_MACOS_SURFACE (surface))
    return;
  NSWindow *win = (__bridge NSWindow *) gdk_macos_surface_get_native_window (GDK_MACOS_SURFACE (surface));
  if (win == nil)
    return;
  header_height = height;
  show_standard_buttons (win);
}
