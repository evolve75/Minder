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
 * A GAction whose enabled state is computed every time it is queried, instead
 * of being stored.  macOS validates menu key equivalents at the moment a key is
 * pressed, so a stored flag refreshed later could trigger a command for a key
 * that belongs to the widget being typed into.  (Written in C because the
 * GAction interface cannot be implemented from Vala: its property getters and
 * interface methods generate the same symbols.)
 */

#ifndef MINDER_LIVE_ACTION_H
#define MINDER_LIVE_ACTION_H

#include <gio/gio.h>

G_BEGIN_DECLS

#define MINDER_TYPE_LIVE_ACTION (minder_live_action_get_type ())
G_DECLARE_FINAL_TYPE (MinderLiveAction, minder_live_action, MINDER, LIVE_ACTION, GObject)

typedef gboolean (*MinderLiveActionEnabledFunc)  (gpointer user_data);
typedef void     (*MinderLiveActionActivateFunc) (gpointer user_data);

MinderLiveAction *minder_live_action_new     (const gchar                 *name,
                                              MinderLiveActionEnabledFunc  enabled_func,
                                              gpointer                     enabled_data,
                                              GDestroyNotify               enabled_destroy,
                                              MinderLiveActionActivateFunc activate_func,
                                              gpointer                     activate_data,
                                              GDestroyNotify               activate_destroy);
void              minder_live_action_refresh (MinderLiveAction            *self);

G_END_DECLS

#endif /* MINDER_LIVE_ACTION_H */
