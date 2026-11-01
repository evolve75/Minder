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

using Cairo;
using Gdk;

/*
 * Paints a pixbuf through a Cairo surface that is built once.  Drawing with
 * Gdk's cairo_set_source_pixbuf builds a new surface (allocating and copying
 * the pixels) on every call, which is wasteful for images drawn every frame.
 * The surface is rebuilt only when a different pixbuf is passed in.
 */
public class PixbufPainter {

  private Pixbuf?       _source  = null;
  private ImageSurface? _surface = null;

  //-------------------------------------------------------------
  // Paints the pixbuf at (x, y) with the given opacity.
  public void paint( Context ctx, Pixbuf pixbuf, double x, double y, double opacity = 1.0 ) {
    if( (pixbuf != _source) || (_surface == null) ) {
      _surface = new ImageSurface( Format.ARGB32, pixbuf.width, pixbuf.height );
      var tmp  = new Context( _surface );
      cairo_set_source_pixbuf( tmp, pixbuf, 0, 0 );
      tmp.paint();
      _source = pixbuf;
    }
    ctx.set_source_surface( _surface, x, y );
    ctx.paint_with_alpha( opacity );
  }

}
