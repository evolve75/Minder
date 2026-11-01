/*
* Copyright (c) 2018-2026 (https://github.com/phase1geo/Minder)
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
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Cairo;

public class ExportPDF : Export {

  //-------------------------------------------------------------
  // Constructor
  public ExportPDF() {
    base( "pdf", _( "PDF" ), { ".pdf" }, true, false, false, false );
  }

  //-------------------------------------------------------------
  // Exports the given mindmap in PDF format.
  public override bool export( string fname, MindMap map ) {

    // Get the width and height of the page
    double page_width  = 8.5 * 72;
    double page_height = 11  * 72;
    double margin      = 0.5 * 72;

    // Create the drawing surface
    var surface = new PdfSurface( fname, page_width, page_height );
    var context = new Context( surface );

    // Get the rectangle holding the entire document
    double x, y, w, h;
    map.model.document_rectangle( out x, out y, out w, out h );

    // Calculate the required scaling factor to get the document to fit
    double width  = (page_width  - (2 * margin)) / w;
    double height = (page_height - (2 * margin)) / h;
    double sf     = (width < height) ? width : height;

    // Scale and translate the image
    context.scale( sf, sf );
    context.translate( ((0 - x) + (margin / sf)), ((0 - y) + (margin / sf)) );

    // Draw background
    map.canvas.get_style_context().render_background( context, x, y, w, h );

    // Recreate the image
    map.model.draw_all( context, true, false );

    // Draw the page to the PDF file
    context.show_page();

    return( true );

  }

#if MACOS_PRINT
  //-------------------------------------------------------------
  // Exports a PDF whose single page is exactly the map plus a margin, so that
  // a print system can scale it to whatever paper the user picks.
  public bool export_to_fit( string fname, MindMap map ) {

    double x, y, w, h;
    map.model.document_rectangle( out x, out y, out w, out h );

    double margin  = 24;
    var    surface = new PdfSurface( fname, w + (2 * margin), h + (2 * margin) );
    var    context = new Context( surface );

    context.translate( (margin - x), (margin - y) );
    map.canvas.get_style_context().render_background( context, x, y, w, h );
    map.model.draw_all( context, true, false );
    context.show_page();

    return( true );

  }
#endif

}
