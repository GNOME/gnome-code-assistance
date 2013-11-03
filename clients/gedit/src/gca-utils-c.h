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

#ifndef __GCA_UTILS_C_H__
#define __GCA_UTILS_C_H__

#include <glib-object.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GCA_TYPE_UTILS_C		(gca_utils_c_get_type ())
#define GCA_UTILS_C(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GCA_TYPE_UTILS_C, GcaUtilsC))
#define GCA_UTILS_C_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GCA_TYPE_UTILS_C, GcaUtilsC const))
#define GCA_UTILS_C_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GCA_TYPE_UTILS_C, GcaUtilsCClass))
#define GCA_IS_UTILS_C(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GCA_TYPE_UTILS_C))
#define GCA_IS_UTILS_C_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GCA_TYPE_UTILS_C))
#define GCA_UTILS_C_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GCA_TYPE_UTILS_C, GcaUtilsCClass))

typedef struct _GcaUtilsC		GcaUtilsC;
typedef struct _GcaUtilsCClass		GcaUtilsCClass;
typedef struct _GcaUtilsCPrivate	GcaUtilsCPrivate;

struct _GcaUtilsC
{
	GObject parent;

	GcaUtilsCPrivate *priv;
};

struct _GcaUtilsCClass
{
	GObjectClass parent_class;
};

GType gca_utils_c_get_type (void) G_GNUC_CONST;

gint gca_utils_c_get_style_property_int (GtkStyleContext *context,
                                         gchar const     *name);

void gca_utils_c_get_range_rect (GtkRange *range, GdkRectangle *rect);

G_END_DECLS

#endif /* __GCA_UTILS_C_H__ */
