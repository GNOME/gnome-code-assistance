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

public abstract class BackendImplementation : Object, Backend
{
	private ArrayList<Document> d_documents;

	public int size
	{
		get { return d_documents.size; }
	}

	public new Document get(int idx)
	{
		return d_documents[idx];
	}

	construct
	{
		d_documents = new ArrayList<Document>();
	}

	public abstract Document create_document(Gedit.Document document);

	public Document ?register_document(Gedit.Document ?document)
	{
		if (document == null)
		{
			return null;
		}

		Document ret = create_document(document);
		d_documents.add(ret);

		ret.changed.connect(on_document_changed);

		return ret;
	}

	public void unregister_document(Document ?document)
	{
		if (document == null)
		{
			return;
		}

		destroy_document(document);
		d_documents.remove(document);
	}

	protected virtual void destroy_document(Document document)
	{
		document.changed.disconnect(on_document_changed);
	}

	protected virtual void on_document_changed(Document doc)
	{
		SymbolBrowserSupport? s = doc as SymbolBrowserSupport;

		if (s != null)
		{
			s.symbol_browser.tainted = true;
		}
	}
}

}

/* vi:ex:ts=4 */
