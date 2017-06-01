EXTENSION = zson
MODULES = zson
DATA = zson--1.1.sql zson--1.0--1.1.sql
OBJS = zson.o
REGRESS = zson

MODULE_big = zson
PG_CPPFLAGS = -g -O2
SHLIB_LINK = # -lz -llz4

PGXS := $(shell pg_config --pgxs)
include $(PGXS)
