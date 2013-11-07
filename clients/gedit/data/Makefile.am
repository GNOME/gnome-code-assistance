geditcodeassistanceplugin_DATA = clients/gedit/data/codeassistance.plugin
geditcodeassistancedata_DATA = clients/gedit/data/codeassistance.css

gsettings_SCHEMAS += clients/gedit/data/org.gnome.gedit.plugins.codeassistance.gschema.xml

EXTRA_DIST += \
	clients/gedit/data/codeassistance.plugin \
	clients/gedit/data/codeassistance.css

CLEANFILES += $(geditcodeassistance_SCHEMAS)
DISTCLEANFILES += $(geditcodeassistance_SCHEMAS)

MAINTAINERCLEANFILES += $(geditcodeassistance_SCHEMAS:.xml=.valid)

GITIGNOREDEPS += clients/gedit/Makefile.am
