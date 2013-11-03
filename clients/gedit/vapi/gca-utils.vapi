[CCode(lower_case_cprefix = "gca_utils_c", cheader_filename = "clients/gedit/src/gca-utils-c.h")]
namespace GcaUtilsC
{
	[CCode (cname = "gca_utils_c_get_style_property_int")]
	public static int get_style_property_int(Gtk.StyleContext context,
	                                         string           name);

	[CCode (cname = "gca_utils_c_get_range_rect")]
	public static Gdk.Rectangle get_range_rect(Gtk.Range range);
}

/* vi:ex:ts=4 */
