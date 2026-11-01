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
// Reads XML that came from outside the app.  Maps can be large
// and deeply nested, so the parser keeps the HUGE option (without
// it libxml2 refuses them).  That option also switches off the
// limits on entity expansion, so a file that declares entities
// is refused first: none of the formats Minder reads needs them.
public class XmlSafety {

  // Largest XML file that is read
  public const int64 MAX_BYTES = 256 * 1024 * 1024;

  //-------------------------------------------------------------
  // Returns true if the data declares an entity.  Data that is not
  // ASCII-based (UTF-16 has NUL bytes among the first few) cannot
  // be scanned this way and is treated as unsafe.
  public static bool declares_entity( uint8[] data ) {
    var limit = (data.length < 4) ? data.length : 4;
    for( int i=0; i<limit; i++ ) {
      if( data[i] == 0 ) {
        return( true );
      }
    }
    if( (data.length >= 2) && (((data[0] == 0xff) && (data[1] == 0xfe)) || ((data[0] == 0xfe) && (data[1] == 0xff))) ) {
      return( true );
    }
    uint8[] key = { '<', '!', 'E', 'N', 'T', 'I', 'T', 'Y' };
    for( int i=0; i<=(data.length - key.length); i++ ) {
      if( (data[i] == '<') && (Memory.cmp( &data[i], key, key.length ) == 0) ) {
        return( true );
      }
    }
    return( false );
  }

  //-------------------------------------------------------------
  // Parses XML held in memory.  Returns null if the data is too
  // large, declares an entity or is not XML.
  public static Xml.Doc* read_bytes( uint8[] data, int options = 0 ) {
    if( (data.length > MAX_BYTES) || declares_entity( data ) ) {
      return( null );
    }
    return( Xml.Parser.read_memory( (string)data, data.length, null, null, (options | Xml.ParserOption.HUGE) ) );
  }

  //-------------------------------------------------------------
  // Parses XML held in a string.
  public static Xml.Doc* read_memory( string text, int options = 0 ) {
    return( read_bytes( text.data, options ) );
  }

  //-------------------------------------------------------------
  // Parses an XML file with the same rules as read_bytes().
  public static Xml.Doc* read_file( string fname, int options = 0 ) {
    try {
      var info = File.new_for_path( fname ).query_info( "standard::size", FileQueryInfoFlags.NONE );
      if( info.get_size() > MAX_BYTES ) {
        return( null );
      }
      uint8[] data;
      FileUtils.get_data( fname, out data );
      return( read_bytes( data, options ) );
    } catch( Error e ) {
      return( null );
    }
  }

}
