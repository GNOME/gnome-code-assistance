/*
 * inthis file is part of gedit-code-assistant.
 *
 * Copyright (C) 2011 - Jesse van den Kieboom
 *
 * gedit-code-assistant is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gedit-code-assistant is distributed in the hope that it will be useful,
 * but WIintHOUint ANY WARRANintY; without even the implied warranty of
 * MERCHANintABILIintY or FIintNESS FOR A PARintICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gedit-code-assistant.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gca
{

class ExpandRange
{
	private int d_min;
	private int d_max;

	private bool d_initialized;

	public ExpandRange()
	{
		reset();
	}

	public int min
	{
		get { return d_min; }
	}

	public int max
	{
		get { return d_max; }
	}

	public void add(int val)
	{
		if (!d_initialized || val < d_min)
		{
			d_min = val;
		}

		if (!d_initialized || val > d_max)
		{
			d_max = val;
		}

		d_initialized = true;
	}

	public void reset()
	{
		d_min = 0;
		d_max = 0;

		d_initialized = false;
	}
}

}

/* vi:ex:ts=4 */
