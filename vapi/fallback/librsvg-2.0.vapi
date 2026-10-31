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
 * Minimal Vala binding for the subset of the librsvg C API that Minder uses
 * (see librsvg/rsvg.h).  Written for platforms such as Homebrew on macOS,
 * where librsvg ships a GIR file but no .vapi.  Used only when the system
 * provides no librsvg-2.0 binding of its own.
 */

[CCode (cheader_filename = "librsvg/rsvg.h")]
namespace Rsvg {

  [CCode (cname = "RsvgUnit", cprefix = "RSVG_UNIT_")]
  public enum Unit {
    PERCENT,
    PX,
    EM,
    EX,
    IN,
    CM,
    MM,
    PT,
    PC,
    CH
  }

  [CCode (cname = "RsvgLength", has_type_id = false)]
  public struct Length {
    public double length;
    public Rsvg.Unit unit;
  }

  [CCode (cname = "RsvgRectangle", has_type_id = false)]
  public struct Rectangle {
    public double x;
    public double y;
    public double width;
    public double height;
  }

  [Flags]
  [CCode (cname = "RsvgHandleFlags", cprefix = "RSVG_HANDLE_", type_id = "rsvg_handle_flags_get_type ()")]
  public enum HandleFlags {
    FLAGS_NONE,
    FLAG_UNLIMITED,
    FLAG_KEEP_IMAGE_DATA
  }

  [CCode (cname = "RsvgHandle", type_id = "rsvg_handle_get_type ()")]
  public class Handle : GLib.Object {

    [CCode (cname = "rsvg_handle_new_from_gfile_sync")]
    public Handle.from_gfile_sync( GLib.File file, Rsvg.HandleFlags flags, GLib.Cancellable? cancellable = null ) throws GLib.Error;

    [CCode (cname = "rsvg_handle_new_from_stream_sync")]
    public Handle.from_stream_sync( GLib.InputStream input_stream, GLib.File? base_file, Rsvg.HandleFlags flags, GLib.Cancellable? cancellable = null ) throws GLib.Error;

    [CCode (cname = "rsvg_handle_set_dpi")]
    public void set_dpi( double dpi );

    [CCode (cname = "rsvg_handle_get_intrinsic_size_in_pixels")]
    public bool get_intrinsic_size_in_pixels( out double out_width, out double out_height );

    [CCode (cname = "rsvg_handle_get_intrinsic_dimensions")]
    public void get_intrinsic_dimensions( out bool out_has_width, out Rsvg.Length out_width, out bool out_has_height, out Rsvg.Length out_height, out bool out_has_viewbox, out Rsvg.Rectangle out_viewbox );

    [CCode (cname = "rsvg_handle_render_document")]
    public bool render_document( Cairo.Context cr, Rsvg.Rectangle viewport ) throws GLib.Error;

  }

}
