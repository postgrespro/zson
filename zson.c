#include <postgres.h>
#include <utils/builtins.h>
#include <utils/jsonb.h>

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(zson_in);
PG_FUNCTION_INFO_V1(zson_out);
PG_FUNCTION_INFO_V1(z2j);
PG_FUNCTION_INFO_V1(j2z);

Datum
zson_in(PG_FUNCTION_ARGS)
{
	Jsonb	*j = DatumGetJsonb(
					DirectFunctionCall1(
						jsonb_in,
						PG_GETARG_DATUM(0)
					)
				);

	PG_RETURN_BYTEA_P(
		DatumGetByteaP(
			DirectFunctionCall1(
				j2z,
				JsonbGetDatum(j)
			)
		)
	);
}


Datum
zson_out(PG_FUNCTION_ARGS)
{
	bytea	*z = PG_GETARG_BYTEA_P(0);

	PG_RETURN_CSTRING(
		DatumGetCString(
			DirectFunctionCall1(
				jsonb_out,
				PointerGetDatum(VARDATA_ANY(z))
			)
		)
	);
}


Datum
z2j(PG_FUNCTION_ARGS)
{
	bytea	*z = PG_GETARG_BYTEA_P(0);
	Jsonb	*j;

	j = palloc(VARSIZE_ANY(z));

	memcpy(j, VARDATA_ANY(z), VARSIZE_ANY_EXHDR(z));

	PG_RETURN_JSONB(j);
}

Datum
j2z(PG_FUNCTION_ARGS)
{
	Jsonb	*j = PG_GETARG_JSONB(0);
	bytea	*z;

	z = palloc(VARSIZE_ANY(j) + VARHDRSZ);
	SET_VARSIZE(z, VARSIZE_ANY(j) + VARHDRSZ);

	memcpy(VARDATA_ANY(z), j, VARSIZE_ANY(j));

	PG_RETURN_BYTEA_P(z);
}


