# gnome code assistance python backend
# Copyright (C) 2013  Jesse van den Kieboom <jessevdk@gnome.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

from lxml import etree
import os

from gnome.codeassistance import transport, types

class Service(transport.Service):
    language = 'xml'

    def get_schema(self, path, location, schema_text=None):
        schema_type = None
        schema_xml = None

        # get the schema text if needed
        if schema_text is None:
            if location.startswith('http://') or location.startswith('https://'):
                # TODO: handle location when it is a URL
                raise Exception("Schema reference must be a local file")

            # now we assume it is a local file reference
            if not os.path.isabs(location):
                location = os.path.join(os.path.dirname(path), location)

            with file(location) as f:
                schema_text = f.read()

        # parse the schema XML, exception to be caught outside this function
        schema_xml = etree.fromstring(schema_text)

        # first check the namespace
        if None in schema_xml.nsmap and schema_xml.nsmap[None] == 'http://relaxng.org/ns/structure/1.0':
            schema_type = "RelaxNG"
        elif 'xs' in schema_xml.nsmap and schema_xml.nsmap['xs'] == "http://www.w3.org/2001/XMLSchema":
            schema_type = "XSD"
        else:
            # then check the file extension
            extension = os.path.splitext(path)[1].lower()

            if extension == '.rng':
                schema_type = "RelaxNG"
            elif extension == '.xsd':
                schema_type = "XSD"

            # TODO: add .rnc support
            # http://infohost.nmt.edu/tcc/help/pubs/pylxml/web/val-mod-RelaxValidator-trang.html

        return {'type': schema_type, 'xml': schema_xml}

    def format_error(self, prefix, error, line = 1, column = 1):
        if type(error) is etree._LogEntry:
            # specially handle the case where line is 0 since docs start at line 1
            if error.line != 0:
                line = error.line
            if error.column != 0:
                column = error.column

            msg = error.message
        else:
            # it is probably a string or an Exception
            msg = str(error)

        msg = prefix + ': ' + msg
        loc = types.SourceLocation(line=line, column=column)
        severity = types.Diagnostic.Severity.ERROR

        return types.Diagnostic(severity=severity, message=msg, locations=[loc.to_range()])

    def look_for_schema(self, path, xml):
        """ This function looks through the comment tags for a schema reference
            it returns on the first reference it finds in no particular order """

        if not os.path.isabs(path):
            return (None, None, None)

        for pre in (True, False):
            for comment in xml.itersiblings(tag=etree.Comment, preceding=pre):
                ref_line = comment.text.split(':', 1)

                if ref_line[0].strip().lower() == 'schema' and len(ref_line) == 2:
                    schema_location = ref_line[1].strip()
                    schema_ref = self.get_schema(path, schema_location)

                    if schema_ref != None and schema_ref['type'] != None:
                        return (schema_ref, schema_location, comment.sourceline)

        return (None, None, None)

    def parse(self, path, cursor, unsaved, options, doc):
        filename = self.data_path(path, unsaved)
        errors = []

        doc_type = 'XML'
        etree.clear_error_log()

        with open(filename) as f:
            source = f.read()

        try:
            # parse the XML for errors
            if os.path.isabs(path):
                doc_schema = self.get_schema(path, path, source)
                xml = doc_schema['xml']

                if doc_schema['type'] != None:
                    doc_type = doc_schema['type']
            else:
                xml = etree.fromstring(source)

            # if the doc is a schema itself, parse it for schema errors
            try:
                if doc_type == "XSD":
                    etree.XMLSchema(xml)
                elif doc_type == "RelaxNG":
                    etree.RelaxNG(xml)

            except (etree.RelaxNGError, etree.XMLSchemaParseError) as e:
                for error in e.error_log:
                    errors.append(self.format_error(doc_type + " parsing error", error))

            except Exception as e:
                errors.append(self.format_error(doc_type + " parsing error", e))

            # parse XML comments in document for a reference to a schema
            try:
                (schema_ref, schema_location, comment_line) = self.look_for_schema(path, xml)
                
                if schema_ref != None:
                    try:
                        if schema_ref['type'] == "XSD":
                            schema = etree.XMLSchema(schema_ref['xml'])
                        elif schema_ref['type'] == "RelaxNG":
                            schema = etree.RelaxNG(schema_ref['xml'])

                        schema.assertValid(xml)

                    except (etree.DocumentInvalid, etree.RelaxNGValidateError, etree.XMLSchemaValidateError):
                        for error in schema.error_log:
                            errors.append(self.format_error(schema_ref['type'] + " validation error", error))

                    except (etree.RelaxNGError, etree.XMLSchemaParseError):
                        errors.append(self.format_error(schema_ref['type'] + " error", "Schema is invalid " + schema_location, comment_line))

                    except Exception as e:
                        errors.append(self.format_error(schema_ref['type'] + " error", e))

            except etree.XMLSyntaxError as e:
                errors.append(self.format_error("Schema error", "Unable to parse schema XML " + schema_location, comment_line))

            except Exception as e:
                errors.append(self.format_error("Schema error", e, comment_line))

        # handle XML parse errors
        except etree.XMLSyntaxError as e:
            for error in e.error_log:
                errors.append(self.format_error("XML parsing error", error))

        # ignore other exceptions
        except:
            pass

        if doc is None:
            doc = self.document()

        doc.errors = errors
        return doc

    def dispose(self, appid, path):
        pass

class Document(transport.Document, transport.Diagnostics):
    errors = None
    path = None

    def paths(self, ids):
        myids = {0: self.path}
        return [myids[id] for id in ids]

    def diagnostics(self):
        return self.errors

def run():
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
