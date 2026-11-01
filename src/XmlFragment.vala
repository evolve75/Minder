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

/*
 * Safe handling of HTML fragments that must become XML elements.  The Markdown
 * converter's output is not guaranteed to be well-formed XML (and with some
 * libmarkdown versions it is only escaped text), so parsing can fail.
 */
public class XmlFragment {

  //-------------------------------------------------------------
  // Parses the HTML fragment and returns a copy of its root element.  If it
  // cannot be parsed, returns a new element named fallback_tag that holds
  // fallback_text instead.  The caller owns the returned node.
  public static Xml.Node* copy_root( string html, string fallback_tag, string fallback_text ) {

    Xml.Doc* doc = Xml.Parser.parse_memory( html, html.length );
    Xml.Node* result = null;

    if( doc != null ) {
      Xml.Node* root = doc->get_root_element();
      if( root != null ) {
        result = root->copy( 1 );
      }
      delete doc;
    }

    if( result == null ) {
      result = new Xml.Node( null, fallback_tag );
      result->add_content( fallback_text );
    }

    return( result );

  }

}
