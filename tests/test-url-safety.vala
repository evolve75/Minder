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

  public class UrlSafetyTest : TestSuite {

    public UrlSafetyTest() {
      this.add_test( "web-links", test_web );
      this.add_test( "other-schemes-refused", test_schemes );
      this.add_test( "file-links", test_files );
    }

    private void test_web() {
      Assert.true( UrlSafety.is_safe_url( "https://example.com/a?b=c" ) );
      Assert.true( UrlSafety.is_safe_url( "HTTP://example.com" ) );
      Assert.true( UrlSafety.is_safe_url( "mailto:someone@example.com" ) );
    }

    private void test_schemes() {
      Assert.false( UrlSafety.is_safe_url( "smb://server/share" ) );
      Assert.false( UrlSafety.is_safe_url( "afp://server/share" ) );
      Assert.false( UrlSafety.is_safe_url( "vnc://server" ) );
      Assert.false( UrlSafety.is_safe_url( "javascript:alert(1)" ) );
      Assert.false( UrlSafety.is_safe_url( "example.com" ) );
      Assert.false( UrlSafety.is_safe_url( "" ) );
    }

    private void test_files() {
      Assert.true( UrlSafety.is_safe_url( "file:///Users/someone/notes.pdf" ) );
      Assert.true( UrlSafety.is_safe_url( "file:///tmp/" ) );
      Assert.false( UrlSafety.is_safe_url( "file:///Applications/Calculator.app" ) );
      Assert.false( UrlSafety.is_safe_url( "file:///tmp/run.COMMAND" ) );
      Assert.false( UrlSafety.is_safe_url( "file://remote-host/share/x.txt" ) );
      Assert.false( UrlSafety.is_safe_url( "file:///bin/sh" ) );
    }

  }

}
