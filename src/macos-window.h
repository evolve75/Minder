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

/*
 * Native macOS window chrome.  GTK draws its own minimize/maximize/close
 * buttons in the header bar; this gives the window the standard macOS traffic
 * lights instead, drawn over a transparent titlebar.
 */

#ifndef MINDER_MACOS_WINDOW_H
#define MINDER_MACOS_WINDOW_H

#include <gtk/gtk.h>

G_BEGIN_DECLS

/* Gives the window the native close/minimize/zoom buttons at the top left and
 * lets the header bar draw underneath them.  Returns FALSE if the window has no
 * native counterpart yet (it must be realized). */
gboolean minder_macos_window_use_native_controls (GtkWindow *window);

/* Calls callback (user_data) when the user clicks the Dock icon (or reopens the
 * app) while it has no visible window. */
typedef void (*MinderReopenFunc) (gpointer user_data);
void minder_macos_set_reopen_handler (MinderReopenFunc callback, gpointer user_data);

/* Makes the fonts in the bundle's Resources/fonts available to this process.
 * Call before GTK creates its font map. */
void minder_macos_register_bundled_fonts (void);

/* Empties the system's recent documents list.  The app keeps its own list, and
 * the Dock menu shows the open tabs instead. */
void minder_macos_clear_recent_documents (void);

/* Makes the titlebar as tall as the header bar and centres the traffic lights
 * in it. */
void minder_macos_window_set_titlebar_height (GtkWindow *window, int height);

/* Shows the window's native "edited" marker (the dot in the close button). */
void minder_macos_window_set_edited (GtkWindow *window, gboolean edited);

/* The Dock icon's menu: one entry per open tab, with a check on the current
 * one.  Choosing an entry calls the handler with the tab's position. */
typedef void (*MinderDockSelectFunc) (int index, gpointer user_data);
void minder_macos_set_dock_handler (MinderDockSelectFunc callback, gpointer user_data);
void minder_macos_set_dock_tabs (const char * const *titles, int n_titles, int current);

G_END_DECLS

#endif /* MINDER_MACOS_WINDOW_H */
