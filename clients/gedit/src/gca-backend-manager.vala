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

namespace Gca
{

class BackendManager
{
	private static BackendManager s_instance;
	private Gee.HashMap<string, Backend?> d_backends;
	private Gee.HashMap<string, string> d_language_mapping;
	private Settings? d_settings;

	private BackendManager()
	{
		d_backends = new Gee.HashMap<string, Backend?>();

		d_settings = null;

		var source = SettingsSchemaSource.get_default();
		var schema = "org.gnome.gedit.plugins.codeassistance";

		if (source.lookup(schema, true) != null)
		{
			d_settings = new Settings(schema);
		}

		update_language_mapping();

		if (d_settings != null)
		{
			d_settings.changed["language-mapping"].connect(() => {
				update_language_mapping();
			});
		}
	}

	private void update_language_mapping()
	{
		d_language_mapping = new Gee.HashMap<string, string>();

		if (d_settings == null)
		{
			d_language_mapping["cpp"] = "c";
			d_language_mapping["chdr"] = "c";
			d_language_mapping["objc"] = "c";

			return;
		}

		var mapping = d_settings.get_value("language-mapping");

		if (mapping == null)
		{
			return;
		}

		var iter = mapping.iterator();

		string key = null;
		string val = null;

		while (iter.next("{ss}", &key, &val))
		{
			d_language_mapping[key] = val;
		}
	}

	public async Backend? backend(string language)
	{
		var lang = language;

		if (d_language_mapping.has_key(language))
		{
			lang = d_language_mapping[language];
		}

		if (d_backends.has_key(lang))
		{
			return d_backends[lang];
		}

		Backend? backend;

		try
		{
			backend = yield Backend.create(lang);
		}
		catch (IOError e)
		{
			Log.debug("Failed to obtain backend: %s\n", e.message);
			backend = null;
		}

		d_backends[lang] = backend;
		return backend;
	}

	public static BackendManager instance
	{
		get
		{
			if (s_instance == null)
			{
				s_instance = new BackendManager();
			}

			return s_instance;
		}
	}
}

}

/* vi:ex:ts=4 */
