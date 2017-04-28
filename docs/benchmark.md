# Benchmark

**Disclaimer**: Synthetic benchmarks could not be trusted. Re-check everything on specific hardware, configuration, data and workload!

We used the following server:

* 12 cores (24 with HT)
* 24 Gb of RAM
* HDD
* swap is off

To simulate scenario when database doesn't fit into memory we used `stress`:

```
sudo stress --vm-bytes 21500m --vm-keep -m 1 --vm-hang 0
```

OOM Killer configuration:

```
# allow up to (100 - 3)% of all memory to be used

echo 100 > /proc/sys/vm/overcommit_ratio
echo 2 > /proc/sys/vm/overcommit_memory # OVERCOMMIT_NEVER
```

Database configuration:

```
max_prepared_transactions = 100
shared_buffers = 1GB
wal_level = hot_standby
wal_keep_segments = 128
max_connections = 600
listen_addresses = '*'
autovacuum = off
```

Data:

```
\timing on

create extension zson;

create table jsonb_example(x jsonb);

create table test_nocompress(id SERIAL PRIMARY KEY, x jsonb);
create table test_compress(id SERIAL PRIMARY KEY, x zson);

-- "common" JSON document - example of Consul REST API response
insert into jsonb_example values ('
	{
	  "Member": {
	    "DelegateCur": 4,
	    "DelegateMax": 4,
	    "DelegateMin": 2,
	    "Name": "postgresql-master",
	    "Addr": "10.0.3.245",
	    "Port": 8301,
	    "Tags": {
	      "vsn_min": "1",
	      "vsn_max": "3",
	      "vsn": "2",
	      "role": "consul",
	      "port": "8300",
	      "expect": "3",
	      "dc": "dc1",
	      "build": "0.6.1:68969ce5"
	    },
	    "Status": 1,
	    "ProtocolMin": 1,
	    "ProtocolMax": 3,
	    "ProtocolCur": 2
	  },
	  "Coord": {
	    "Height": 1.1121755379893715e-05,
	    "Adjustment": -2.023610556800026e-05,
	    "Error": 0.19443548095527025,
	    "Vec": [
	      -0.004713143383327869,
	      -0.0032494905923075553,
	      0.0007104109540813835,
	      0.00472788328972092,
	      -0.0015931587524407006,
	      0.0014436856764788407,
	      0.005688487740053884,
	      -0.0039037697928507834
	    ]
	  },
	  "Config": {
	    "Reap": null,
	    "SessionTTLMinRaw": "",
	    "SessionTTLMin": 0,
	    "UnixSockets": {
	      "Perms": "",
	      "Grp": "",
	      "Usr": ""
	    },
	    "VersionPrerelease": "",
	    "Version": "0.6.1",
	    "Revision": "68969ce5f4499cbe3a4f946917be2e580f1b1936+CHANGES",
	    "CAFile": "",
	    "VerifyServerHostname": false,
	    "VerifyOutgoing": false,
	    "VerifyIncoming": false,
	    "EnableDebug": false,
	    "Protocol": 2,
	    "DogStatsdTags": null,
	    "DogStatsdAddr": "",
	    "StatsdAddr": "",
	    "StatsitePrefix": "consul",
	    "StatsiteAddr": "",
	    "SkipLeaveOnInt": false,
	    "LeaveOnTerm": false,
	    "Addresses": {
	      "RPC": "",
	      "HTTPS": "",
	      "HTTP": "",
	      "DNS": ""
	    },
	    "Ports": {
	      "Server": 8300,
	      "SerfWan": 8302,
	      "SerfLan": 8301,
	      "RPC": 8400,
	      "HTTPS": -1,
	      "HTTP": 8500,
	      "DNS": 8600
	    },
	    "AdvertiseAddrWan": "10.0.3.245",
	    "DNSRecursors": [],
	    "DNSRecursor": "",
	    "DataDir": "/var/lib/consul",
	    "Datacenter": "dc1",
	    "Server": true,
	    "BootstrapExpect": 3,
	    "Bootstrap": false,
	    "DevMode": false,
	    "DNSConfig": {
	      "OnlyPassing": false,
	      "MaxStale": 5e+09,
	      "EnableTruncate": false,
	      "AllowStale": false,
	      "ServiceTTL": null,
	      "NodeTTL": 0
	    },
	    "Domain": "consul.",
	    "LogLevel": "INFO",
	    "NodeName": "postgresql-master",
	    "ClientAddr": "0.0.0.0",
	    "BindAddr": "10.0.3.245",
	    "AdvertiseAddr": "10.0.3.245",
	    "AdvertiseAddrs": {
	      "RPCRaw": "",
	      "RPC": null,
	      "SerfWanRaw": "",
	      "SerfWan": null,
	      "SerfLanRaw": "",
	      "SerfLan": null
	    },
	    "CertFile": "",
	    "KeyFile": "",
	    "ServerName": "",
	    "StartJoin": [],
	    "StartJoinWan": [],
	    "RetryJoin": [],
	    "RetryMaxAttempts": 0,
	    "RetryIntervalRaw": "",
	    "RetryJoinWan": [],
	    "RetryMaxAttemptsWan": 0,
	    "RetryIntervalWanRaw": "",
	    "EnableUi": false,
	    "UiDir": "/usr/share/consul/web-ui",
	    "PidFile": "",
	    "EnableSyslog": false,
	    "SyslogFacility": "LOCAL0",
	    "RejoinAfterLeave": false,
	    "CheckUpdateInterval": 3e+11,
	    "ACLDatacenter": "",
	    "ACLTTL": 3e+10,
	    "ACLTTLRaw": "",
	    "ACLDefaultPolicy": "allow",
	    "ACLDownPolicy": "extend-cache",
	    "Watches": null,
	    "DisableRemoteExec": false,
	    "DisableUpdateCheck": false,
	    "DisableAnonymousSignature": false,
	    "HTTPAPIResponseHeaders": null,
	    "AtlasInfrastructure": "",
	    "AtlasJoin": false,
	    "AtlasEndpoint": "",
	    "DisableCoordinates": false
	  }
	}
	');

-- step 1

insert into test_nocompress select * from generate_series(1, 10000),
	jsonb_example;

select zson_learn('{{"test_nocompress", "x"}}');

insert into test_compress select * from generate_series(1, 10000),
	jsonb_example;


select before, after, after :: float / before as ratio
	from (select pg_table_size('test_nocompress') as before,
	pg_table_size('test_compress') as after) as temp;

-- step 2

insert into test_nocompress
	select * from generate_series(10001, 1000000), jsonb_example;

insert into test_compress
	select * from generate_series(10001, 1000000), jsonb_example;

select before, after, after :: float / before as ratio
	from (select pg_table_size('test_nocompress') as before,
	pg_table_size('test_compress') as after) as temp;

-- step 3

insert into test_nocompress
	select * from generate_series(1000001, 3000000), jsonb_example;

insert into test_compress
	select * from generate_series(1000001, 3000000), jsonb_example;

select before, after, after :: float / before as ratio
	from (select pg_table_size('test_nocompress') as before,
	pg_table_size('test_compress') as after) as temp;

-- VACUUM prevents PostgreSQL from *writing* data to disk during benchmark
-- when only SELECT queries are executed
-- For more details see https://wiki.postgresql.org/wiki/Hint_Bits

vacuum full verbose;

select before, after, after :: float / before as ratio
	from (select pg_table_size('test_nocompress') as before,
	pg_table_size('test_compress') as after) as temp;

```

File nocompress.pgbench:

```
\set maxid 3000000
\setrandom from_id 1 :maxid
select x -> 'time' from test_nocompress where id=:from_id;
```

File compress.pgbench:

```
\set maxid 3000000
\setrandom from_id 1 :maxid
select x -> 'time' from test_compress where id=:from_id;
```

On PostgreSQL server:

```
# restart is required to clean shared buffers

sudo service postgresql restart
```

On second server (same hardware, same rack):

```
pgbench -h 10.110.0.10 -f nocompress.pgbench -T 600 -P 1 -c 40 -j 12 zson_test
```

On PostgreSQL server:

```
sudo service postgresql restart
```

On second server:

```
pgbench -h 10.110.0.10 -f compress.pgbench -T 600 -P 1 -c 40 -j 12 zson_test
```

Benchmark results:

```
transaction type: nocompress.pgbench
scaling factor: 1
query mode: simple
number of clients: 40
number of threads: 12
duration: 600 s
number of transactions actually processed: 583183
latency average = 41.153 ms
latency stddev = 75.002 ms
tps = 971.802963 (including connections establishing)
tps = 971.810536 (excluding connections establishing)


transaction type: compress.pgbench
scaling factor: 1
query mode: simple
number of clients: 40
number of threads: 12
duration: 600 s
number of transactions actually processed: 651910
latency average = 36.814 ms
latency stddev = 52.750 ms
tps = 1086.386943 (including connections establishing)
tps = 1086.396431 (excluding connections establishing)
```

In this case ZSON gives about 11.8% more TPS.

We can modify compress.pgbench and nocompress.pgbench so only the documents with id between 1 and 3000 will be requested. It will simulate a case when all data *does* fit into memory. In this case we see 141K TPS (JSONB) vs 134K TPS (ZSON) which is 5% slower.

The compression ratio could be different depending on the documents, the database schema, the number of rows, etc. But in general ZSON compression is much better than build-in PostgreSQL compression (PGLZ):

```
   before   |   after    |      ratio       
------------+------------+------------------
 3961880576 | 1638834176 | 0.41365057440843
(1 row)

   before   |   after    |       ratio       
------------+------------+-------------------
 8058904576 | 4916436992 | 0.610062688500061
(1 row)

   before    |   after    |       ratio       
-------------+------------+-------------------
 14204420096 | 9832841216 | 0.692238130775149
```

Not only disk space is saved. Data loaded to shared buffers is not decompressed. It means that memory is also saved and more data could be accessed without loading it from the disk.
