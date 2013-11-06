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

	private static Gee.HashMap<string, string> s_languageMapping;

	static construct
	{
		// TODO: use gsettings to make this user configurable
		s_languageMapping = new Gee.HashMap<string, string>();

		s_languageMapping["cpp"] = "c";
		s_languageMapping["objc"] = "c";
		s_languageMapping["chdr"] = "c";
	}

	private BackendManager()
	{
		d_backends = new Gee.HashMap<string, Backend?>();
	}

	public async Backend? backend(string language)
	{
		var lang = language;

		if (s_languageMapping.has_key(language))
		{
			lang = s_languageMapping[language];
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
