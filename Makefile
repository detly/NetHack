#!/usr/bin/make -f

# About This Makefile
#
# The original Nethack source has multiple makefiles for the various systems it
# targets. I have some extra constraints that have given rise to this makefile's
# unusual architecture:
#
#  1. I only care about GNU/Linux systems.
#  2. I want it to build via a single invocation of "make" at the top level of
#     the project (because that makes it much easier to work with most popular
#     cloud application platforms).
#  3. I would like to keep the original build information as intact as possible.
#
# This makefile is based on the 'debian/rules' file from the current Nethack
# package for Debian. The original rules file had an initial target to make the
# top-level makefile, which could then be invoked with some extra flags to build
# Nethack.
#
# To make it work as a top-level makefile itself, I changed it so that it
# creates a temporary makefile (see TEMP_MAKEFILE), and invokes that using the
# '-f' option to GNU make. This requires a hack to pass through any unknown
# targets to the temporary makefile (see the .DEFAULT target), and also requires
# the 'clean' target to depend on $(TEMP_MAKEFILE) existing.

# The name of the temporary makefile.
TEMP_MAKEFILE = temp-makefile

# The target that builds the binaries uses a stamp file (an empty file whose
# existence tells GNU make that the target has been built, and when).
REAL_BUILD_STAMP_FILE = real-build

GAME_DATA = x11tiles pet_mark.xbm rip.xpm mapbg.xpm

# These flags were originally DEB_CFLAGS, etc. and used the 'dpkg-buildflags'
# command instead of being verbatim flags.
CUSTOM_CFLAGS   := -g3 -O0 -fstack-protector --param=ssp-buffer-size=4 -Wformat \
                   -Werror=format-security -Wall
CUSTOM_CPPFLAGS := -D_FORTIFY_SOURCE=2
CUSTOM_LDFLAGS  := -Wl,-Bsymbolic-functions -Wl,-z,relro

# These are from the original Debian rules file.
CFLAGS = $(CUSTOM_CPPFLAGS) $(CUSTOM_CFLAGS) -I../include -g -Wall -DGCC_WARN
LFLAGS = $(CUSTOM_CFLAGS) $(CUSTOM_LDFLAGS)

# This target results in the "real build" of the Nethack binaries, by way of the
# temporary makefile.
$(REAL_BUILD_STAMP_FILE): $(TEMP_MAKEFILE)
	+$(call build_target,console)
	+$(call build_target,x11)
	+$(call build_target,lisp)
	+$(call build_target,gtk)
	touch src/nethack.dummy ; sleep 2
	$(MAKE) -f $(TEMP_MAKEFILE) -j1 \
	  LFLAGS='$(LFLAGS)' CFLAGS='$(CFLAGS) -DUSE_XPM' \
	  GAME=src/nethack.dummy \
	  VARDATND="$(GAME_DATA)" \
	  Guidebook data oracles options quest.dat rumors dungeon spec_levs \
	  check-dlb x11tiles pet_mark.xbm rip.xpm mapbg.xpm
	$(MAKE) -C util LFLAGS='$(LFLAGS)' CFLAGS='$(CFLAGS)' recover
	touch $@

TARGETS = console lisp x11 gtk

# The binaries are built by the makefile in the 'src' directory (note the -C
# option to the second make invocation).
define build_target
	$(MAKE) -f $(TEMP_MAKEFILE) clean
	touch include/config.h
	sleep 2
	$(MAKE) LFLAGS='$(LFLAGS)' CFLAGS='$(CFLAGS) $(EXTRACPP_$1)' \
	    WINSRC='$(SRC_$1)' WINOBJ='$(OBJ_$1)' WINLIB='$(LIB_$1)' \
	    $(EXTRA_$1) GAME='nethack.$1' \
	    -C src 'nethack.$1'
endef

# Extra make arguments for particular targets, used by 'build_target'.
SRC_console = $$(WINTTYSRC)
OBJ_console = $$(WINTTYOBJ)
LIB_console = -lncurses
EXTRACPP_console =

SRC_x11 = $$(WINTTYSRC) $$(WINX11SRC)
OBJ_x11 = $$(WINTTYOBJ) $$(WINX11OBJ)
LIB_x11 = -lncurses -lXaw -Wl,--as-needed -lXmu -lXext -Wl,--no-as-needed -lXt \
          -lXpm -lX11 -Wl,--as-needed -lm -Wl,--no-as-needed
EXTRACPP_x11 = -DX11_GRAPHICS

SRC_lisp = $$(WINLISPSRC)
OBJ_lisp = $$(WINLISPOBJ)
LIB_lisp = $$(WINLISPLIB)
EXTRACPP_lisp = -DLISP_GRAPHICS -DDEFAULT_WINDOW_SYS=\"lisp\"

SRC_gtk = $$(WINTTYSRC) $$(WINGNOMESRC)
OBJ_gtk = $$(WINTTYOBJ) $$(WINGNOMEOBJ)
LIB_gtk = -lgnomeui-2 -lgnome-2 -lart_lgpl_2 -lgtk-x11-2.0 -lgdk-x11-2.0 \
          -lgnomecanvas-2 -lgdk_pixbuf-2.0 -lgobject-2.0 -lglib-2.0 -ldl \
          -lncurses -lpopt
EXTRACPP_gtk = -I/usr/include/libgnomeui-2.0 -I/usr/include/libgnome-2.0 \
               -I/usr/include/gtk-2.0 -I/usr/include/glib-2.0 \
               -I/usr/lib/x86_64-linux-gnu/gtk-2.0/include \
               -I/usr/include/atk-1.0 -I/usr/include/cairo \
               -I/usr/include/pango-1.0 -I/usr/include/gdk-pixbuf-2.0 \
               -I/usr/include/libbonobo-2.0 -I/usr/include/libbonoboui-2.0 \
               -I/usr/include/libgnomecanvas-2.0 -I/usr/include/libart-2.0 \
               -I/usr/include/gnome-vfs-2.0 \
               -I/usr/lib/x86_64-linux-gnu/glib-2.0/include -DGNOME_GRAPHICS \
               -I../win/gnome \
               -DGTK_ENABLE_BROKEN

# Create the read-only data area (ie. HACKDIR). The original Makefiles try to do
# weird things with permissions; this assumes local usage. This also assumes the
# use of the data librarian "nhdat" file instead of the separate files.
local-data-dir: $(REAL_BUILD_STAMP_FILE)
	$(if $(strip $(LOCAL_DATADIR)), , \
		$(error LOCAL_DATADIR must be specified) \
	)

	mkdir -p $(LOCAL_DATADIR)
	cp -t $(LOCAL_DATADIR) dat/nhdat $(foreach datafile,$(GAME_DATA),dat/$(datafile))
	chmod -R a-w $(LOCAL_DATADIR)

clean-local-data-dir:
	if [ -n "$(LOCAL_DATADIR)" -a -d $(LOCAL_DATADIR) ] ; then \
	    chmod -R a+w $(LOCAL_DATADIR) ;\
	    rm -f $(LOCAL_DATADIR)/nhdat $(foreach datafile,$(GAME_DATA),$(LOCAL_DATADIR)/$(datafile)) ;\
	    rmdir $(LOCAL_DATADIR) ;\
	fi

# Create the variable data area.
local-var-dir: $(REAL_BUILD_STAMP_FILE)
	$(if $(strip $(LOCAL_VARDIR)), , \
		$(error LOCAL_VARDIR must be specified) \
	)
	mkdir -p $(LOCAL_VARDIR)
	mkdir -p $(LOCAL_VARDIR)/save
	touch $(LOCAL_VARDIR)/record
	touch $(LOCAL_VARDIR)/perm
	touch $(LOCAL_VARDIR)/logfile

clean-local-var-dir:
	if [ -n "$(LOCAL_VARDIR)" -a -d $(LOCAL_VARDIR) ] ; then \
	    rm -fr $(LOCAL_VARDIR)/save ;\
	    rm -f $(LOCAL_VARDIR)/record ;\
	    rm -f $(LOCAL_VARDIR)/perm ;\
	    rm -f $(LOCAL_VARDIR)/logfile ;\
	    rmdir $(LOCAL_VARDIR) ;\
	fi

# These are the commands that would be run by invoking 'sys/unix/setup.sh 1'
# (back before it was linuxland), except that the top level makefile is
# specifically marked as a temporary file. This assumes that symlinks are
# available.
$(TEMP_MAKEFILE):
	umask 0
	ln -s sys/linuxland/Makefile.top $@
	ln -s ../sys/linuxland/Makefile.dat dat/Makefile
	ln -s ../sys/linuxland/Makefile.doc doc/Makefile
	ln -s ../sys/linuxland/Makefile.src src/Makefile
	ln -s ../sys/linuxland/Makefile.utl util/Makefile

# It might seem strange to have the 'clean' target depend upon another target,
# but lower-level makefiles test for the existence of "Makefile" in the top
# level and call it to do cleaning tasks. In this case, that means passing
# through to $(TEMP_MAKEFILE).
clean: clean-local-var-dir clean-local-data-dir $(TEMP_MAKEFILE)
	rm -f $(REAL_BUILD_STAMP_FILE)
	rm -f nh10.pcf*
	rm -f $(patsubst %,src/nethack.%,$(TARGETS) dummy)
	if [ -f Makefile ] ; then $(MAKE) -f $(TEMP_MAKEFILE) spotless ; fi
	# The minimum depth is 2 so that this makefile isn't deleted.
	find . -mindepth 2 -name Makefile -print0 | xargs -r -0 --no-run-if-empty rm
	rm -f $(TEMP_MAKEFILE)

.PHONY: clean

# The temporary makefile tries to re-invoke itself via the shell (see the
# check-dlb target). This default target will simply pass through any unknown
# targets to the temporary makefile.
.DEFAULT:
	$(MAKE) -f $(TEMP_MAKEFILE) -j1 $@
