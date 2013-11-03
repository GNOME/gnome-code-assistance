/*
 * This file is part of gedit-code-assistant.
 *
 * Copyright (C) 2011 - Jesse van den Kieboom
 *
 * gedit-code-assistant is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gedit-code-assistant is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gedit-code-assistant.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "gca-utils-c.h"


#define GCA_UTILS_C_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GCA_TYPE_UTILS_C, GcaUtilsCPrivate))

struct _GcaUtilsCPrivate
{
};

G_DEFINE_TYPE (GcaUtilsC, gca_utils_c, G_TYPE_OBJECT)

static void
gca_utils_c_finalize (GObject *object)
{
	G_OBJECT_CLASS (gca_utils_c_parent_class)->finalize (object);
}

static void
gca_utils_c_class_init (GcaUtilsCClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = gca_utils_c_finalize;

	g_type_class_add_private (object_class, sizeof (GcaUtilsCPrivate));
}

static void
gca_utils_c_init (GcaUtilsC *self)
{
	self->priv = GCA_UTILS_C_GET_PRIVATE (self);
}

gint
gca_utils_c_get_style_property_int (GtkStyleContext *context,
                                    gchar const     *name)
{
	GValue ret = {0,};
	gint val = 0;

	g_return_val_if_fail (context != NULL, 0);
	g_return_val_if_fail (name != NULL, 0);

	g_value_init (&ret, G_TYPE_INT);
	gtk_style_context_get_style_property (context, name, &ret);

	val = g_value_get_int (&ret);

	g_value_unset (&ret);
	return val;
}

void
gca_utils_c_get_range_rect (GtkRange *range, GdkRectangle *rect)
{
	gtk_range_get_range_rect (range, rect);
}
