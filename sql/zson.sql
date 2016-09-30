CREATE EXTENSION zson;

SELECT zson_extract_strings('true');

SELECT zson_extract_strings('"aaa"');

SELECT zson_extract_strings('["some", ["dummy", "array"], 456, false]');

SELECT zson_extract_strings('{"IP":"10.0.0.3","Roles":["master", "slave"]}');

CREATE TABLE nocompress(x jsonb);

INSERT INTO nocompress VALUES
('true'),
('123'),
('"aaa"'),
('["some", ["dummy", "array"], 456, false]'),
('
[
{"ModifyIndex":1,"IP":"10.0.0.1","Roles":["master"]},
{"ModifyIndex":2,"IP":"10.0.0.2","Roles":["slave"]},
{"ModifyIndex":3,"IP":"10.0.0.3","Roles":["master", "slave"]}
]
');

SELECT zson_learn('{{"nocompress", "x"}}');

SELECT * FROM zson_dict;

SELECT zson_learn('{{"nocompress", "x"}}', 10000, 1, 128, 1);

SELECT * FROM zson_dict;

SELECT '{"aaa": "ololo"}'::zson;

SELECT '{"aaa": "ololo"}'::zson -> 'aaa';

CREATE TABLE zson_test(x zson);

INSERT INTO zson_test VALUES('{"aaa":123}' :: jsonb);

SELECT * FROM zson_test;

SELECT x :: jsonb FROM zson_test;

DROP TABLE zson_test;

DROP TABLE nocompress;

DROP EXTENSION zson;