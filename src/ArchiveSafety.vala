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
// Rules for extracting archives that came from outside the app
// (map files, XMind files).  Entry names are untrusted: without
// these checks a name such as "../../x" or a symlink entry makes
// the extractor write outside the folder it was given.
public class ArchiveSafety {

  // Largest map.xml that is read into memory from an archive
  public const int64 MAX_XML_BYTES = 256 * 1024 * 1024;

  //-------------------------------------------------------------
  // Options for the disk writer.  Permissions, ACLs and file
  // flags are left to the defaults rather than taken from the
  // archive.  The SECURE_* flags are not used: they check the
  // whole destination path, and the temp and data folders on
  // macOS sit below symlinks (/var).  Names and entry types are
  // checked by is_safe_entry() instead, so no link is created.
  public static Archive.ExtractFlags extract_flags() {
    return( Archive.ExtractFlags.TIME );
  }

  //-------------------------------------------------------------
  // Returns true if the name is a relative path that stays below
  // the folder it is joined to.
  public static bool is_safe_name( string? name ) {
    if( (name == null) || (name == "") || name.has_prefix( "/" ) || name.has_prefix( "\\" ) ) {
      return( false );
    }
    foreach( var part in name.replace( "\\", "/" ).split( "/" ) ) {
      if( part == ".." ) {
        return( false );
      }
    }
    return( true );
  }

  //-------------------------------------------------------------
  // Returns true if the entry is a plain file or folder with a
  // safe name.  Links and device files are refused.
  public static bool is_safe_entry( Archive.Entry entry ) {
    var type = entry.filetype();
    if( (type != Archive.FileType.IFREG) && (type != Archive.FileType.IFDIR) ) {
      return( false );
    }
    if( entry.hardlink() != null ) {
      return( false );
    }
    return( is_safe_name( entry.pathname() ) );
  }

}
