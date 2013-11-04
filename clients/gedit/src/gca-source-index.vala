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

class SourceIndex<T> : Object
{
	public class Wrapper : Object
	{
		public SourceRangeSupport? obj;
		public SourceRange range;
		public int idx;
		public bool encapsulated;

		public Wrapper(SourceRangeSupport? obj, SourceRange range, int idx)
		{
			this.obj = obj;
			this.range = range;
			this.idx = idx;

			encapsulated = false;
		}
	}

	public class Iterator<T> : Object
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

		public new T get()
		{
			return (T)d_iter.get().obj;
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

	public int length
	{
		get { return d_index.get_length(); }
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

	public T[] find_at_line(int line)
	{
		var loc = SourceLocation() {
			line = line,
			column = 0
		};

		return find_at_priv(loc.to_range(), FindFlags.LINE_ONLY);
	}

	public T[] find_at(SourceRange range)
	{
		return find_at_priv(range, FindFlags.NONE);
	}

	private bool find_at_condition(Wrapper     wrapper,
	                               SourceRange range,
	                               FindFlags   flags)
	{
		bool lineonly = (flags & FindFlags.LINE_ONLY) != 0;

		if (lineonly)
		{
			return wrapper.range.contains_line(range.start.line) &&
			       wrapper.range.contains_line(range.end.line);
		}
		else
		{
			return wrapper.range.contains_range(range);
		}
	}

	private T[] find_at_priv(SourceRange range,
	                         FindFlags   flags)
	{
		LinkedList<T> ret = new LinkedList<Object>();

		SequenceIter<Wrapper> iter;
		var uniq = new HashMap<Object, bool>();

		iter = d_index.search(new Wrapper(null, range, 0), compare_func);

		if ((flags & FindFlags.INNER_MOST) != 0)
		{
			while (!iter.is_begin())
			{
				iter = iter.prev();

				if (find_at_condition(iter.get(), range, flags))
				{
					return new T[] {(T)iter.get().obj};
				}
				else if (!iter.get().encapsulated)
				{
					break;
				}
			}

			return new T[] {};
		}

		// Go back to find ranges that encapsulate the location
		if (!iter.is_begin())
		{
			SequenceIter<Wrapper> prev = iter.prev();

			while (find_at_condition(prev.get(), range, flags) ||
			       prev.get().encapsulated)
			{
				var val = prev.get().obj;

				if (find_at_condition(prev.get(), range, flags) &&
				    !uniq.has_key(val))
				{
					ret.insert(0, (T)val);
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
		       (find_at_condition(iter.get(), range, flags) ||
		        iter.get().encapsulated))
		{
			var val = iter.get().obj;

			if (find_at_condition(iter.get(), range, flags) && !uniq.has_key(val))
			{
				ret.add((T)val);
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

	public Iterator<T> iterator()
	{
		return new Iterator<T>(d_index.get_begin_iter());
	}
}

}

/* vi:ex:ts=4 */
