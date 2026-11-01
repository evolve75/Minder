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

/* Vala binding for src/macos-window.m (native macOS window controls) */

[CCode (cheader_filename = "macos-window.h")]
namespace MacosWindow {
  [CCode (cname = "minder_macos_window_use_native_controls")]
  public bool use_native_controls( Gtk.Window window );
  [CCode (cname = "minder_macos_register_bundled_fonts")]
  public void register_bundled_fonts();
  [CCode (cname = "minder_macos_note_recent_document")]
  public void note_recent_document( string path );
  [CCode (cname = "minder_macos_clear_recent_documents")]
  public void clear_recent_documents();
  [CCode (cname = "minder_macos_window_set_titlebar_height")]
  public void set_titlebar_height( Gtk.Window window, int height );
  [CCode (cname = "minder_macos_window_set_edited")]
  public void set_edited( Gtk.Window window, bool edited );
  [CCode (cname = "MinderDockSelectFunc", has_target = true, simple_generics = true)]
  public delegate void DockSelectFunc( int index );
  [CCode (cname = "minder_macos_set_dock_handler")]
  public void set_dock_handler( [CCode (delegate_target_pos = 1.1)] DockSelectFunc callback );
  [CCode (cname = "minder_macos_set_dock_tabs")]
  public void set_dock_tabs( [CCode (array_length_pos = 1.1)] string[] titles, int current );
  [CCode (cname = "MinderReopenFunc", has_target = true, simple_generics = true)]
  public delegate void ReopenFunc();
  [CCode (cname = "minder_macos_set_reopen_handler")]
  public void set_reopen_handler( [CCode (delegate_target_pos = 1.1)] ReopenFunc callback );
}
