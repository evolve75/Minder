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

//-------------------------------------------------------------
// Decides which link targets may be handed to the system.  The
// target of a link is stored apart from the text that is shown
// and comes from the map file, so it must not be able to start
// an application or reach a network share when it is clicked.
public class UrlSafety {

  private const string[] SCHEMES = { "http", "https", "ftp", "ftps", "sftp", "mailto" };

  // File types that the system would run rather than show
  private const string[] RUNNABLE = {
    ".app", ".command", ".terminal", ".workflow", ".action", ".scpt", ".scptd",
    ".sh", ".bash", ".zsh", ".pkg", ".mpkg", ".dmg", ".jar", ".exe", ".bat",
    ".cmd", ".msi", ".desktop", ".fileloc", ".inetloc", ".webloc"
  };

  //-------------------------------------------------------------
  // Returns true if the URL may be opened with the default
  // application.
  public static bool is_safe_url( string url ) {

    var scheme = Uri.parse_scheme( url.strip() );
    if( scheme == null ) {
      return( false );
    }

    scheme = scheme.down();

    if( scheme in SCHEMES ) {
      return( true );
    }

    if( scheme == "file" ) {
      try {
        string? host = null;
        var     path = Filename.from_uri( url.strip(), out host );
        return( ((host == null) || (host == "")) && is_safe_path( path ) );
      } catch( ConvertError e ) {
        return( false );
      }
    }

    return( false );

  }

  //-------------------------------------------------------------
  // Returns true if the local path is something to show, not to
  // run.
  public static bool is_safe_path( string path ) {

    var name = Path.get_basename( path ).down();

    foreach( var suffix in RUNNABLE ) {
      if( name.has_suffix( suffix ) ) {
        return( false );
      }
    }

    if( FileUtils.test( path, FileTest.IS_REGULAR ) && FileUtils.test( path, FileTest.IS_EXECUTABLE ) ) {
      return( false );
    }

    return( true );

  }

}
