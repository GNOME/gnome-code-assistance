/*
 * This file is part of gnome-code-assistance.
 *
 * Copyright (C) 2013 - Melissa Wen <melissa.srw@gmail.com>
 * Copyright (C) 2013 - Jesse van den Kieboom <jessevdk@gnome.org>
 *
 * gnome-code-assistance is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gnome-code-assistance is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gnome-code-assistance.  If not, see <http://www.gnu.org/licenses/>.
 */

using global::Vala;

namespace Gca.Backends.Vala
{

public class Service : Object
{
	public void parse(Document doc, HashTable<string, Variant> options) throws Error
	{
		CodeContext context = new CodeContext();

		var diags = new Diagnostics(doc.path);
		context.report = diags;

		CodeContext.push(context);

		string source;
		FileUtils.get_contents(doc.data_path, out source);

		var sf = new SourceFile(context, SourceFileType.SOURCE, doc.path, source, true);
		context.add_source_file(sf);

		Parser ast = new Parser();
		ast.parse(context);

		CodeContext.pop();

		doc.diagnostics = diags.diagnostics;
	}

	public new void dispose(Document document)
	{
	}
}

}

/* vi:ex:ts=4 */
