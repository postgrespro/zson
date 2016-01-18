CREATE EXTENSION zson;

SELECT '{"a": true}'::zson;

SELECT '{"a": true}'::zson -> 'a';
