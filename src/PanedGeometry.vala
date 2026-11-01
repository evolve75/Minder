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
 * Pane sizing rules, kept free of widgets so they can be tested.
 */
public class PanedGeometry {

  public const int MIN_SIDEBAR     = 250;
  public const int MAX_SIDEBAR     = 600;
  public const int DEFAULT_SIDEBAR = 300;
  public const int MIN_CANVAS      = 300;

  //-------------------------------------------------------------
  // Returns the sidebar width to use, given the saved setting and the total
  // width of the pane.  Older builds stored the canvas width in the setting, so
  // a value outside the sane sidebar range is ignored; the canvas always keeps
  // at least MIN_CANVAS.
  public static int sidebar_width( int saved, int total ) {
    var width = ((saved < MIN_SIDEBAR) || (saved > MAX_SIDEBAR)) ? DEFAULT_SIDEBAR : saved;
    return( width.clamp( MIN_SIDEBAR, int.max( MIN_SIDEBAR, total - MIN_CANVAS ) ) );
  }

}
