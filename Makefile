#!/usr/bin/make -f
TEMP_MAKEFILE = temp_makefile
REAL_BUILD_LABEL = real-build

DEB_CFLAGS := $(shell dpkg-buildflags --get CFLAGS) -Wall
DEB_CPPFLAGS := $(shell dpkg-buildflags --get CPPFLAGS)
DEB_LDFLAGS := $(shell dpkg-buildflags --get LDFLAGS)

# upstream Makefile only has CFLAGS (missing CPPFLAGS)
# and does not give CFLAGS to linking calls, so add them.
# also needs some stuff so the Makefile can be overriden:
CFLAGS = $(DEB_CPPFLAGS) $(DEB_CFLAGS) -I../include -g -Wall -DGCC_WARN
LFLAGS = $(DEB_CFLAGS) $(DEB_LDFLAGS)

$(REAL_BUILD_LABEL): $(TEMP_MAKEFILE)
	+$(call build_target,console)
	+$(call build_target,x11)
	+$(call build_target,lisp)
	touch src/nethack.dummy ; sleep 2
	$(MAKE) -f $(TEMP_MAKEFILE) -j1 LFLAGS='$(LFLAGS)' CFLAGS='$(CFLAGS) -DUSE_XPM' \
	  GAME=src/nethack.dummy \
	  VARDATND="x11tiles pet_mark.xbm rip.xpm mapbg.xpm" \
	  Guidebook data oracles options quest.dat rumors dungeon spec_levs \
	  check-dlb x11tiles pet_mark.xbm rip.xpm mapbg.xpm
	$(MAKE) -C util LFLAGS='$(LFLAGS)' CFLAGS='$(CFLAGS)' recover
	touch $@

TARGETS = console lisp x11

define build_target
	$(MAKE) -f $(TEMP_MAKEFILE) clean
	touch include/config.h
	sleep 2
	$(MAKE) LFLAGS='$(LFLAGS)' CFLAGS='$(CFLAGS) $(EXTRACPP_$1)' \
	    WINSRC='$(SRC_$1)' WINOBJ='$(OBJ_$1)' WINLIB='$(LIB_$1)' \
	    $(EXTRA_$1) GAME='nethack.$1' \
	    -C src 'nethack.$1'
endef

SRC_console = $$(WINTTYSRC)
OBJ_console = $$(WINTTYOBJ)
LIB_console = -lncurses
EXTRACPP_console =
SRC_x11 = $$(WINTTYSRC) $$(WINX11SRC)
OBJ_x11 = $$(WINTTYOBJ) $$(WINX11OBJ)
LIB_x11 = -lncurses -lXaw -Wl,--as-needed -lXmu -lXext -Wl,--no-as-needed -lXt -lXpm -lX11 -Wl,--as-needed -lm -Wl,--no-as-needed
EXTRACPP_x11 = -DX11_GRAPHICS
SRC_lisp = $$(WINLISPSRC)
OBJ_lisp = $$(WINLISPOBJ)
LIB_lisp = $$(WINLISPLIB)
EXTRACPP_lisp = -DLISP_GRAPHICS -DDEFAULT_WINDOW_SYS=\"lisp\"

$(TEMP_MAKEFILE):
	# sh sys/unix/setup.sh 1
	umask 0
	ln -s sys/unix/Makefile.top $@
	ln -s ../sys/unix/Makefile.dat dat/Makefile
	ln -s ../sys/unix/Makefile.doc doc/Makefile
	ln -s ../sys/unix/Makefile.src src/Makefile
	ln -s ../sys/unix/Makefile.utl util/Makefile

clean:
	rm -f $(REAL_BUILD_LABEL)
	rm -f nh10.pcf*
	rm -f $(patsubst %,src/nethack.%,$(TARGETS) dummy)
	if [ -f Makefile ] ; then $(MAKE) -f $(TEMP_MAKEFILE) spotless ; fi
	find . -mindepth 2 -name Makefile -print0 | xargs -r -0 --no-run-if-empty rm
	rm $(TEMP_MAKEFILE)

.PHONY: clean

# The temporary makefile tries to re-invoke itself via the shell (see the
# check-dlb target). This default target will simply pass through any unknown
# targets to the temporary makefile.
.DEFAULT:
	$(MAKE) -f $(TEMP_MAKEFILE) $@
