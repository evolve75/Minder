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
 * Minimal Vala binding for libmarkdown (discount) 3.x, written from its public
 * header.  Version 3 replaced the integer flag word with a flag object; the
 * 2.x binding in libmarkdown.vapi covers older versions.
 */

[CCode (cheader_filename = "mkdio.h")]
namespace Markdown3 {

  // Flag numbers (the anonymous enum in mkdio.h)
  [CCode (cname = "MKD_NOPANTS")]        public const ulong NOPANTS;
  [CCode (cname = "MKD_1_COMPAT")]       public const ulong COMPAT_1;
  [CCode (cname = "MKD_TOC")]            public const ulong TOC;
  [CCode (cname = "MKD_AUTOLINK")]       public const ulong AUTOLINK;
  [CCode (cname = "MKD_EXTRA_FOOTNOTE")] public const ulong EXTRA_FOOTNOTE;
  [CCode (cname = "MKD_NOSTYLE")]        public const ulong NOSTYLE;
  [CCode (cname = "MKD_DLEXTRA")]        public const ulong DLEXTRA;
  [CCode (cname = "MKD_FENCEDCODE")]     public const ulong FENCEDCODE;
  [CCode (cname = "MKD_IDANCHOR")]       public const ulong IDANCHOR;
  [CCode (cname = "MKD_LATEX")]          public const ulong LATEX;

  [Compact]
  [CCode (cname = "mkd_flag_t", free_function = "mkd_free_flags", has_type_id = false)]
  public class Flags {
    [CCode (cname = "mkd_flags")]
    public Flags();
    [CCode (cname = "mkd_set_flag_num")]
    public void set_flag( ulong flag );
  }

  [Compact]
  [CCode (cname = "MMIOT", free_function = "mkd_cleanup", has_type_id = false)]
  public class Document {
    [CCode (cname = "gfm_string")]
    public Document.from_gfm_string( uint8[] doc, Flags flags );
    [CCode (cname = "mkd_compile")]
    public int compile( Flags flags );
    [CCode (cname = "mkd_document")]
    public int document( out unowned string text );
  }

}
