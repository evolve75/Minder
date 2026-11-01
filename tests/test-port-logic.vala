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

  public class PortLogicTest : TestSuite {

    public PortLogicTest() {
      this.add_test( "text-content-ignores-indentation", test_text_content_indentation );
      this.add_test( "text-content-real-text", test_text_content_real );
      this.add_test( "sidebar-default", test_sidebar_default );
      this.add_test( "sidebar-legacy-canvas-width", test_sidebar_legacy );
      this.add_test( "sidebar-keeps-canvas-room", test_sidebar_room );
      this.add_test( "recent-newest-first", test_recent_order );
      this.add_test( "recent-no-duplicates", test_recent_dedup );
      this.add_test( "recent-capped", test_recent_cap );
      this.add_test( "recent-remove", test_recent_remove );
      this.add_test( "recent-labels", test_recent_label );
    }

    private bool first_child_has_text( string xml ) {
      Xml.Doc* doc = Xml.Parser.parse_memory( xml, xml.length );
      Assert.true( doc != null );
      var result = XmlFragment.has_text_content( doc->get_root_element() );
      delete doc;
      return( result );
    }

    // An indented file puts a blank text node before the child element
    private void test_text_content_indentation() {
      Assert.false( first_child_has_text( "<node>\n  <style/>\n  <text/>\n</node>" ) );
      Assert.false( first_child_has_text( "<node/>" ) );
    }

    private void test_text_content_real() {
      Assert.true( first_child_has_text( "<node>hello</node>" ) );
      Assert.true( first_child_has_text( "<node>  padded  <b/></node>" ) );
    }

    private void test_sidebar_default() {
      Assert.int_compare( 300, PanedGeometry.sidebar_width( 300, 1000 ) );
      Assert.int_compare( 420, PanedGeometry.sidebar_width( 420, 1000 ) );
    }

    // The old setting held the canvas width (e.g. 1356); it must not become the sidebar width
    private void test_sidebar_legacy() {
      Assert.int_compare( 300, PanedGeometry.sidebar_width( 1356, 2000 ) );
      Assert.int_compare( 300, PanedGeometry.sidebar_width( 0, 2000 ) );
      Assert.int_compare( 300, PanedGeometry.sidebar_width( 100, 2000 ) );
    }

    private void test_sidebar_room() {
      Assert.int_compare( 250, PanedGeometry.sidebar_width( 600, 550 ) );   // tiny window: floor
      Assert.int_compare( 500, PanedGeometry.sidebar_width( 600, 800 ) );   // canvas keeps 300
    }

    private void test_recent_order() {
      var list = RecentFiles.add( RecentFiles.add( {}, "/a.minder" ), "/b.minder" );
      Assert.int_compare( 2, list.length );
      Assert.string_compare( "/b.minder", list[0] );
      Assert.string_compare( "/a.minder", list[1] );
    }

    private void test_recent_dedup() {
      var list = RecentFiles.add( RecentFiles.add( RecentFiles.add( {}, "/a" ), "/b" ), "/a" );
      Assert.int_compare( 2, list.length );
      Assert.string_compare( "/a", list[0] );
      Assert.string_compare( "/b", list[1] );
    }

    private void test_recent_cap() {
      string[] list = {};
      for( int i=0; i<(RecentFiles.MAX + 5); i++ ) {
        list = RecentFiles.add( list, "/f%d".printf( i ) );
      }
      Assert.int_compare( RecentFiles.MAX, list.length );
      Assert.string_compare( "/f%d".printf( RecentFiles.MAX + 4 ), list[0] );
    }

    private void test_recent_remove() {
      var list = RecentFiles.remove( {"/a", "/b", "/c"}, "/b" );
      Assert.int_compare( 2, list.length );
      Assert.string_compare( "/c", list[1] );
    }

    private void test_recent_label() {
      string[] list = {"/x/map.minder", "/y/map.minder", "/x/other.minder"};
      Assert.string_compare( "other.minder", RecentFiles.label( list, "/x/other.minder" ) );
      Assert.true( RecentFiles.label( list, "/x/map.minder" ).contains( "/x" ) );
    }


  }

}
