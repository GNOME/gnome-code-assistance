using Gtk;

namespace Gcp
{
	private unowned TextView d_view;
	private unowned TextBuffer? d_buffer;

	private TextTag? d_infoTag;
	private TextTag? d_warningTag;
	private TextTag? d_errorTag;
	private TextTag? d_locationTag;
	private TextTag? d_fixitTag;

	class DiagnosticTags
	{
		public DiagnosticTags(TextView view)
		{
			d_view = view;

			d_view.style_updated.connect(on_style_updated);
			d_view.notify["buffer"].connect(on_buffer_changed);

			d_buffer = view.buffer;

			update_tags();
		}

		~DiagnosticTags()
		{
			remove_tags();

			d_view.style_updated.disconnect(on_style_updated);
		}

		private TextTag ensure_tag(ref TextTag? tag, string name)
		{
			if (tag == null)
			{
				tag = d_buffer.create_tag(name);
			}

			return tag;
		}

		private void update_tag(ref TextTag? tag,
		                        string name,
		                        Gdk.RGBA col)
		{
			StyleContext ctx = d_view.get_style_context();

			Gdk.RGBA mixed = col;

			if (mixed.alpha < 1)
			{
				Gdk.RGBA dest;
				Gdk.RGBA source;

				source = col;

				ctx.save();
				ctx.add_class(Gtk.STYLE_CLASS_VIEW);

				ctx.get_background_color(Gtk.StateFlags.NORMAL, out dest);

				ctx.restore();

				// Alpha compositing
				mixed.alpha = source.alpha + dest.alpha * (1 - source.alpha);

				mixed.red = (source.red * source.alpha +
				             dest.red * dest.alpha * (1 - source.alpha)) / mixed.alpha;

				mixed.green = (source.green * source.alpha +
				             dest.green * dest.alpha * (1 - source.alpha)) / mixed.alpha;

				mixed.blue = (source.blue * source.alpha +
				             dest.blue * dest.alpha * (1 - source.alpha)) / mixed.alpha;
			}

			Gdk.Color bgcol = Gdk.Color() {
				red = (ushort)(mixed.red * 65535),
				green = (ushort)(mixed.green * 65535),
				blue = (ushort)(mixed.blue * 65535)
			};

			ensure_tag(ref tag, name);

			tag.background_gdk = bgcol;
			tag.background_full_height = true;
		}

		private void update_tags()
		{
			DiagnosticColors colors;

			colors = new DiagnosticColors(d_view.get_style_context());

			update_tag(ref d_infoTag,
			           "Gcp.Info",
			           colors.info_color);

			update_tag(ref d_warningTag,
			           "Gcp.Warning",
			           colors.warning_color);

			update_tag(ref d_errorTag,
			           "Gcp.Error",
			           colors.error_color);

			if (d_locationTag == null)
			{
				d_locationTag = d_buffer.create_tag("Gcp.Location",
				                                    weight: Pango.Weight.BOLD);
			}

			if (d_fixitTag == null)
			{
				d_fixitTag = d_buffer.create_tag("Gcp.Fixit",
				                                 strikethrough: true);
			}
		}

		public TextTag? error_tag
		{
			get { return d_errorTag; }
		}

		public TextTag? warning_tag
		{
			get { return d_warningTag; }
		}

		public TextTag? info_tag
		{
			get { return d_infoTag; }
		}

		public TextTag? location_tag
		{
			get { return d_locationTag; }
		}

		public TextTag? fixit_tag
		{
			get { return d_fixitTag; }
		}

		public TextTag? get(Diagnostic.Severity severity)
		{
			switch (severity)
			{
				case Diagnostic.Severity.INFO:
					return d_infoTag;
				case Diagnostic.Severity.WARNING:
					return d_warningTag;
				case Diagnostic.Severity.ERROR:
				case Diagnostic.Severity.FATAL:
					return d_errorTag;
				default:
					return null;
			}
		}

		private void remove_tag(ref TextTag? tag)
		{
			if (d_buffer != null && tag != null)
			{
				d_buffer.tag_table.remove(tag);
				tag = null;
			}
		}

		private void remove_tags()
		{
			remove_tag(ref d_errorTag);
			remove_tag(ref d_warningTag);
			remove_tag(ref d_infoTag);
			remove_tag(ref d_locationTag);
			remove_tag(ref d_fixitTag);
		}

		private void on_buffer_changed()
		{
			remove_tags();

			d_buffer = d_view.buffer;

			d_errorTag = null;
			d_warningTag = null;
			d_infoTag = null;

			update_tags();
		}

		private void on_style_updated()
		{
			update_tags();
		}
	}
}

/* vi:ex:ts=4 */