EXTENSION = zson
MODULES = zson
DATA = zson--1.1.sql zson--1.0--1.1.sql
REGRESS = zson

PG_CPPFLAGS = -g -O2
SHLIB_LINK = # -lz -llz4

ifndef PG_CONFIG
	PG_CONFIG := pg_config
endif
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
