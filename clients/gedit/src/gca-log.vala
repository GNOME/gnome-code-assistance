namespace Gca
{
	public class Log
	{
		const string Domain = "Gca";

		[Diagnostics]
		[PrintfFormat]
		public static void error(string format, ...)
		{
			var v = va_list();
	
			GLib.log(Domain,
			         GLib.LogLevelFlags.LEVEL_ERROR,
			         "%s",
			         format.vprintf(v));
		}

		[Diagnostics]
		[PrintfFormat]
		public static void warning(string format, ...)
		{
			var v = va_list();

			GLib.log (Domain,
			          GLib.LogLevelFlags.LEVEL_WARNING,
			          "%s",
			          format.vprintf(v));
		}

		[Diagnostics]
		[PrintfFormat]
		public static void message(string format, ...)
		{
			var v = va_list();

			GLib.log (Domain,
			          GLib.LogLevelFlags.LEVEL_MESSAGE,
			          "%s",
			          format.vprintf(v));
		}

		[Diagnostics]
		[PrintfFormat]
		public static void info(string format, ...)
		{
			var v = va_list();

			GLib.log (Domain,
			          GLib.LogLevelFlags.LEVEL_INFO,
			          "%s",
			          format.vprintf(v));
		}

		[Diagnostics]
		[PrintfFormat]
		public static void debug(string format, ...)
		{
			var v = va_list();

			GLib.log (Domain,
			          GLib.LogLevelFlags.LEVEL_DEBUG,
			          "%s",
			          format.vprintf(v));
		}

		[Diagnostics]
		[PrintfFormat]
		public static void critical(string format, ...)
		{
			var v = va_list();

			GLib.log (Domain,
			          GLib.LogLevelFlags.LEVEL_CRITICAL,
			          "%s",
			          format.vprintf(v));
		}
	}
}

// vi:ex:ts=4
