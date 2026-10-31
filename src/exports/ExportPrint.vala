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

using Gtk;

public class ExportPrint : Object {

  private MindMap _map;

  //-------------------------------------------------------------
  // Default constructor.
  public ExportPrint() {}

  //-------------------------------------------------------------
  // Perform print operation.
  public void print( MindMap map, MainWindow main ) {

    _map = map;

#if PRIMARY_COMMAND
    // GTK's macOS build has no CUPS print backend, so its dialog can only print
    // to a file.  Render a PDF and open it in the default viewer (Preview),
    // which can print to any installed printer.
    try {
      var dir  = DirUtils.make_tmp( "minder-print-XXXXXX" );
      var name = map.doc.label.replace( "/", "-" );
      if( name.has_suffix( ".minder" ) ) {
        name = name.substring( 0, name.length - 7 );
      }
      var path = Path.build_filename( dir, name + ".pdf" );
      if( new ExportPDF().export( path, map ) ) {
        AppInfo.launch_default_for_uri( File.new_for_path( path ).get_uri(), null );
      }
    } catch( GLib.Error e ) {
      stderr.printf( "ERROR: Unable to print: %s\n", e.message );
    }
    return;
#endif

    var op = new PrintOperation();

    op.print_settings     = new PrintSettings.from_gvariant( Minder.settings.get_value( "print-settings" ) );
    op.default_page_setup = new PageSetup.from_gvariant( Minder.settings.get_value( "page-setup" ) );
    op.n_pages            = 1;
    op.unit               = Unit.MM;
    op.embed_page_setup   = true;

    // Connect to the draw_page signal
    op.draw_page.connect( draw_page );

    try {
      var res = op.run( PrintOperationAction.PRINT_DIALOG, main );
      switch( res ) {
        case PrintOperationResult.APPLY :
          Minder.settings.set_value( "print-settings", op.print_settings.to_gvariant() );
          Minder.settings.set_value( "page-setup",     op.default_page_setup.to_gvariant() );
          break;
        case PrintOperationResult.ERROR :
          // TBD - Display the print error
          break;
        case PrintOperationResult.IN_PROGRESS :
          // TBD
          break;
        default :  break;
      }
    } catch( GLib.Error e ) {
      // TBD
    }

  }

  //-------------------------------------------------------------
  // Draws the page.
  public void draw_page( PrintOperation op, PrintContext context, int page_nr ) {

    var ctx         = context.get_cairo_context();
    var page_width  = context.get_width();
    var page_height = context.get_height();

    // Get the rectangle holding the entire document
    double x, y, w, h;
    _map.model.document_rectangle( out x, out y, out w, out h );

    // Calculate the required scaling factor to get the document to fit
    double width  = page_width  / w;
    double height = page_height / h;
    double sf     = (width < height) ? width : height;

    // Scale and translate the image
    ctx.scale( sf, sf );
    ctx.translate( (0 - x), (0 - y) );

    // Draw the map
    _map.model.draw_all( ctx, true, false );

  }

}
