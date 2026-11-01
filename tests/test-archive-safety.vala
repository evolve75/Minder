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

namespace MinderTest {

  public class ArchiveSafetyTest : TestSuite {

    public ArchiveSafetyTest() {
      this.add_test( "plain-names", test_plain_names );
      this.add_test( "traversal-refused", test_traversal );
      this.add_test( "absolute-refused", test_absolute );
      this.add_test( "entry-types", test_entry_types );
    }

    private void test_plain_names() {
      Assert.true( ArchiveSafety.is_safe_name( "map.xml" ) );
      Assert.true( ArchiveSafety.is_safe_name( "images/12.png" ) );
      Assert.true( ArchiveSafety.is_safe_name( "a..b/c" ) );
    }

    private void test_traversal() {
      Assert.false( ArchiveSafety.is_safe_name( "../x" ) );
      Assert.false( ArchiveSafety.is_safe_name( "a/../../x" ) );
      Assert.false( ArchiveSafety.is_safe_name( "a/.." ) );
      Assert.false( ArchiveSafety.is_safe_name( "..\\x" ) );
      Assert.false( ArchiveSafety.is_safe_name( "a\\..\\..\\x" ) );
    }

    private void test_absolute() {
      Assert.false( ArchiveSafety.is_safe_name( "/etc/passwd" ) );
      Assert.false( ArchiveSafety.is_safe_name( "\\windows" ) );
      Assert.false( ArchiveSafety.is_safe_name( "" ) );
      Assert.false( ArchiveSafety.is_safe_name( null ) );
    }

    private void test_entry_types() {
      var entry = new Archive.Entry();
      entry.set_pathname( "1.png" );
      entry.set_filetype( Archive.FileType.IFREG );
      Assert.true( ArchiveSafety.is_safe_entry( entry ) );

      entry.set_filetype( Archive.FileType.IFLNK );
      entry.set_symlink( "/etc/passwd" );
      Assert.false( ArchiveSafety.is_safe_entry( entry ) );

      var linked = new Archive.Entry();
      linked.set_pathname( "2.png" );
      linked.set_filetype( Archive.FileType.IFREG );
      linked.set_hardlink( "1.png" );
      Assert.false( ArchiveSafety.is_safe_entry( linked ) );

      var escape = new Archive.Entry();
      escape.set_pathname( "../../.zshrc" );
      escape.set_filetype( Archive.FileType.IFREG );
      Assert.false( ArchiveSafety.is_safe_entry( escape ) );
    }

  }

}
