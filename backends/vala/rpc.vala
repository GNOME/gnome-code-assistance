namespace Rpc
{
	public struct Parse
	{
		public string[] args;
		public OpenDocument[] documents;
	}

	public struct Document
	{
		public string path;
		public Diagnostic[] diagnostics;
	}

	public struct Reply
	{
		public Document[] documents;
	}
}

/* vi:ex:ts=4 */
