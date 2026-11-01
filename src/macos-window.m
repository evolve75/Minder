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
#include <gdk/macos/gdkmacos.h>

#include "macos-window.h"

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
