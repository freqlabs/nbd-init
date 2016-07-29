#	@(#)Makefile	8.1 (Berkeley) 7/19/93
# $FreeBSD$

PROG=	init
SRCS=	init.c getmntopts.c
MAN=
PRECIOUSPROG=
INSTALLFLAGS=-b -B.bak
CFLAGS+=-DDEBUGSHELL -DSECURE -DLOGIN_CAP -DCOMPAT_SYSV_INIT
LDADD=	-lutil -lcrypt -lcap_pwd

NO_SHARED?=	YES

.include <bsd.prog.mk>
