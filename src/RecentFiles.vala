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
/*
 * The list of recently used documents, kept free of widgets and settings so it
 * can be tested.  The most recent file comes first.
 */
public class RecentFiles {

  public const int MAX = 10;

  //-------------------------------------------------------------
  // Returns the list with the path moved (or added) to the front, without
  // duplicates, cut to MAX entries.
  public static string[] add( string[] list, string path ) {
    string[] result = { path };
    foreach( var item in list ) {
      if( (item != path) && (result.length < MAX) ) {
        result += item;
      }
    }
    return( result );
  }

  //-------------------------------------------------------------
  // Returns the list without the path
  public static string[] remove( string[] list, string path ) {
    string[] result = {};
    foreach( var item in list ) {
      if( item != path ) {
        result += item;
      }
    }
    return( result );
  }

  //-------------------------------------------------------------
  // Returns the list without the entries whose files no longer exist
  public static string[] prune( string[] list ) {
    string[] result = {};
    foreach( var item in list ) {
      if( FileUtils.test( item, FileTest.IS_REGULAR ) ) {
        result += item;
      }
    }
    return( result );
  }

  //-------------------------------------------------------------
  // Returns the menu label for a file.  Files that share a name with another
  // entry show their folder as well, so they can be told apart.
  public static string label( string[] list, string path ) {
    var name = Path.get_basename( path );
    foreach( var item in list ) {
      if( (item != path) && (Path.get_basename( item ) == name) ) {
        return( "%s — %s".printf( name, Path.get_dirname( path ) ) );
      }
    }
    return( name );
  }

}
