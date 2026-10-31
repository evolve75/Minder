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

#include "live-action.h"

struct _MinderLiveAction
{
  GObject                      parent_instance;
  gchar                       *name;
  MinderLiveActionEnabledFunc  enabled_func;
  gpointer                     enabled_data;
  GDestroyNotify               enabled_destroy;
  MinderLiveActionActivateFunc activate_func;
  gpointer                     activate_data;
  GDestroyNotify               activate_destroy;
};

enum { PROP_NAME = 1, PROP_PARAMETER_TYPE, PROP_ENABLED, PROP_STATE_TYPE, PROP_STATE };

static const gchar *
live_get_name (GAction *action)
{
  return MINDER_LIVE_ACTION (action)->name;
}

static const GVariantType *
live_get_parameter_type (GAction *action)
{
  return NULL;
}

static const GVariantType *
live_get_state_type (GAction *action)
{
  return NULL;
}

static GVariant *
live_get_state_hint (GAction *action)
{
  return NULL;
}

static gboolean
live_get_enabled (GAction *action)
{
  MinderLiveAction *self = MINDER_LIVE_ACTION (action);
  return self->enabled_func != NULL && self->enabled_func (self->enabled_data);
}

static GVariant *
live_get_state (GAction *action)
{
  return NULL;
}

static void
live_change_state (GAction *action, GVariant *value)
{
}

static void
live_activate (GAction *action, GVariant *parameter)
{
  MinderLiveAction *self = MINDER_LIVE_ACTION (action);
  if (live_get_enabled (action) && self->activate_func != NULL)
    self->activate_func (self->activate_data);
}

static void
live_action_iface_init (GActionInterface *iface)
{
  iface->get_name           = live_get_name;
  iface->get_parameter_type = live_get_parameter_type;
  iface->get_state_type     = live_get_state_type;
  iface->get_state_hint     = live_get_state_hint;
  iface->get_enabled        = live_get_enabled;
  iface->get_state          = live_get_state;
  iface->change_state       = live_change_state;
  iface->activate           = live_activate;
}

G_DEFINE_TYPE_WITH_CODE (MinderLiveAction, minder_live_action, G_TYPE_OBJECT,
                         G_IMPLEMENT_INTERFACE (G_TYPE_ACTION, live_action_iface_init))

static void
live_get_property (GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
  GAction *action = G_ACTION (object);

  switch (prop_id)
    {
    case PROP_NAME:           g_value_set_string  (value, live_get_name (action));    break;
    case PROP_PARAMETER_TYPE: g_value_set_boxed   (value, NULL);                      break;
    case PROP_ENABLED:        g_value_set_boolean (value, live_get_enabled (action)); break;
    case PROP_STATE_TYPE:     g_value_set_boxed   (value, NULL);                      break;
    case PROP_STATE:          g_value_set_variant (value, NULL);                      break;
    default:                  G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
live_finalize (GObject *object)
{
  MinderLiveAction *self = MINDER_LIVE_ACTION (object);

  if (self->enabled_destroy != NULL)
    self->enabled_destroy (self->enabled_data);
  if (self->activate_destroy != NULL)
    self->activate_destroy (self->activate_data);
  g_free (self->name);

  G_OBJECT_CLASS (minder_live_action_parent_class)->finalize (object);
}

static void
minder_live_action_class_init (MinderLiveActionClass *klass)
{
  GObjectClass *oclass = G_OBJECT_CLASS (klass);

  oclass->get_property = live_get_property;
  oclass->finalize     = live_finalize;

  g_object_class_override_property (oclass, PROP_NAME,           "name");
  g_object_class_override_property (oclass, PROP_PARAMETER_TYPE, "parameter-type");
  g_object_class_override_property (oclass, PROP_ENABLED,        "enabled");
  g_object_class_override_property (oclass, PROP_STATE_TYPE,     "state-type");
  g_object_class_override_property (oclass, PROP_STATE,          "state");
}

static void
minder_live_action_init (MinderLiveAction *self)
{
}

MinderLiveAction *
minder_live_action_new (const gchar                 *name,
                        MinderLiveActionEnabledFunc  enabled_func,
                        gpointer                     enabled_data,
                        GDestroyNotify               enabled_destroy,
                        MinderLiveActionActivateFunc activate_func,
                        gpointer                     activate_data,
                        GDestroyNotify               activate_destroy)
{
  MinderLiveAction *self = g_object_new (MINDER_TYPE_LIVE_ACTION, NULL);

  self->name             = g_strdup (name);
  self->enabled_func     = enabled_func;
  self->enabled_data     = enabled_data;
  self->enabled_destroy  = enabled_destroy;
  self->activate_func    = activate_func;
  self->activate_data    = activate_data;
  self->activate_destroy = activate_destroy;

  return self;
}

/* Tells menus to re-query the enabled state */
void
minder_live_action_refresh (MinderLiveAction *self)
{
  g_object_notify (G_OBJECT (self), "enabled");
}
