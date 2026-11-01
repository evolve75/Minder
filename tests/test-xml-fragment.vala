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

  public class XmlFragmentTest : TestSuite {

    public XmlFragmentTest() {
      this.add_test( "well-formed", test_well_formed );
      this.add_test( "malformed-falls-back", test_malformed );
      this.add_test( "empty-falls-back", test_empty );
    }

    private void test_well_formed() {
      Xml.Node* n = XmlFragment.copy_root( "<body><p>hello</p></body>", "body", "fallback" );
      Assert.string_compare( "body", n->name );
      Assert.string_compare( "hello", n->children->get_content() );
      delete n;
    }

    private void test_malformed() {
      Xml.Node* n = XmlFragment.copy_root( "<body><p>unclosed", "body", "the note text" );
      Assert.string_compare( "body", n->name );
      Assert.string_compare( "the note text", n->get_content() );
      delete n;
    }

    private void test_empty() {
      Xml.Node* n = XmlFragment.copy_root( "", "html", "plain" );
      Assert.string_compare( "html", n->name );
      Assert.string_compare( "plain", n->get_content() );
      delete n;
    }

  }

}
