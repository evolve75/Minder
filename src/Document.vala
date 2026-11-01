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
using Gtk;
using GLib;

public enum UpgradeAction {
  OVERRIDE,
  SAVE_ORIG,
  READ_ONLY,
  NUM;

  //-------------------------------------------------------------
  // Returns the label to display to the user for this option.
  public string? label() {
    switch( this ) {
      case OVERRIDE  :  return( _( "Upgrade Minder file to new version" ) );
      case SAVE_ORIG :  return( _( "Upgrade Minder file to new version and keep a copy of the original" ) );
      case READ_ONLY :  return( _( "Do not upgrade Minder file but view it as read-only" ) );
      default        :  return( null );
    }
  }

  //-------------------------------------------------------------
  // Returns the label to use when tabs need to be upgraded.
  public string? tab_label() {
    switch( this ) {
      case OVERRIDE  :  return( _( "Upgrade Minder files to new version" ) );
      case SAVE_ORIG :  return( _( "Upgrade Minder files to new version but keep a copy of the original if previously saved" ) );
      case READ_ONLY :  return( _( "Do not upgrade Minder files but view them as read-only" ) );
      default        :  return( null );
    }
  }

  //-------------------------------------------------------------
  // Returns an array of labels for upgrade action DropDown list.
  public static string[] labels() {
    string[] lbls = {};
    for( int i=0; i<NUM; i++ ) {
      var action = (UpgradeAction)i;
      if( action.label() != null ) {
        lbls += action.label();
      }
    }
    return( lbls );
  }

  //-------------------------------------------------------------
  // Returns an array of labels to display when tabs need to be
  // upgraded.
  public static string[] tab_labels() {
    string[] lbls = {};
    for( int i=0; i<NUM; i++ ) {
      var action = (UpgradeAction)i;
      if( action.tab_label() != null ) {
        lbls += action.tab_label();
      }
    }
    return( lbls );
  }

}

public delegate void AfterLoadFunc( bool loaded, string msg );

public class Document : Object {

  private weak MindMap _map;
  private string  _filename;
  private string  _temp_dir;
  private bool    _from_user;  // Set to true if _filename was set by the user
  private string  _etag;
  private bool    _upgrade_ro   = false;
  private bool    _save_needed  = false;
  private bool    _read_only    = false;
  private string  _load_version = "";  

  // Properties
  public string filename {
    set {
      if( _filename != value ) {
        if( !_from_user ) {
          FileUtils.unlink( _filename );
        }
        _filename   = value;
        _from_user  = true;
        _disk_stamp = null;   // a new name: the user already chose to use it
      }
    }
    get {
      return( _filename );
    }
  }
  public string temp_dir {
    get {
      return( _temp_dir );
    }
  }
  public string load_version {
    get {
      return( _load_version );
    }
  }
  public string label {
    owned get {
      return( GLib.Path.get_basename( _filename ) );
    }
  }
  public bool save_needed {
    get {
      return( _save_needed );
    }
  }
  public bool read_only {
    get {
      var prev_read_only = _read_only;
      _read_only = Utils.is_read_only( _filename );
      if( _save_needed && prev_read_only && !_read_only && !_upgrade_ro ) {
        save();
      }
      return( _read_only || _upgrade_ro );
    }
  }

  public signal void save_changed();

  private string? _disk_stamp = null;   // Stamp of the file on disk when we last read or wrote it
  private bool    _recovery_dirty = false;  // The map changed since its recovery copy was written
  public signal void read_only_changed();

  //-------------------------------------------------------------
  // Default constructor
  public Document( MindMap map ) {

    _map = map;

    // Generate unique Etag
    _etag = generate_etag();

    // Create the temporary file
    var dir = get_unsaved_dir();
    if( DirUtils.create_with_parents( dir, 0775 ) == 0 ) {
      int i = 1;
      do {
        _filename = GLib.Path.build_filename( dir, _( "unnamed" ) + "%d.minder".printf( i++ ) );
      } while( GLib.FileUtils.test( _filename, FileTest.EXISTS ) );
      _from_user = false;
    }

    // Create the temporary directory to store the mind map
    make_temp_dir();

    // Listen for any changes from the canvas
    map.changed.connect( canvas_changed );

  }

  //-------------------------------------------------------------
  // Returns the directory where unsaved minder files.
  public static string get_unsaved_dir() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "minder", "unsaved" ) );
  }

  //-------------------------------------------------------------
  // Generate new "random" etag
  private string generate_etag() {
    return GLib.Random.next_int().to_string();
  }

  //-------------------------------------------------------------
  // Called whenever the canvas changes such that a save will be
  // needed
  private void canvas_changed() {
    var call_save_changed = !_save_needed;
    _save_needed    = true;
    _recovery_dirty = true;
    auto_save();
    if( call_save_changed ) {
      save_changed();
    }
  }

  //-------------------------------------------------------------
  // Called when a document filename is loaded from the tab state
  // file
  public void load_filename( string fname, bool saved ) {
    filename   = fname;
    _from_user = saved;
  }

  //-------------------------------------------------------------
  // Returns the name of the backup file to use for the stored
  // filename.
  private string get_bak_file() {

    var file = GLib.File.new_for_path( filename );

    // Get parent directory
    var parent = file.get_parent();
    var dir    = (parent != null) ? parent.get_path() : ".";
    var bak_basename = "." + file.get_basename() + ".bak";

    // Join dir + new basename
    return( GLib.Path.build_filename( dir, bak_basename ) );

  }

  //-------------------------------------------------------------
  // Returns the name of the filename named with a .orig in the
  // filename just before the extension.
  private string get_orig_file() {

    var file = GLib.File.new_for_path( filename );

    var parent   = file.get_parent();
    var dir      = (parent != null) ? parent.get_path() : ".";
    var basename = file.get_basename();
    var index    = basename.last_index_of_char('.');

    basename = (index > 0) ? (basename.substring( 0, index ) + ".orig" + basename.substring( index )) :
                             (basename + ".orig");

    return( GLib.Path.build_filename( dir, basename ) );

  }

  //-------------------------------------------------------------
  // Returns true if the stored filename came from the user
  public bool is_saved() {
    return( _from_user );
  }

  //-------------------------------------------------------------
  // Searches the given file for a node with the given ID.  If
  // found, returns true along with the title of the node.
  public static bool xml_find( string fname, int id, ref string name ) {

    var found = false;

    Archive.Read archive = new Archive.Read();
    archive.support_filter_gzip();
    archive.support_format_all();

    // Open the portable Minder file for reading
    if( archive.open_filename( fname, 16384 ) != Archive.Result.OK ) {
      Xml.Doc* doc = Xml.Parser.read_file( fname, null, Xml.ParserOption.HUGE );
      if( doc != null ) {
        found = MapModel.xml_find( doc->get_root_element(), id, ref name );
        delete doc;
      }
      return( found );
    }

    unowned Archive.Entry entry;

    while( archive.next_header( out entry ) == Archive.Result.OK ) {
      if( entry.pathname() == "map.xml" ) {
        // One extra byte so that the buffer is a valid NUL-terminated string
        uint8[] data = new uint8[entry.size() + 1];
        if( archive.read_data( data[0:entry.size()] ) > 0 ) {
          var memory = (string)data;
          Xml.Doc* doc = Xml.Parser.read_memory( memory, memory.length, null, null, Xml.ParserOption.HUGE );
          if( doc != null ) {
            found = MapModel.xml_find( doc->get_root_element(), id, ref name );
            delete doc;
            break;
          }
        }
      }
    }

    archive.close();

    return( found );

  }

  //-------------------------------------------------------------
  // Reads in the map.xml file and returns the XML document.
  private Xml.Doc* load_raw() {
    return Xml.Parser.read_file( get_map_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
  }

  //-------------------------------------------------------------
  // Reads the stored etag attribute from the given XML document
  private string get_etag( Xml.Doc* doc ) {
    var root = doc->get_root_element();
    if( root == null ) return( "" );
    var e = root->get_prop( "etag" );
    return( (e == null) ? "" : e );
  }

  //-------------------------------------------------------------
  // Opens the given filename
  private bool load_xml() {

    Xml.Doc* doc = load_raw();
    if( doc == null ) {
      return( false );
    }

    // Load Etag
    _etag = get_etag( doc );

    var v = doc->get_root_element()->get_prop( "version" );
    if( v != null ) {
      _load_version = v;
    }

    // Load document
    _map.model.load( doc->get_root_element() );

    // Delete the XML document contents
    delete doc;

    // If an etag was not found, generate one and save the updated map immediately
    if( _etag == "" ) {
      _etag = generate_etag();
      save_xml_internal( filename, false );
    }

    return( true );

  }

  //-------------------------------------------------------------
  // Converts the Minder file into the Minder document and moves
  // all stored images to the ImageManager on the local computer
  public void load( UpgradeAction force_upgrade_action = UpgradeAction.NUM, AfterLoadFunc? func = null ) {

    var bak_file = get_bak_file();
    var fname    = (FileUtils.test( bak_file, FileTest.EXISTS ) && !_map.settings.get_boolean( "keep-backup-after-save" )) ? bak_file : filename;

    // Remember the state of the file we are reading
    _disk_stamp = disk_stamp();

    // A recovery copy newer than the file holds changes lost to a crash
    var recovered = false;
    if( FileUtils.test( recovery_file(), FileTest.EXISTS ) && (mtime_of( recovery_file() ) >= mtime_of( filename )) ) {
      fname     = recovery_file();
      recovered = true;
    }

    // stdout.printf( "Loading fname: %s, temp: %s\n", fname, _temp_dir );

    Archive.Read archive = new Archive.Read();
    archive.support_filter_gzip();
    archive.support_format_all();

    Archive.ExtractFlags flags;
    flags  = Archive.ExtractFlags.TIME;
    flags |= Archive.ExtractFlags.PERM;
    flags |= Archive.ExtractFlags.ACL;
    flags |= Archive.ExtractFlags.FFLAGS;

    Archive.WriteDisk extractor = new Archive.WriteDisk();
    extractor.set_options( flags );
    extractor.set_standard_lookup();

    // Open the portable Minder file for reading
    if( archive.open_filename( fname, 16384 ) != Archive.Result.OK ) {
      if( force_upgrade_action != UpgradeAction.NUM ) {
        upgrade( force_upgrade_action, func );
      } else if( _map.settings.get_boolean( "ask-for-upgrade-action" ) ) {
        request_upgrade_action( func );
      } else {
        upgrade( (UpgradeAction)_map.settings.get_int( "upgrade-action" ), func );
      }
      return;
    }

    unowned Archive.Entry entry;

    while( archive.next_header( out entry ) == Archive.Result.OK ) {

      // We will need to modify the entry pathname so the file is written to the
      // proper location.
      if( entry.pathname() == "map.xml" ) {
        entry.set_pathname( GLib.Path.build_filename( _temp_dir, entry.pathname() ) );
      } else {
        entry.set_pathname( GLib.Path.build_filename( get_image_dir(), entry.pathname() ) );
      }

      // Read from the archive and write the files to disk
      if( extractor.write_header( entry ) != Archive.Result.OK ) {
        continue;
      }
      uint8[]         buffer;
      Archive.int64_t offset;

      while( archive.read_data_block( out buffer, out offset ) == Archive.Result.OK ) {
        if( extractor.write_data_block( buffer, offset ) != Archive.Result.OK ) {
          break;
        }
      }

    }

    // Close the archive
    if( archive.close () != Archive.Result.OK) {
      warning( "Error: %s (%d)", archive.error_string(), archive.errno() );
    }

    // Set the image directory in the image manager
    _map.image_manager.set_image_dir( get_image_dir() );

    // Finally, load the minder file
    var loaded = load_xml();

    // Recovered changes were never saved, so the document is modified
    if( recovered && loaded ) {
      _save_needed = true;
      save_changed();
    }

    if( func != null ) {
      func( loaded, "load" );
    }

  }

  //-------------------------------------------------------------
  // Saves the given node information to the specified file
  public bool save_xml() {
    return( save_xml_internal( get_map_file(), true ) );
  }

  //-------------------------------------------------------------
  // Saves the document to the given filename
  private bool save_xml_internal( string dest_filename, bool bump_etag ) {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "minder" );
    var orig_etag  = _etag;
    root->set_prop( "version", Minder.static_version );

    if ( bump_etag ) {
      // Save previous Etag
      root->set_prop( "parent-etag", _etag );

      // Generate new unique Etag
      _etag = generate_etag();
    }

    root->set_prop( "etag" , _etag );

    doc->set_root_element( root );
    _map.model.save( root );
    var res = doc->save_format_file( dest_filename, 1 );
    delete doc;

    // If the save failed, restore the original etag and return false
    if( res < 0 ) {
      _etag = orig_etag;
      return( false );
    }

    return( true );

  }

  //-------------------------------------------------------------
  // Copies the current filename as an original file, giving it
  // a unique name.
  public bool copy_as_orig() {
    var orig_file = get_orig_file();
    return( copy_file( filename, orig_file ) );
  }

  //-------------------------------------------------------------
  // Returns a string that changes whenever the file on disk is modified (its
  // modification time and size), or an empty string if it does not exist.
  private string disk_stamp() {
    try {
      var info = GLib.File.new_for_path( filename ).query_info( "etag::value,standard::size", FileQueryInfoFlags.NONE );
      return( "%s:%lld".printf( info.get_etag(), info.get_size() ) );
    } catch( Error e ) {
      return( "" );
    }
  }

  //-------------------------------------------------------------
  // Path of the crash-recovery copy of this document.
  private string recovery_file() {
    var id = Checksum.compute_for_string( ChecksumType.MD5, filename );
    return( GLib.Path.build_filename( get_unsaved_dir(), ".recovery-%s.minder".printf( id ) ) );
  }

  //-------------------------------------------------------------
  // Removes the crash-recovery copy, if any.
  private void remove_recovery() {
    FileUtils.unlink( recovery_file() );
  }

  //-------------------------------------------------------------
  // Writes a recovery copy of a document with unsaved changes.  The document
  // itself and its saved/unsaved state are not touched; after a crash the copy
  // is picked up the next time the document is opened.
  public void write_recovery() {
    if( !_save_needed || !_map.editable || !_recovery_dirty ) return;
    DirUtils.create_with_parents( get_unsaved_dir(), 0775 );
    // Never write a recovery copy without the map in it
    if( save_xml_internal( get_map_file(), false ) && write_archive( recovery_file() ) ) {
      _recovery_dirty = false;
    }
  }

  //-------------------------------------------------------------
  // Returns the modification time of the file, or 0 if it does not exist.
  private static int64 mtime_of( string path ) {
    try {
      return( GLib.File.new_for_path( path ).query_info( "time::modified", FileQueryInfoFlags.NONE ).get_modification_date_time().to_unix() );
    } catch( Error e ) {
      return( 0 );
    }
  }

  //-------------------------------------------------------------
  // Returns true if the file on disk differs from what we last read or wrote.  A
  // file that is gone has nothing of someone else's to protect, so it does not
  // count; saving writes it again, or reports why that is not possible.
  private bool externally_modified() {
    if( _disk_stamp == null ) return( false );
    var now = disk_stamp();
    return( (now != "") && (now != _disk_stamp) );
  }

  //-------------------------------------------------------------
  // Archives the contents of the opened Minder directory.  If the file on disk
  // was changed by someone else since we last read or wrote it, the user is
  // asked first and the save completes (or the file is reloaded) after the
  // answer; false is returned in that case.
  public bool save( bool force = false, bool quiet = false ) {

    if( !force && externally_modified() ) {
      _map.win.ask_modified_overwrite( _map, (overwrite) => {
        if( overwrite ) {
          save( true );
        } else {
          remove_recovery();
          _map.initialize_for_open();
          load();
        }
      });
      return( false );
    }

    // stdout.printf( "Saving...\n" );

    var bak_file = get_bak_file();
    var backed   = false;

    // Copy the file to a .bak file if it currently exists
    if( FileUtils.test( filename, FileTest.EXISTS ) ) {
      copy_file( filename, bak_file );
      backed = true;
    }

    // Save the XML file before we do everything else.  An archive without the map in
    // it must never replace the user's file.
    if( !save_xml() ) {
      stderr.printf( "WARNING: Unable to write the map for '%s'\n", filename );
      if( !quiet ) {
        _map.win.show_save_failed( _map );
      }
      return( false );
    }

    // Create the tar.gz archive named according the the first argument.  If it
    // cannot be written (the folder is gone, the volume is unmounted, ...), the
    // document stays modified so that nothing is lost and the app keeps running.
    if( !write_archive( filename ) ) {
      stderr.printf( "WARNING: Unable to save '%s'\n", filename );
      if( !quiet ) {
        _map.win.show_save_failed( _map );
      }
      return( false );
    }

    // Remove the bak file if the save went well
    if( backed && !_map.settings.get_boolean( "keep-backup-after-save" ) ) {
      FileUtils.unlink( bak_file );
    }

    // Remember what we wrote so that later changes by others can be noticed
    _disk_stamp = disk_stamp();
    remove_recovery();

    // Indicate that a save is no longer needed
    _save_needed = false;
    _upgrade_ro = false;
    read_only_changed();
    save_changed();

    return( true );

  }

  //-------------------------------------------------------------
  // Writes the document (map file and images) as a tar.gz archive to dest.  The
  // archive is built next to dest and renamed into place, so a failure part way
  // never leaves a truncated or map-less file where a good one was.  Returns false
  // if the archive could not be written.
  private bool write_archive( string dest_name ) {

    // Write through a symbolic link, not over it
    var dest = dest_name;
    for( int i=0; i<10 && FileUtils.test( dest, FileTest.IS_SYMLINK ); i++ ) {
      try {
        var target = FileUtils.read_link( dest );
        dest = GLib.Path.is_absolute( target ) ? target : GLib.Path.build_filename( GLib.Path.get_dirname( dest ), target );
      } catch( FileError e ) {
        break;
      }
    }

    var tmp = dest + ".tmp";

    Archive.Write archive = new Archive.Write ();
    archive.add_filter_gzip();
    archive.set_format_pax_restricted();
    if( archive.open_filename( tmp ) != Archive.Result.OK ) {
      warning( "Unable to create '%s': %s", tmp, archive.error_string() );
      return( false );
    }

    // Add the Minder file to the archive
    var ok = archive_file( archive, get_map_file() );

    // Add the images
    if( ok ) {
      var image_ids = _map.image_manager.get_ids();
      for( int i=0; i<image_ids.length; i++ ) {
        var id = image_ids.index( i );
        if( !archive_file( archive, _map.image_manager.get_file( id ), id ) ) {
          warning( "Unable to add image %d to '%s'", id, dest );
        }
      }
    }

    // Close the archive
    if( archive.close() != Archive.Result.OK ) {
      warning( "Unable to write '%s': %s (%d)", tmp, archive.error_string(), archive.errno() );
      ok = false;
    }

    if( ok && (FileUtils.rename( tmp, dest ) != 0) ) {
      warning( "Unable to move '%s' to '%s'", tmp, dest );
      ok = false;
    }

    if( !ok ) {
      FileUtils.unlink( tmp );
    }

    return( ok );

  }

  //-------------------------------------------------------------
  // Adds the given file to the archive.
  public bool archive_file( Archive.Write archive, string fname, int? image_id = null ) {

    try {

      var file              = GLib.File.new_for_path( fname );
      var file_info         = file.query_info( GLib.FileAttribute.STANDARD_SIZE, GLib.FileQueryInfoFlags.NONE );
      var input_stream      = file.read();
      var data_input_stream = new DataInputStream( input_stream );

      // Add an entry to the archive
      var entry = new Archive.Entry();
      entry.set_pathname( file.get_basename() );
      entry.set_size( (Archive.int64_t)file_info.get_size() );
      entry.set_filetype( Archive.FileType.IFREG );
      entry.set_perm( (Archive.FileMode)0644 );

      if( image_id != null ) {
        entry.xattr_add_entry( "image_id", (void*)image_id, sizeof( int ) );
      }

      if( archive.write_header( entry ) != Archive.Result.OK ) {
        critical ("Error writing '%s': %s (%d)", file.get_path (), archive.error_string (), archive.errno ());
        return( false );
      }

      // Add the actual content of the file
      size_t bytes_read;
      uint8[] buffer = new uint8[64];
      while( data_input_stream.read_all( buffer, out bytes_read ) ) {
        if( bytes_read <= 0 ) {
          break;
        }
        archive.write_data( buffer );
      }

    } catch( Error e ) {
      stdout.printf( "ERROR archiving: %s\n", e.message );
      critical( e.message );
      return( false );
    }

    return( true );

  }

  //-------------------------------------------------------------
  // Creates a temporary directory containing the unarchived
  // Minder files
  private void make_temp_dir() {
    try {
      _temp_dir = DirUtils.make_tmp( "minder-XXXXXX" );
      DirUtils.create( get_image_dir(), 0755 );
    } catch( Error e ) {
      critical( e.message );
    }
  }

  //-------------------------------------------------------------
  // Copies a file from one location to another
  /*
   NOTE: This function is not called according to valac
  private bool move_file( string from, string to ) {
    var from_file = File.new_for_path( from );
    var to_file   = File.new_for_path( to );
    try {
      from_file.move( to_file, FileCopyFlags.OVERWRITE );
    } catch( Error e ) {
      critical( e.message );
      return( false );
    }
    return( true );
  }
  */

  //-------------------------------------------------------------
  // Copies a file from one location to another */
  private bool copy_file( string from, string to ) {
    var from_file = File.new_for_path( from );
    var to_file   = File.new_for_path( to );
    try {
      from_file.copy( to_file, FileCopyFlags.OVERWRITE );
    } catch( Error e ) {
      critical( e.message );
      return( false );
    }
    return( true );
  }

  //-------------------------------------------------------------
  // Returns the name of the map file to save to
  private string get_map_file() {
    return( GLib.Path.build_filename( _temp_dir, "map.xml" ) );
  }

  //-------------------------------------------------------------
  // Returns the name of the image directory within the temp
  // directory
  private string get_image_dir() {
    return( GLib.Path.build_filename( _temp_dir, "images" ) );
  }

  //-------------------------------------------------------------
  // Perform the upgrade and run the given function.
  private void upgrade( UpgradeAction action, AfterLoadFunc? func ) {

    // Move the Minder XML file to the temporary directory
    if( !copy_file( filename, get_map_file() ) ) {
      if( func != null ) {
        func( false, "upgrade A" );
      }
      return;
    }

    // Load the XML file
    if( !load_xml() ) {
      if( func != null ) {
        func( false, "upgrade B" );
      }
      return;
    }

    // Move all image files that are related to the temp images directory
    var image_ids = _map.image_manager.get_ids();
    for( int i=0; i<image_ids.length; i++ ) {
      var id       = image_ids.index( i );
      var img_file = _map.image_manager.get_file( id );
      copy_file( img_file, GLib.Path.build_filename( get_image_dir(), GLib.Path.get_basename( img_file ) ) );
    }

    // Set the image directory in the image manager
    _map.image_manager.set_image_dir( get_image_dir() );

    switch( action ) {
      case UpgradeAction.OVERRIDE  :  save();  break;
      case UpgradeAction.SAVE_ORIG :  copy_as_orig();  save();  break;
      case UpgradeAction.READ_ONLY :  _upgrade_ro = true;  _map.editable_changed( _map );  break;
      default                      :  break;
    }

    if( func != null ) {
      func( true, "upgrade C" );
    }

  }

  //-------------------------------------------------------------
  // Displays a dialog to the user to request what to do when
  // upgrading.
  private void request_upgrade_action( AfterLoadFunc? func ) {

    var dialog = new Granite.MessageDialog.with_image_from_icon_name(
      _( "Upgrade?" ),
      _( "This file is from an older version Minder and needs to be upgraded to edit.\n\nNote: Upgraded files cannot be viewed/edited with older versions of Minder." ),
      "system-software-update",
      ButtonsType.NONE
    );

    var cancel = new Button.with_label( _( "Cancel" ) );
    dialog.add_action_widget( cancel, ResponseType.CANCEL );

    var apply = new Button.with_label( _( "Apply" ) );
    dialog.add_action_widget( apply, ResponseType.APPLY );

    var options = new DropDown.from_strings( UpgradeAction.labels() ) {
      halign       = Align.START,
      margin_top   = 10,
      margin_start = 20,
      selected     = _map.settings.get_int( "upgrade-action" )
    };

    var remember = new CheckButton();
    var rem_description = new Label( _( "Don't show this dialog again" ) ) {
      halign = Align.START
    };
    var rem_info = new Label( _( "<small>This can be changed in preferences</small>" ) ) {
      halign     = Align.START,
      use_markup = true
    };
    var rem_grid = new Grid() {
      row_spacing  = 5,
      margin_start = 20,
      margin_top   = 20
    };

    rem_grid.attach( remember,        0, 0 );
    rem_grid.attach( rem_description, 1, 0 );
    rem_grid.attach( rem_info,        1, 1 );

    var box = dialog.get_content_area();
    box.append( options );
    box.append( rem_grid );

    dialog.set_transient_for( _map.win );
    dialog.set_modal( true );
    dialog.set_default_response( ResponseType.APPLY );
    dialog.set_title( _( "Upgrade Needed" ) );

    dialog.response.connect((id) => {
      if( id == ResponseType.APPLY ) {
        var action = (UpgradeAction)options.selected;
        _map.settings.set_int( "upgrade-action", action );
        _map.settings.set_boolean( "ask-for-upgrade-action", !remember.active );
        upgrade( action, func );
      } else if( (id == ResponseType.CANCEL) && (func != null) ) {
        func( false, "request_upgrade_action" );
      }
      dialog.close();
    });

    dialog.present();

  }

  //-------------------------------------------------------------
  // Auto-saves the document
  public void auto_save() {
    // save_xml();
  }

  //-------------------------------------------------------------
  // If this documen hasn't been named by the user but we are deleting
  // it, remove the unnamed file.  We don't touch the temporary directory
  // because we may need to save it with a given name.
  public bool remove() {
    if( !_from_user ) {
      FileUtils.unlink( _filename );
    }
    return( true );
  }

  //-------------------------------------------------------------
  // Recursively deletes a given directory.
  private void delete_recursively( File file ) throws Error {

    try {
      var enumerator = file.enumerate_children ( FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NOFOLLOW_SYMLINKS );
      FileInfo? info;
      while( (info = enumerator.next_file ()) != null ) {
        var child = file.get_child (info.get_name ());
        delete_recursively( child );
      }
    } catch (Error e) {
      // ignore if not a directory
    }

    // Finally delete the file or directory itself
    file.delete ();

  }

  //-------------------------------------------------------------
  // This should be called when the application is closing.  This
  // will cause the document to be stored in .minder format and
  // will clean up tmp space.
  public void cleanup() {

    // Force the save to occur.  There is nobody to ask while quitting, so if the
    // file was changed by someone else, keep their version and store ours next to it.
    if( _save_needed ) {
      var original = _filename;
      var conflict = externally_modified();
      if( conflict ) {
        var stamp = (new DateTime.now_local()).format( "%Y%m%d-%H%M%S" );
        var stem  = _filename.has_suffix( ".minder" ) ? _filename.substring( 0, _filename.length - 7 ) : _filename;
        _filename = "%s-conflict-%s.minder".printf( stem, stamp );
      }
      var saved = save( true, true );
      _filename = original;
      if( !saved ) {
        // Keep the work in the recovery copy, which belongs to the original file
        write_recovery();
        stderr.printf( "WARNING: Unsaved changes were kept in '%s'\n", recovery_file() );
        remove_temp_dir();
        return;
      }
      if( conflict ) {
        // The conflict copy holds our version; the original's recovery copy is stale
        remove_recovery();
      }
    }
    remove_recovery();
    remove_temp_dir();

  }

  //-------------------------------------------------------------
  // Deletes the temporary directory that holds the unarchived files.
  private void remove_temp_dir() {

    // Delete the temporary directory
    try {
      var dir = File.new_for_path( _temp_dir );
      delete_recursively( dir );
    } catch( Error e ) {}

  }

}
