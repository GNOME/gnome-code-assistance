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

using Gee;

namespace Gca
{

class Diagnostic : Object, SourceRangeSupport
{
	public enum Severity
	{
		NONE,
		INFO,
		WARNING,
		DEPRECATED,
		ERROR,
		FATAL;

		public string to_string()
		{
			switch (this)
			{
				case NONE:
					return "None";
				case INFO:
					return "Info";
				case WARNING:
					return "Warning";
				case DEPRECATED:
					return "Deprecated";
				case ERROR:
					return "Error";
				case FATAL:
					return "Fatal";
				default:
					return "Unknown";
			}
		}
	}

	public struct Fixit
	{
		public SourceRange range;
		public string replacement;
	}

	private SourceRange[] d_location;
	private Fixit[] d_fixits;
	private Severity d_severity;
	private string d_message;

	public Diagnostic(Severity       severity,
	                  SourceRange[]  location,
	                  Fixit[]        fixits,
	                  string         message)
	{
		d_severity = severity;
		d_location = location;
		d_fixits = fixits;
		d_message = message;
	}

	public SourceRange[] ranges
	{
		owned get
		{
			return d_location;
		}
	}

	public Fixit[] fixits
	{
		get { return d_fixits; }
	}

	public Severity severity
	{
		get { return d_severity; }
	}

	public string message
	{
		get { return d_message; }
	}

	public SourceRange[] location
	{
		get { return d_location; }
	}

	private string loc_string()
	{
		string[] r = new string[d_location.length];

		for (int i = 0; i < d_location.length; ++i)
		{
			r[i] = d_location[i].to_string();
		}

		return string.joinv(", ", r);
	}

	public string to_markup(bool include_severity = true)
	{
		if (include_severity)
		{
			return "<b>%s</b> %s: %s".printf(d_severity.to_string(),
			                                 loc_string(),
			                                 Markup.escape_text(d_message));
		}
		else
		{
			return "%s: %s".printf(loc_string(), Markup.escape_text(d_message));
		}
	}
}

}

/* vi:ex:ts=4 */
