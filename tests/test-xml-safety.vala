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

  public class XmlSafetyTest : TestSuite {

    public XmlSafetyTest() {
      this.add_test( "plain-document", test_plain );
      this.add_test( "entities-refused", test_entities );
      this.add_test( "utf16-refused", test_utf16 );
      this.add_test( "deep-document", test_deep );
      this.add_test( "file", test_file );
    }

    private void test_plain() {
      Xml.Doc* doc = XmlSafety.read_memory( "<a><b>text</b></a>" );
      Assert.true( doc != null );
      delete doc;
    }

    private void test_entities() {
      var bomb = "<?xml version=\"1.0\"?><!DOCTYPE a [<!ENTITY x \"aaaaaaaaaa\"><!ENTITY y \"&x;&x;&x;&x;\">]><a>&y;&y;</a>";
      Assert.true( XmlSafety.declares_entity( bomb.data ) );
      Assert.true( XmlSafety.read_memory( bomb ) == null );
    }

    private void test_utf16() {
      uint8[] wide = { 0xff, 0xfe, '<', 0, 'a', 0, '/', 0, '>', 0 };
      Assert.true( XmlSafety.read_bytes( wide ) == null );
    }

    // Nesting past libxml2's default limit of 256 levels still loads
    private void test_deep() {
      var sb = new StringBuilder();
      for( int i=0; i<400; i++ ) sb.append( "<n>" );
      for( int i=0; i<400; i++ ) sb.append( "</n>" );
      Xml.Doc* doc = XmlSafety.read_memory( sb.str );
      Assert.true( doc != null );
      delete doc;
    }

    private void test_file() {
      try {
        var dir  = DirUtils.make_tmp( "minder-xml-test-XXXXXX" );
        var path = Path.build_filename( dir, "a.xml" );
        FileUtils.set_contents( path, "<a/>" );
        Xml.Doc* doc = XmlSafety.read_file( path );
        Assert.true( doc != null );
        delete doc;
        Assert.true( XmlSafety.read_file( Path.build_filename( dir, "missing.xml" ) ) == null );
        FileUtils.unlink( path );
        DirUtils.remove( dir );
      } catch( Error e ) {
        Assert.true( false );
      }
    }

  }

}
