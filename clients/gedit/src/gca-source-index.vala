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

public class SourceIndex : Object
{
	public class Wrapper : Object
	{
		public SourceRangeSupport obj;
		public SourceRange range;
		public int idx;
		public bool encapsulated;

		public Wrapper(SourceRangeSupport obj, SourceRange range, int idx)
		{
			this.obj = obj;
			this.range = range;
			this.idx = idx;

			encapsulated = false;
		}
	}

	public class Iterator : Object
	{
		private SequenceIter<Wrapper> d_iter;
		private bool d_first;

		public Iterator(SequenceIter<Wrapper> iter)
		{
			d_iter = iter;
			d_first = true;
		}

		public bool next()
		{
			if (d_first)
			{
				d_first = false;
			}
			else if (!d_iter.is_end())
			{
				d_iter = d_iter.next();
			}

			return !d_iter.is_end();
		}

		public new Object get()
		{
			return d_iter.get().obj;
		}
	}

	[Flags]
	private enum FindFlags
	{
		NONE = 0,
		LINE_ONLY = 1 << 0,
		INNER_MOST = 1 << 1
	}

	private Sequence<Wrapper> d_index;

	construct
	{
#if VALA_0_14
		d_index = new Sequence<Wrapper>();
#else
		d_index = new Sequence<Wrapper>(null);
#endif
	}

	public void add(SourceRangeSupport range)
	{
		wrap_each(range, wrapper => {
			// Find out if it's encapsulated
			SequenceIter<Wrapper> iter = d_index.search(wrapper, compare_func);
			SequenceIter<Wrapper> prev = iter;

			while (!prev.is_begin())
			{
				prev = prev.prev();

				if (prev.get().range.contains_range(wrapper.range))
				{
					wrapper.encapsulated = true;
					break;
				}

				if (!prev.get().encapsulated)
				{
					break;
				}
			}

			iter = Sequence<Wrapper>.insert_before(iter, wrapper);

			while (!iter.is_end() && wrapper.range.contains_range(iter.get().range))
			{
				iter.get().encapsulated = true;
				iter = iter.next();
			}
		});
	}

	public new Object? get(int idx)
	{
		SequenceIter<Wrapper>? iter = d_index.get_iter_at_pos(idx);

		if (iter == null)
		{
			return null;
		}

		return iter.get().obj;
	}

	public int length
	{
		get { return d_index.get_length(); }
	}

	private SequenceIter<Wrapper>? find_iter(Wrapper wrapper)
	{
		SequenceIter<Wrapper>? iter;

		iter = d_index.search(wrapper, compare_func);

		if (iter == null)
		{
			return null;
		}

		// Move back on same
		while (!iter.is_begin())
		{
			SequenceIter<Wrapper> prev = iter.prev();

			if (prev.get().range.compare_to(wrapper.range) != 0)
			{
				break;
			}

			iter = prev;
		}

		// Move forward until find, or end, or not same
		while (!iter.is_end() &&
		       iter.get().range.compare_to(wrapper.range) == 0 &&
		       iter.get().obj != wrapper.obj)
		{
			iter = iter.next();
		}

		return iter.get().obj == wrapper.obj ? iter : null;
	}

	private delegate void WrapEachFunc(Wrapper wrapper);

	private void wrap_each(SourceRangeSupport range, WrapEachFunc func)
	{
		SourceRange[] ranges = range.ranges;

		for (int i = 0; i < ranges.length; ++i)
		{
			func(new Wrapper(range, ranges[i], i));
		}
	}

	public void remove(SourceRangeSupport range)
	{
		wrap_each(range, (wrapper) => {
			SequenceIter<Wrapper>? iter;

			iter = find_iter(wrapper);

			if (iter != null)
			{
				Sequence<Wrapper>.remove(iter);
			}
		});
	}

	public Object[] find_at_line(int line)
	{
		return find_at_priv(new SourceLocation(null, line, 0), FindFlags.LINE_ONLY);
	}

	public Object[] find_at(SourceLocation location)
	{
		return find_at_priv(location, FindFlags.NONE);
	}

	public Object? find_inner_at(SourceLocation location)
	{
		Object[] ret = find_at_priv(location, FindFlags.INNER_MOST);

		if (ret.length == 0)
		{
			return null;
		}
		else
		{
			return (owned)ret[0];
		}
	}

	private bool find_at_condition(Wrapper wrapper,
	                               SourceLocation location,
	                               FindFlags flags)
	{
		bool lineonly = (flags & FindFlags.LINE_ONLY) != 0;

		return (lineonly && wrapper.range.contains_line(location.line)) ||
		       (!lineonly && wrapper.range.contains_location(location));
	}

	private Object[] find_at_priv(SourceLocation location,
	                         FindFlags flags)
	{
		LinkedList<Object> ret = new LinkedList<Object>();

		SequenceIter<Wrapper> iter;
		HashMap<Object, bool> uniq = new HashMap<Object, bool>(direct_hash, direct_equal);

		iter = d_index.search(new Wrapper(location, location.range, 0), compare_func);

		if ((flags & FindFlags.INNER_MOST) != 0)
		{
			while (!iter.is_begin())
			{
				iter = iter.prev();

				if (find_at_condition(iter.get(), location, flags))
				{
					return new Object[] {iter.get().obj};
				}
				else if (!iter.get().encapsulated)
				{
					break;
				}
			}

			return new Object[] {};
		}

		// Go back to find ranges that encapsulate the location
		if (!iter.is_begin())
		{
			SequenceIter<Wrapper> prev = iter.prev();

			while (find_at_condition(prev.get(), location, flags) ||
			       prev.get().encapsulated)
			{
				Object val = (Object)prev.get().obj;

				if (find_at_condition(prev.get(), location, flags) &&
				    !uniq.has_key(val))
				{
					ret.insert(0, val);
					uniq[val] = true;
				}

				if (prev.is_begin())
				{
					break;
				}

				prev = prev.prev();
			}
		}

		// Then move with iter forward
		while (!iter.is_end() &&
		       (find_at_condition(iter.get(), location, flags) ||
		        iter.get().encapsulated))
		{
			Object val = (Object)iter.get().obj;

			if (find_at_condition(iter.get(), location, flags) && !uniq.has_key(val))
			{
				ret.add(val);
				uniq[val] = true;
			}

			iter = iter.next();
		}

		return ret.to_array();
	}

	public void clear()
	{
		Sequence<Wrapper>.remove_range(d_index.get_begin_iter(), d_index.get_end_iter());
	}

	private int compare_func(Wrapper a, Wrapper b)
	{
		SourceRange ra = a.range;
		SourceRange rb = b.range;

		return ra.compare_to(rb);
	}

	public Iterator iterator()
	{
		return new Iterator(d_index.get_begin_iter());
	}
}

}

/* vi:ex:ts=4 */
