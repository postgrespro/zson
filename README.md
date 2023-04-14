# ZSON

![ZSON Logo](img/zson-logo.png)

## About

ZSON is a PostgreSQL extension for transparent JSONB compression. Compression is
based on a shared dictionary of strings most frequently used in specific JSONB
documents (not only keys, but also values, array elements, etc).

In some cases ZSON can save half of your disk space and give you about 10% more
TPS. Memory is saved as well. See [docs/benchmark.md](docs/benchmark.md).
Everything depends on your data and workload, though. Don't believe any
benchmarks, re-check everything on your data, configuration, hardware, workload
and PostgreSQL version.

ZSON was originally created in 2016 by [Postgres Professional][pgpro] team:
researched and coded by [Aleksander Alekseev][me]; ideas, code review, testing,
etc by [Alexander Korotkov][ak] and [Teodor Sigaev][ts].

[me]: https://eax.me/
[ak]: https://akorotkov.github.io/
[ts]: http://www.sigaev.ru/
[pgpro]: https://postgrespro.com/

See also discussions on [pgsql-general@][gen], [Hacker News][hn], [Reddit][rd]
and [HabraHabr][habr].

[gen]: https://www.postgresql.org/message-id/flat/20160930185801.38654a1c%40e754
[hn]: https://news.ycombinator.com/item?id=12633486
[rd]: https://www.reddit.com/r/PostgreSQL/comments/55mr4r/zson_postgresql_extension_for_transparent_jsonb/
[habr]: https://habr.com/ru/company/postgrespro/blog/312006/

## Install

Build and install ZSON:

```
cd /path/to/zson/source/code
make
sudo make install
```

Run tests:

```
make installcheck
```

Connect to PostgreSQL:

```
psql my_database
```

Enable extension:

```
create extension zson;
```

## Uninstall

Disable extension:

```
drop extension zson;
```

Uninstall ZSON:

```
cd /path/to/zson/source/code
sudo make uninstall
```

## Usage

First ZSON should be *trained* on common data using zson\_learn procedure:

```
zson_learn(
    tables_and_columns text[][],
    max_examples int default 10000,
    min_length int default 2,
    max_length int default 128,
    min_count int default 2
)
```

Example:

```
select zson_learn('{{"table1", "col1"}, {"table2", "col2"}}');
```

You can create a temporary table and write some common JSONB documents into it
manually or use the existing tables. The idea is to provide a subset of real
data.  Let's say some document *type* is twice as frequent as another document
type.  ZSON expects that there will be twice as many documents of the first type
as those of the second one in a learning set.

Resulting dictionary could be examined using this query:

```
select * from zson_dict;
```

Now ZSON type could be used as a complete and transparent replacement of JSONB
type:

```
zson_test=# create table zson_example(x zson);
CREATE TABLE

zson_test=# insert into zson_example values ('{"aaa": 123}');
INSERT 0 1

zson_test=# select x -> 'aaa' from zson_example;
-[ RECORD 1 ]-
?column? | 123
```

## Migrating to a new dictionary

When a schema of JSONB documents evolves ZSON could be *re-learned*:

```
select zson_learn('{{"table1", "col1"}, {"table2", "col2"}}');
```

This time *second* dictionary will be created. Dictionaries are cached in memory
so it will take about a minute before ZSON realizes that there is a new
dictionary. After that old documents will be decompressed using the old
dictionary and new documents will be compressed and decompressed using the new
dictionary.

To find out which dictionary is used for a given ZSON document use zson\_info
procedure:

```
zson_test=# select zson_info(x) from test_compress where id = 1;
-[ RECORD 1 ]---------------------------------------------------
zson_info | zson version = 0, dict version = 1, ...

zson_test=# select zson_info(x) from test_compress where id = 2;
-[ RECORD 1 ]---------------------------------------------------
zson_info | zson version = 0, dict version = 0, ...
```

If **all** ZSON documents are migrated to the new dictionary the old one could
be safely removed:

```
delete from zson_dict where dict_id = 0;
```

In general, it's safer to keep old dictionaries just in case. Gaining a few KB
of disk space is not worth the risk of losing data.

## When it's a time to re-learn?

Unfortunately, it's hard to recommend a general approach.

A good heuristic could be:

```
select pg_table_size('tt') / (select count(*) from tt)
```

... i.e. average document size. When it suddenly starts to grow it's time to
re-learn.

However, developers usually know when they change a schema significantly. It's
also easy to re-check whether the current schema differs a lot from the original
one using zson\_dict table.

## Open issues

- Intalling the extension in a schema other than `public` is not supported (i.e. `CREATE EXTENSION zson WITH SCHEMA ...`);

