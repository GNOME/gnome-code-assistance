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

public class Diagnostic : Object, SourceRangeSupport
{
	public enum Severity
	{
		NONE,
		INFO,
		WARNING,
		ERROR,
		FATAL,
		NUM;

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
				case ERROR:
					return "Error";
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

	private SourceLocation d_location;
	private SourceRange[] d_ranges;
	private SourceRange[]? d_rangesAndLocation;
	private Fixit[] d_fixits;
	private Severity d_severity;
	private string d_message;

	public Diagnostic(Severity       severity,
	                  SourceLocation location,
	                  SourceRange[]  ranges,
	                  Fixit[]        fixits,
	                  string         message)
	{
		d_severity = severity;
		d_location = location;
		d_ranges = ranges;
		d_fixits = fixits;
		d_message = message;
	}

	public SourceLocation location
	{
		get { return d_location; }
	}

	public SourceRange? range
	{
		owned get { return d_location.range; }
	}

	public SourceRange[] ranges
	{
		owned get
		{
			if (d_rangesAndLocation == null)
			{
				d_rangesAndLocation = new SourceRange[d_ranges.length + 1];
				d_rangesAndLocation[0] = d_location.range;

				for (int i = 0; i < d_ranges.length; ++i)
				{
					d_rangesAndLocation[i + 1] = d_ranges[i];
				}
			}

			return d_rangesAndLocation;
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

	private string loc_string()
	{
		string[] r = new string[d_ranges.length];

		for (int i = 0; i < d_ranges.length; ++i)
		{
			r[i] = d_ranges[i].to_string();
		}

		string loc = "%s".printf(d_location.to_string());

		if (r.length > 0)
		{
			loc = "%s at %s".printf(string.joinv(", ", r), loc);
		}

		return loc;
	}

	public string to_string()
	{
		return "%s %s: %s".printf(d_severity.to_string(), loc_string(), d_message);
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
