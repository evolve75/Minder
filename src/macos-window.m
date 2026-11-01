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
