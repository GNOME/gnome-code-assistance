using Gtk;

namespace Gca
{

class AppActivatable : Peas.ExtensionBase, Gedit.AppActivatable
{
	public Gedit.App app { owned get; construct; }

	private CssProvider d_provider;

	public void activate()
	{
		d_provider = new CssProvider();

		File file = File.new_for_path(get_data_dir());
		File child = file.get_child("codeassistance.css");

		try
		{
			d_provider.load_from_file(child);
		}
		catch (GLib.Error error)
		{
			stderr.printf("Could not load css for gcp: %s\n", error.message);
		}

		StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),
		                                     d_provider,
		                                     600);
	}

	public void deactivate()
	{
		StyleContext.remove_provider_for_screen(Gdk.Screen.get_default(),
		                                        d_provider);
	}
}

}

/* vi:ex:ts=4 */
