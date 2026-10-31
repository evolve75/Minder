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
*/

/*
 * Minimal stand-in for the subset of the Granite API that Minder uses.
 * This file is compiled only when the 'granite' Meson option is disabled
 * (e.g. on macOS), and is built on plain GTK4 and libadwaita.
 */

namespace Granite {

  namespace CssClass {
    public const string SUGGESTED = "suggested-action";
  }

  public const string STYLE_CLASS_VIEW = "view";

  // Empty: Minder only imports this namespace.
  namespace Widgets {
  }

  //-------------------------------------------------------------
  // Returns black or white, whichever contrasts best with the given
  // background color (WCAG relative-luminance contrast ratio).
  public Gdk.RGBA contrasting_foreground_color( Gdk.RGBA bg ) {

    var lum    = relative_luminance( bg );
    var black  = Gdk.RGBA() { red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 1.0f };
    var white  = Gdk.RGBA() { red = 1.0f, green = 1.0f, blue = 1.0f, alpha = 1.0f };
    var c_black = (lum + 0.05) / 0.05;
    var c_white = 1.05 / (lum + 0.05);

    return( (c_black >= c_white) ? black : white );

  }

  private double linearize( float c ) {
    return( (c <= 0.03928) ? (c / 12.92) : Math.pow( (c + 0.055) / 1.055, 2.4 ) );
  }

  private double relative_luminance( Gdk.RGBA c ) {
    return( (0.2126 * linearize( c.red )) + (0.7152 * linearize( c.green )) + (0.0722 * linearize( c.blue )) );
  }

  //-------------------------------------------------------------
  // Converts an accelerator string to a human-readable label.
  public string accel_to_string( string? accel ) {

    if( (accel == null) || (accel == "") ) {
      return( "" );
    }

    uint            key;
    Gdk.ModifierType mods;
    if( !Gtk.accelerator_parse( accel, out key, out mods ) ) {
      return( "" );
    }

    return( Gtk.accelerator_get_label( key, mods ) );

  }

  //-------------------------------------------------------------
  // Returns Pango markup for a tooltip with its accelerators shown
  // beneath the description.
  public string markup_accel_tooltip( string[]? accels, string? description = null ) {

    string[] labels = {};
    if( accels != null ) {
      foreach( var accel in accels ) {
        var label = accel_to_string( accel );
        if( label != "" ) {
          labels += Markup.escape_text( label );
        }
      }
    }

    var markup = (description != null) ? Markup.escape_text( description ) : "";

    if( labels.length > 0 ) {
      if( markup != "" ) {
        markup += "\n";
      }
      markup += "<span weight=\"600\" size=\"smaller\" alpha=\"75%\">%s</span>".printf( string.joinv( ", ", labels ) );
    }

    return( markup );

  }

  //-------------------------------------------------------------
  // Follows the system light/dark preference via libadwaita.
  public class Settings : Object {

    public enum ColorScheme {
      NO_PREFERENCE,
      DARK,
      LIGHT
    }

    private static Settings? _instance = null;

    public ColorScheme prefers_color_scheme { get; private set; default = ColorScheme.NO_PREFERENCE; }

    public static unowned Settings get_default() {
      if( _instance == null ) {
        _instance = new Settings();
      }
      return( _instance );
    }

    private Settings() {
      Adw.init();
      var manager = Adw.StyleManager.get_default();
      update( manager );
      manager.notify["dark"].connect(() => {
        update( manager );
      });
    }

    private void update( Adw.StyleManager manager ) {
      prefers_color_scheme = manager.dark ? ColorScheme.DARK : ColorScheme.LIGHT;
    }

  }

  //-------------------------------------------------------------
  // Box with optional "linked" child spacing.
  public class Box : Gtk.Box {

    public enum Spacing {
      NONE   = 0,
      SINGLE = 6,
      DOUBLE = 12,
      LINKED = -1
    }

    private Spacing _child_spacing = Spacing.NONE;

    public Spacing child_spacing {
      get {
        return( _child_spacing );
      }
      construct set {
        _child_spacing = value;
        if( value == Spacing.LINKED ) {
          spacing = 0;
          add_css_class( "linked" );
        } else {
          remove_css_class( "linked" );
          spacing = (int)value;
        }
      }
    }

    public Box( Gtk.Orientation orientation, int spacing = 0 ) {
      Object( orientation: orientation, spacing: spacing );
    }

  }

  //-------------------------------------------------------------
  public class Dialog : Gtk.Dialog {
  }

  //-------------------------------------------------------------
  public class MessageDialog : Gtk.Dialog {

    public MessageDialog.with_image_from_icon_name( string primary_text, string secondary_text, string image_icon_name, Gtk.ButtonsType buttons = Gtk.ButtonsType.NONE ) {

      Object( modal: true );

      var image = new Gtk.Image.from_icon_name( image_icon_name ) {
        pixel_size = 48,
        valign     = Gtk.Align.START
      };

      var primary = new Gtk.Label( primary_text ) {
        halign     = Gtk.Align.START,
        xalign     = 0,
        wrap       = true,
        max_width_chars = 50
      };
      primary.add_css_class( "title-3" );

      var secondary = new Gtk.Label( secondary_text ) {
        halign     = Gtk.Align.START,
        xalign     = 0,
        wrap       = true,
        max_width_chars = 50
      };

      var text = new Gtk.Box( Gtk.Orientation.VERTICAL, 6 ) {
        hexpand = true
      };
      text.append( primary );
      text.append( secondary );

      var box = new Gtk.Box( Gtk.Orientation.HORIZONTAL, 12 ) {
        margin_top    = 12,
        margin_bottom = 12,
        margin_start  = 12,
        margin_end    = 12
      };
      box.append( image );
      box.append( text );

      get_content_area().append( box );

      switch( buttons ) {
        case Gtk.ButtonsType.CLOSE     :  add_button( _( "Close" ), Gtk.ResponseType.CLOSE );  break;
        case Gtk.ButtonsType.OK        :  add_button( _( "OK" ),    Gtk.ResponseType.OK );     break;
        case Gtk.ButtonsType.CANCEL    :  add_button( _( "Cancel" ), Gtk.ResponseType.CANCEL );  break;
        case Gtk.ButtonsType.YES_NO    :
          add_button( _( "No" ),  Gtk.ResponseType.NO );
          add_button( _( "Yes" ), Gtk.ResponseType.YES );
          break;
        case Gtk.ButtonsType.OK_CANCEL :
          add_button( _( "Cancel" ), Gtk.ResponseType.CANCEL );
          add_button( _( "OK" ),     Gtk.ResponseType.OK );
          break;
        default :  break;
      }

    }

  }

}
