-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION zson" to load this file. \quit

CREATE TYPE zson;

CREATE TABLE zson_dict (
    dict_id SERIAL NOT NULL,
    word_id INTEGER NOT NULL,
    word text NOT NULL,
    PRIMARY KEY(dict_id, word_id)
);

-- Usage: select zson_learn('{{"table1", "col1"}, {"table2", "col2"}, ... }');
CREATE FUNCTION zson_learn(
    tables_and_columns text[][],
    max_examples int default 10000,
    min_length int default 2,
    max_length int default 128,
    min_count int default 2)
    RETURNS text AS $$
DECLARE
    tabname text;
    colname text;
    query text := '';
    i int;
    next_dict_id int;
BEGIN
    IF cardinality(tables_and_columns) = 0 THEN
        RAISE NOTICE 'First argument should not be an empty array!';
        RETURN '';
    END IF;

    FOR i IN    array_lower(tables_and_columns, 1) ..
                array_upper(tables_and_columns, 1)
    LOOP
        tabname := tables_and_columns[i][1];
        colname := tables_and_columns[i][2];

        IF (tabname IS NULL) OR (colname IS NULL) THEN
            RAISE NOTICE 'Invalid list of tables and columns!';
            RETURN '';
        ELSIF position('"' in tabname) <> 0 THEN
            RAISE NOTICE 'Invalid table name %', tabname;
            RETURN '';
        ELSIF position('"' in colname) <> 0 THEN
            RAISE NOTICE 'Invalid column name %', tabname;
            RETURN '';
        END IF;

        IF query <> '' THEN
            query := query || ' union all ';
        END IF;

        query := query || '( select unnest(zson_extract_strings("' ||
                    colname || '")) as t from "' || tabname || '" limit ' ||
                    max_examples || ')';
    END LOOP;

    select coalesce(max(dict_id), -1) INTO next_dict_id from zson_dict;
    next_dict_id := next_dict_id + 1;

    query := 'select t from (select t, count(*) as sum from ( ' ||
        query || ' ) as tt group by t) as s where length(t) >= ' ||
        min_length || ' and length(t) <= ' || max_length ||
        ' and sum >= ' || min_count || ' order by sum desc limit 65534';

    query := 'insert into zson_dict select ' || next_dict_id ||
        ' as dict_id, row_number() over () as word_id, t as word from ( ' ||
        query || ' ) as top_words';

    EXECUTE query;

    RETURN 'Done! Run " select * from zson_dict where dict_id = ' ||
        next_dict_id || '; " to see a dictionary.';
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION zson_extract_strings(x jsonb)
    RETURNS text[] AS $$
DECLARE
    jtype text;
    jitem jsonb;
BEGIN
    jtype := jsonb_typeof(x);
    IF jtype = 'object' THEN
        RETURN array(select unnest(z) from (
                select array(select jsonb_object_keys(x)) as z
            union all (
                select zson_extract_strings(x -> k) as z from (
                    select jsonb_object_keys(x) as k
                ) as kk
            )
        ) as zz);
    ELSIF jtype = 'array' THEN
       RETURN ARRAY(select unnest(zson_extract_strings(t)) from
            (select jsonb_array_elements(x) as t) as tt);
    ELSIF jtype = 'string' THEN
        RETURN array[ x #>> array[] :: text[] ];
    ELSE -- 'number', 'boolean', 'bool'
        RETURN array[] :: text[];
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION zson_in(cstring)
    RETURNS zson
    AS 'MODULE_PATHNAME'
    LANGUAGE C STRICT IMMUTABLE;

CREATE FUNCTION zson_out(zson)
    RETURNS cstring
    AS 'MODULE_PATHNAME'
    LANGUAGE C STRICT IMMUTABLE;

CREATE TYPE zson (
    INTERNALLENGTH = -1,
    INPUT = zson_in,
    OUTPUT = zson_out,
    STORAGE = extended -- try to compress
);

CREATE FUNCTION jsonb_to_zson(jsonb)
    RETURNS zson
    AS 'MODULE_PATHNAME'
    LANGUAGE C STRICT IMMUTABLE;

CREATE FUNCTION zson_to_jsonb(zson)
    RETURNS jsonb
    AS 'MODULE_PATHNAME'
    LANGUAGE C STRICT IMMUTABLE;

CREATE CAST (jsonb AS zson) WITH FUNCTION jsonb_to_zson(jsonb) AS ASSIGNMENT;
CREATE CAST (zson AS jsonb) WITH FUNCTION zson_to_jsonb(zson) AS IMPLICIT;

CREATE FUNCTION zson_info(zson)
    RETURNS cstring
    AS 'MODULE_PATHNAME'
    LANGUAGE C STRICT IMMUTABLE;

--CREATE FUNCTION debug_dump_jsonb(jsonb)
--    RETURNS cstring
--    AS 'MODULE_PATHNAME'
--    LANGUAGE C STRICT IMMUTABLE;
