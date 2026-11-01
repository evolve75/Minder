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

/* Vala binding for src/macos-print.m (native macOS print panel) */

[CCode (cheader_filename = "macos-print.h")]
namespace MacosPrint {
  [CCode (cname = "minder_macos_print_pdf")]
  public bool print_pdf( Gtk.Window parent, string pdf_path, string job_name );
  [CCode (cname = "minder_macos_print_pdf_to_file")]
  public bool print_pdf_to_file( string pdf_path, string save_path );
}
