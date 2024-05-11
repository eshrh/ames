PREFIX?=/usr
BINDIR=${PREFIX}/bin
DOCDIR=${PREFIX}/local/man/man1
CONFIGDIR=/etc/ames

DOCFILE=ames.1
CONFIGFILE=config
SRCBIN=ames.sh
TARGETBIN=ames
NAME=ames

default: all

all:
	@echo Run \'make install\' to install ${NAME} on your device

install:
	@mkdir -p ${DESTDIR}${BINDIR}
	@cp ${SRCBIN} ${DESTDIR}${BINDIR}/${TARGETBIN}
	@chmod 755 ${DESTDIR}${BINDIR}/${TARGETBIN}
	@cp ${DOCFILE} ${DOCDIR}/${DOCFILE}
	@mkdir -p ${CONFIGDIR}
	@cp ./${CONFIGFILE} ${CONFIGDIR}
	@echo ${NAME} has been installed

uninstall:
	@rm -rf ${DESTDIR}${BINDIR}/${TARGETBIN}
	@rmdir -p --ignore-fail-on-non-empty ${DESTDIR}${BINDIR}
	@echo ${NAME} has been removed

#.PHONY: default all install uninstall 
