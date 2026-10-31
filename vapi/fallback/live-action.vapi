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
 * Vala binding for src/live-action.c: a GLib.Action whose enabled state is
 * computed every time it is queried.
 */

[CCode (cheader_filename = "live-action.h")]
public delegate bool LiveActionEnabledFunc();

[CCode (cheader_filename = "live-action.h")]
public delegate void LiveActionActivateFunc();

[CCode (cheader_filename = "live-action.h", cname = "MinderLiveAction", type_id = "minder_live_action_get_type ()")]
public class LiveAction : GLib.Object, GLib.Action {
  [CCode (cname = "minder_live_action_new")]
  public LiveAction( string name, owned LiveActionEnabledFunc is_enabled, owned LiveActionActivateFunc do_activate );
  [CCode (cname = "minder_live_action_refresh")]
  public void refresh();
}
