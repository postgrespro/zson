EXTENSION = zson
MODULES = zson
DATA = zson--1.0.sql
OBJS = zson.o
REGRESS = zson

ifdef USE_PGXS
PGXS := $(shell pg_config --pgxs)
include $(PGXS)
else
subdir = contrib/zson
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif


