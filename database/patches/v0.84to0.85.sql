--
-- Copyright (c) 2019 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

/*
Invoked:

	--suffix=v86
	--postschema
	jazzhands_legacy
	--post
	post
	--scan
	mlag_peering
	logical_port
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
--
-- BEGIN: process_ancillary_schema(schema_support)
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table_other_indexes');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table_other_indexes ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_other_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r	RECORD;
	sch	TEXT;
BEGIN
	-- one day, I will want to construct the list of columns by hand rather
	-- than use pg_get_constraintdef.  watch me...

	sch := quote_ident( aud_schema );
	FOR _r IN
		SELECT c2.relname, pg_get_indexdef(i.indexrelid) as def, con.contype
	FROM pg_catalog.pg_class c
	    INNER JOIN pg_namespace n
		ON relnamespace = n.oid
	    INNER JOIN pg_catalog.pg_index i
		ON c.oid = i.indrelid
	    INNER JOIN pg_catalog.pg_class c2
		ON i.indexrelid = c2.oid
	   LEFT JOIN pg_catalog.pg_constraint con ON
		(con.conrelid = i.indrelid
		AND con.conindid = i.indexrelid )
	WHERE c.relname =  table_name
	AND      n.nspname = tbl_schema
	AND	con.contype IS NULL

	LOOP
		_r.def := regexp_replace(_r.def, ' ON ', ' ON ' || sch || '.');
		EXECUTE _r.def;
	END LOOP;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_columns ( _schema text, _table text );
CREATE OR REPLACE FUNCTION schema_support.get_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			record;
BEGIN
	FOR _r IN SELECT  a.attname as colname,
	    pg_catalog.format_type(a.atttypid, a.atttypmod) as coltype,
	    a.attnotnull, a.attnum
	FROM    pg_catalog.pg_attribute a
				INNER JOIN pg_class c on a.attrelid = c.oid
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
	WHERE   c.relname = _table
		  AND	n.nspname = _schema
	  AND   a.attnum > 0
	  AND   NOT a.attisdropped
		  AND	lower(a.attname) not like 'data_%'
	ORDER BY a.attnum
	LOOP
		SELECT array_append(cols, _r.colname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols	text[];
BEGIN
    _q := 'WITH cols AS (
	SELECT  n.nspname as schema, c.relname as relation, a.attname as colname, t.typoutput as type,
		a.attnum
	    FROM    pg_catalog.pg_attribute a
		INNER JOIN pg_catalog.pg_class c
		    ON a.attrelid = c.oid
		INNER JOIN pg_catalog.pg_namespace n
		    ON c.relnamespace = n.oid
				INNER JOIN pg_catalog.pg_type t
					ON  t.oid = a.atttypid
	    WHERE   a.attnum > 0
	    AND   NOT a.attisdropped
	    ORDER BY a.attnum
       ) SELECT array_agg(colname ORDER BY attnum) as cols
	FROM ( SELECT CASE WHEN ( o.type::text ~ ''enum'' OR n.type::text ~ ''enum'')  AND o.type != n.type THEN concat(quote_ident(n.colname), ''::text'')
					ELSE quote_ident(n.colname)
					END  AS colname,
				o.attnum
			FROM cols  o
	    INNER JOIN cols n USING (schema, colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.relation = $3
		) as prett
	';
	EXECUTE _q INTO cols USING _schema, _table1, _table2;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_pk_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_pk_columns ( _schema text, _table text );
CREATE OR REPLACE FUNCTION schema_support.get_pk_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			RECORD;
BEGIN
	for _r IN SELECT a.attname
			FROM pg_class c
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
				INNER JOIN pg_index i ON i.indrelid = c.oid
				INNER JOIN pg_attribute  a ON   a.attrelid = c.oid AND
								a.attnum = any(i.indkey)
			WHERE	c.relname = _table
			AND		n.nspname = _schema
			AND		indisprimary
	LOOP
		SELECT array_append(cols, _r.attname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_t1		integer;
	_t2		integer;
	_cnt	integer;
	_cols	TEXT[];
	_pkcol	TEXT[];
	_q		TEXT;
	_f		TEXT;
	_c		RECORD;
	_w		TEXT[];
	_ctl		TEXT[];
	_rv	boolean;
	_oj		jsonb;
	_nj		jsonb;
BEGIN
	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(schema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(schema, old_rel, new_rel);

	_ctl := NULL;
	FOREACH _f IN ARRAY prikeys
	LOOP
		SELECT array_append(_ctl, quote_ident(_f) ) INTO _ctl;
	END LOOP;
	_pkcol := _ctl;

	--
	-- Number of rows mismatch.  Show the missing rows based on the
	-- primary key.
	--
	IF _t1 != _t2 THEN
		RAISE NOTICE 'table % has % rows; table % has % rows (%)', old_rel, _t1, new_rel, _t2, _t1 - _t2;
		_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel)  ||
			' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' EXCEPT ( '
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' )) ';

		_cnt := 0;
		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE 'InOld/%: %', _cnt, _r;
			_cnt := _cnt + 1;
		END LOOP;

		_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel)  ||
			' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' EXCEPT ( '
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' )) ';

		_cnt := 0;
		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE 'InNew/%: %', _cnt, _r;
			_cnt := _cnt + 1;
		END LOOP;

		_rv := false;
	END IF;

	IF NOT _rv THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Relations do not match';
		END IF;
		RETURN false;
	END IF;

	-- At this point, the same number of rows appear in both, so need to
	-- figure out rows that are different between them.


	-- SELECT row_to_json(o) as old, row_to_json(n) as new
	-- FROM ( SELECT cols FROM old WHERE prikeys in Vv ) old,
	-- JOIN ( SELECT cols FROM new WHERE prikeys in Vv ) new
	-- USING (prikeys);
	-- WHERE (prikeys) IN
	-- ( SELECT  prikeys FROM (
	--		( SELECT cols FROM old EXCEPT ( SELECT cols FROM new ) )
	-- ))

	_q := ' SELECT row_to_json(old) as old, row_to_json(new) as new FROM ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel) || ' )) ' ||
		' ) subq) ORDER BY ' || array_to_string(_pkcol,',')
	;

	_t1 := 0;
	FOR _r IN EXECUTE _q
	LOOP
		_t1 := _t1 + 1;
		FOR _f IN SELECT json_object_keys(_r.new)
		LOOP
			IF _f = ANY ( prikeys ) OR _r.old->>_f IS DISTINCT FROM _r.new->>_f
			THEN
				IF _oj IS NULL THEN
					_oj := jsonb_build_object(_f, _r.old->>_f);
					_nj := jsonb_build_object(_f, _r.new->>_f);
				ELSE
					_oj := _oj || jsonb_build_object(_f, _r.old->>_f);
					_nj := _nj || jsonb_build_object(_f, _r.new->>_f);
				END IF;
			END IF;
		END LOOP;
		RAISE NOTICE 'mismatched row:';
		RAISE NOTICE 'OLD: %', _oj;
		RAISE NOTICE 'NEW: %', _nj;
		_rv := false;
	END LOOP;

	IF NOT _rv AND raise_exception THEN
		RAISE EXCEPTION 'Relations do not match (% rows)', _t1;
	ELSE
		RAISE NOTICE '% rows mismatch', _t1;
	END IF;
	return _rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	audsch	text;
	rk	char;
	rv	timestamp;
	ts	timestamp;
	obj	text;
	objaud text;
	objkind text;
	objschema text;
BEGIN
	SELECT	audit_schema
	INTO	audsch
	FROM	schema_support.schema_audit_map m
	WHERE	m.schema = relation_last_changed.schema;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Schema % not configured for this', schema;
	END IF;

	SELECT	relkind
	INTO	rk
	FROM	pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE	n.nspname = relation_last_changed.schema
	AND	c.relname = relation_last_changed.relation;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'No such object %.%', schema, relation;
	END IF;

	IF rk = 'r' THEN
		EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
			FROM '||quote_ident(audsch)||'.'|| quote_ident(relation)
		INTO rv;
		IF rv IS NULL THEN
			EXECUTE '
				SELECT	max("aud#timestamp")
				FROM	'||quote_ident(audsch)||'.'||quote_ident(relation)
			INTO rv;
		END IF;

		IF rv IS NULL THEN
			RETURN '-infinity'::timestamp;
		ELSE
			RETURN rv;
		END IF;
	END IF;

	IF rk = 'v' OR rk = 'm' THEN
		FOR obj,objaud,objkind, objschema IN WITH RECURSIVE recur AS (
		SELECT distinct rewrite.ev_class as root_oid, d.refobjid as oid
		FROM pg_depend d
		    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
		    JOIN pg_class c on rewrite.ev_class = c.oid
		    JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE c.relname = relation
		AND n.nspname = relation_last_changed.schema
		AND d.refobjsubid > 0
	    UNION ALL
		SELECT recur.root_oid, d.refobjid as oid
		FROM pg_depend d
		    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
		    JOIN pg_class c on rewrite.ev_class = c.oid
		JOIN recur ON recur.oid = rewrite.ev_class
		AND d.refobjsubid > 0
		AND c.relkind != 'm'
	    ), list AS ( select distinct m.audit_schema, c.relname, c.relkind, n.nspname as relschema, recur.*
		FROM pg_class c
		    JOIN recur on recur.oid = c.oid
		    JOIN pg_namespace n on c.relnamespace = n.oid
		    JOIN schema_support.schema_audit_map m
			ON m.schema = n.nspname
		WHERE relkind IN ('r', 'm')
		) SELECT relname, audit_schema, relkind, relschema from list
		LOOP
			-- if there is no audit table, assume its kept current.  This is
			-- likely some sort of cache table.  XXX - should probably be
			-- updated to use the materialized view update bits
			BEGIN
				IF objkind = 'r' THEN
					EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
						FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) ||'
						WHERE "aud#timestamp" > (
								SELECT max("aud#timestamp")
								FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) || '
							) - ''10 day''::interval'
						INTO ts;
					IF ts IS NULL THEN
						EXECUTE 'SELECT max("aud#timestamp")
							FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
							INTO ts;
					END IF;
				ELSIF objkind = 'm' THEN
					SELECT refresh INTO ts FROM schema_support.mv_refresh m WHERE m.schema = objschema
						AND m.view = obj;
				ELSE
					RAISE NOTICE 'Unknown object kind % for %.%', objkind, objaud, obj;
				END IF;
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): %.% -> %', objaud, obj, ts;
				END IF;
				IF rv IS NULL OR ts > rv THEN
					rv := ts;
				END IF;
			EXCEPTION WHEN undefined_table THEN
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): skipping %.%', schema, obj;
				END IF;
			END;
		END LOOP;
		RETURN rv;
	END IF;

	RAISE EXCEPTION 'Unable to process relkind %', rk;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'reset_table_sequence');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.reset_table_sequence ( schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence(schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r	RECORD;
	m	BIGINT;
BEGIN
	FOR _r IN
		WITH s AS (
			SELECT	pg_get_serial_sequence(schema||'.'||table_name,
				a.attname) as seq, a.attname as column
			FROM	pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE	c.relname = table_name
			AND	n.nspname = schema
				AND	a.attnum > 0
				AND	NOT a.attisdropped
		) SELECT s.*, nextval(s.seq) as nv FROM s WHERE seq IS NOT NULL
	LOOP
		EXECUTE 'SELECT max('||quote_ident(_r.column)||')+1 FROM  '
			|| quote_ident(schema)||'.'||quote_ident(table_name)
			INTO m;
		IF m IS NOT NULL THEN
			IF _r.nv > m THEN
				m := _r.nv;
			END IF;
			EXECUTE 'ALTER SEQUENCE ' || _r.seq || ' RESTART WITH '
				|| m;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_constraint_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in	SELECT n.nspname, c.relname, con.conname,
				pg_get_constraintdef(con.oid, true) as def
		FROM pg_constraint con
			INNER JOIN pg_class c on (c.relnamespace, c.oid) =
				(con.connamespace, con.conrelid)
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE con.confrelid in (
			select c.oid
			from pg_class c
				inner join pg_namespace n on n.oid = c.relnamespace
			WHERE c.relname = object
			AND n.nspname = schema
		) AND n.nspname != schema
	LOOP
		_ddl := 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
			' ADD CONSTRAINT ' || _r.conname || ' ' || _r.def;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define constraint for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'constraint', _ddl
			);
		IF dropit  THEN
			_cmd = 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
				' DROP CONSTRAINT ' || _r.conname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	-- process stored procedures
	FOR _r in SELECT  distinct np.nspname::text, dependent.proname::text
		FROM   pg_depend dep
			INNER join pg_type dependee on dependee.oid = dep.refobjid
			INNER join pg_namespace n on n.oid = dependee.typnamespace
			INNER join pg_proc dependent on dependent.oid = dep.objid
			INNER join pg_namespace np on np.oid = dependent.pronamespace
			WHERE   dependee.typname = object
			  AND	  n.nspname = schema
	LOOP
		-- RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.proname;
		PERFORM schema_support.save_constraint_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit);
	END LOOP;

	-- save any triggers on the view
	FOR _r in SELECT distinct n.nspname::text, dependee.relname::text, dependee.relkind
		FROM pg_depend
		JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
		JOIN pg_class as dependee ON pg_rewrite.ev_class = dependee.oid
		JOIN pg_class as dependent ON pg_depend.refobjid = dependent.oid
		JOIN pg_namespace n on n.oid = dependee.relnamespace
		JOIN pg_namespace sn on sn.oid = dependent.relnamespace
		JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
			AND pg_depend.refobjsubid = pg_attribute.attnum
		WHERE dependent.relname = object
		AND sn.nspname = schema
	LOOP
		IF _r.relkind = 'v' OR _r.relkind = 'm' THEN
			-- RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
		PERFORM schema_support.save_constraint_for_replay('jazzhands', 'table');
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_relations');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_relations ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object	varchar;
	_tabs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_fullgrant		varchar;
	_role		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();

	-- Handle table wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			c.relacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

	-- Handle column specific wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			a.attname as col,
			a.attacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
		ON a.attrelid = c.oid
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND a.attacl IS NOT NULL
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || '(' || _tabs.col || ')'
				' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.migrate_grants(username text, direction text, old_schema text DEFAULT 'jazzhands'::text, new_schema text DEFAULT 'jazzhands_legacy'::text)
 RETURNS text[]
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_rv	TEXT[];
	_r	RECORD;
	_q	TEXT;
BEGIN
	IF lower(direction) NOT IN ('grant','revoke') THEN
		RAISE EXCEPTION 'direction must be grant or revoke';
	END IF;

	FOR _r IN
		WITH x AS (
		SELECT *
			FROM (
		SELECT oid, schema, name,  typ,
			p->>'privilege_type' as privilege_type,
			col,
			r.usename as grantor, e.usename as grantee,
			r.usesysid as rid,  e.usesysid as eid,
			e.useconfig
		FROM (
			SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
				NULL::text as col,
			to_jsonb(pg_catalog.aclexplode(acl := c.relacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
		UNION ALL
		SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
			a.attname as col,
			to_jsonb(pg_catalog.aclexplode(a.attacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
				ON a.attrelid = c.oid
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
			AND a.attacl IS NOT NULL
		) x
		LEFT JOIN pg_user r ON r.usesysid = (p->>'grantor')::oid
		LEFT JOIN pg_user e ON e.usesysid = (p->>'grantee')::oid
		) i
		) select *
		FROM x
		WHERE ( schema = old_schema )
		AND grantee = username
		AND typ IN ('table', 'view', 'mview', 'foreign table')
		order by name, col
	LOOP
		IF _r.col IS NOT NULL THEN
			_q = concat(' (', _r.col, ') ');
		ELSE
			_q := NULL;
		END IF;
		IF lower(direction) = 'grant' THEN
			_q := concat('GRANT ', _r.privilege_type, _q, ' ON ', new_schema, '.', _r.name, ' TO ', _r.grantee);
		ELSIF lower(direction) = 'revoke' THEN
			_q := concat('REVOKE ', _r.privilege_type, _q, ' ON ', old_schema, '.', _r.name, ' FROM ', _r.grantee);
		END IF;


		_rv := array_append(_rv, _q);
		EXECUTE _q;
	END LOOP;
	RETURN _rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table_other_indexes');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table_other_indexes ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_other_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r	RECORD;
	sch	TEXT;
BEGIN
	-- one day, I will want to construct the list of columns by hand rather
	-- than use pg_get_constraintdef.  watch me...

	sch := quote_ident( aud_schema );
	FOR _r IN
		SELECT c2.relname, pg_get_indexdef(i.indexrelid) as def, con.contype
	FROM pg_catalog.pg_class c
	    INNER JOIN pg_namespace n
		ON relnamespace = n.oid
	    INNER JOIN pg_catalog.pg_index i
		ON c.oid = i.indrelid
	    INNER JOIN pg_catalog.pg_class c2
		ON i.indexrelid = c2.oid
	   LEFT JOIN pg_catalog.pg_constraint con ON
		(con.conrelid = i.indrelid
		AND con.conindid = i.indexrelid )
	WHERE c.relname =  table_name
	AND      n.nspname = tbl_schema
	AND	con.contype IS NULL

	LOOP
		_r.def := regexp_replace(_r.def, ' ON ', ' ON ' || sch || '.');
		EXECUTE _r.def;
	END LOOP;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_columns ( _schema text, _table text );
CREATE OR REPLACE FUNCTION schema_support.get_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			record;
BEGIN
	FOR _r IN SELECT  a.attname as colname,
	    pg_catalog.format_type(a.atttypid, a.atttypmod) as coltype,
	    a.attnotnull, a.attnum
	FROM    pg_catalog.pg_attribute a
				INNER JOIN pg_class c on a.attrelid = c.oid
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
	WHERE   c.relname = _table
		  AND	n.nspname = _schema
	  AND   a.attnum > 0
	  AND   NOT a.attisdropped
		  AND	lower(a.attname) not like 'data_%'
	ORDER BY a.attnum
	LOOP
		SELECT array_append(cols, _r.colname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols	text[];
BEGIN
    _q := 'WITH cols AS (
	SELECT  n.nspname as schema, c.relname as relation, a.attname as colname, t.typoutput as type,
		a.attnum
	    FROM    pg_catalog.pg_attribute a
		INNER JOIN pg_catalog.pg_class c
		    ON a.attrelid = c.oid
		INNER JOIN pg_catalog.pg_namespace n
		    ON c.relnamespace = n.oid
				INNER JOIN pg_catalog.pg_type t
					ON  t.oid = a.atttypid
	    WHERE   a.attnum > 0
	    AND   NOT a.attisdropped
	    ORDER BY a.attnum
       ) SELECT array_agg(colname ORDER BY attnum) as cols
	FROM ( SELECT CASE WHEN ( o.type::text ~ ''enum'' OR n.type::text ~ ''enum'')  AND o.type != n.type THEN concat(quote_ident(n.colname), ''::text'')
					ELSE quote_ident(n.colname)
					END  AS colname,
				o.attnum
			FROM cols  o
	    INNER JOIN cols n USING (schema, colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.relation = $3
		) as prett
	';
	EXECUTE _q INTO cols USING _schema, _table1, _table2;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_pk_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_pk_columns ( _schema text, _table text );
CREATE OR REPLACE FUNCTION schema_support.get_pk_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			RECORD;
BEGIN
	for _r IN SELECT a.attname
			FROM pg_class c
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
				INNER JOIN pg_index i ON i.indrelid = c.oid
				INNER JOIN pg_attribute  a ON   a.attrelid = c.oid AND
								a.attnum = any(i.indkey)
			WHERE	c.relname = _table
			AND		n.nspname = _schema
			AND		indisprimary
	LOOP
		SELECT array_append(cols, _r.attname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_t1		integer;
	_t2		integer;
	_cnt	integer;
	_cols	TEXT[];
	_pkcol	TEXT[];
	_q		TEXT;
	_f		TEXT;
	_c		RECORD;
	_w		TEXT[];
	_ctl		TEXT[];
	_rv	boolean;
	_oj		jsonb;
	_nj		jsonb;
BEGIN
	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(schema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(schema, old_rel, new_rel);

	_ctl := NULL;
	FOREACH _f IN ARRAY prikeys
	LOOP
		SELECT array_append(_ctl, quote_ident(_f) ) INTO _ctl;
	END LOOP;
	_pkcol := _ctl;

	--
	-- Number of rows mismatch.  Show the missing rows based on the
	-- primary key.
	--
	IF _t1 != _t2 THEN
		RAISE NOTICE 'table % has % rows; table % has % rows (%)', old_rel, _t1, new_rel, _t2, _t1 - _t2;
		_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel)  ||
			' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' EXCEPT ( '
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' )) ';

		_cnt := 0;
		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE 'InOld/%: %', _cnt, _r;
			_cnt := _cnt + 1;
		END LOOP;

		_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel)  ||
			' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' EXCEPT ( '
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' )) ';

		_cnt := 0;
		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE 'InNew/%: %', _cnt, _r;
			_cnt := _cnt + 1;
		END LOOP;

		_rv := false;
	END IF;

	IF NOT _rv THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Relations do not match';
		END IF;
		RETURN false;
	END IF;

	-- At this point, the same number of rows appear in both, so need to
	-- figure out rows that are different between them.


	-- SELECT row_to_json(o) as old, row_to_json(n) as new
	-- FROM ( SELECT cols FROM old WHERE prikeys in Vv ) old,
	-- JOIN ( SELECT cols FROM new WHERE prikeys in Vv ) new
	-- USING (prikeys);
	-- WHERE (prikeys) IN
	-- ( SELECT  prikeys FROM (
	--		( SELECT cols FROM old EXCEPT ( SELECT cols FROM new ) )
	-- ))

	_q := ' SELECT row_to_json(old) as old, row_to_json(new) as new FROM ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel) || ' )) ' ||
		' ) subq) ORDER BY ' || array_to_string(_pkcol,',')
	;

	_t1 := 0;
	FOR _r IN EXECUTE _q
	LOOP
		_t1 := _t1 + 1;
		FOR _f IN SELECT json_object_keys(_r.new)
		LOOP
			IF _f = ANY ( prikeys ) OR _r.old->>_f IS DISTINCT FROM _r.new->>_f
			THEN
				IF _oj IS NULL THEN
					_oj := jsonb_build_object(_f, _r.old->>_f);
					_nj := jsonb_build_object(_f, _r.new->>_f);
				ELSE
					_oj := _oj || jsonb_build_object(_f, _r.old->>_f);
					_nj := _nj || jsonb_build_object(_f, _r.new->>_f);
				END IF;
			END IF;
		END LOOP;
		RAISE NOTICE 'mismatched row:';
		RAISE NOTICE 'OLD: %', _oj;
		RAISE NOTICE 'NEW: %', _nj;
		_rv := false;
	END LOOP;

	IF NOT _rv AND raise_exception THEN
		RAISE EXCEPTION 'Relations do not match (% rows)', _t1;
	ELSE
		RAISE NOTICE '% rows mismatch', _t1;
	END IF;
	return _rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	audsch	text;
	rk	char;
	rv	timestamp;
	ts	timestamp;
	obj	text;
	objaud text;
	objkind text;
	objschema text;
BEGIN
	SELECT	audit_schema
	INTO	audsch
	FROM	schema_support.schema_audit_map m
	WHERE	m.schema = relation_last_changed.schema;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Schema % not configured for this', schema;
	END IF;

	SELECT	relkind
	INTO	rk
	FROM	pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE	n.nspname = relation_last_changed.schema
	AND	c.relname = relation_last_changed.relation;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'No such object %.%', schema, relation;
	END IF;

	IF rk = 'r' THEN
		EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
			FROM '||quote_ident(audsch)||'.'|| quote_ident(relation)
		INTO rv;
		IF rv IS NULL THEN
			EXECUTE '
				SELECT	max("aud#timestamp")
				FROM	'||quote_ident(audsch)||'.'||quote_ident(relation)
			INTO rv;
		END IF;

		IF rv IS NULL THEN
			RETURN '-infinity'::timestamp;
		ELSE
			RETURN rv;
		END IF;
	END IF;

	IF rk = 'v' OR rk = 'm' THEN
		FOR obj,objaud,objkind, objschema IN WITH RECURSIVE recur AS (
		SELECT distinct rewrite.ev_class as root_oid, d.refobjid as oid
		FROM pg_depend d
		    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
		    JOIN pg_class c on rewrite.ev_class = c.oid
		    JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE c.relname = relation
		AND n.nspname = relation_last_changed.schema
		AND d.refobjsubid > 0
	    UNION ALL
		SELECT recur.root_oid, d.refobjid as oid
		FROM pg_depend d
		    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
		    JOIN pg_class c on rewrite.ev_class = c.oid
		JOIN recur ON recur.oid = rewrite.ev_class
		AND d.refobjsubid > 0
		AND c.relkind != 'm'
	    ), list AS ( select distinct m.audit_schema, c.relname, c.relkind, n.nspname as relschema, recur.*
		FROM pg_class c
		    JOIN recur on recur.oid = c.oid
		    JOIN pg_namespace n on c.relnamespace = n.oid
		    JOIN schema_support.schema_audit_map m
			ON m.schema = n.nspname
		WHERE relkind IN ('r', 'm')
		) SELECT relname, audit_schema, relkind, relschema from list
		LOOP
			-- if there is no audit table, assume its kept current.  This is
			-- likely some sort of cache table.  XXX - should probably be
			-- updated to use the materialized view update bits
			BEGIN
				IF objkind = 'r' THEN
					EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
						FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) ||'
						WHERE "aud#timestamp" > (
								SELECT max("aud#timestamp")
								FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) || '
							) - ''10 day''::interval'
						INTO ts;
					IF ts IS NULL THEN
						EXECUTE 'SELECT max("aud#timestamp")
							FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
							INTO ts;
					END IF;
				ELSIF objkind = 'm' THEN
					SELECT refresh INTO ts FROM schema_support.mv_refresh m WHERE m.schema = objschema
						AND m.view = obj;
				ELSE
					RAISE NOTICE 'Unknown object kind % for %.%', objkind, objaud, obj;
				END IF;
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): %.% -> %', objaud, obj, ts;
				END IF;
				IF rv IS NULL OR ts > rv THEN
					rv := ts;
				END IF;
			EXCEPTION WHEN undefined_table THEN
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): skipping %.%', schema, obj;
				END IF;
			END;
		END LOOP;
		RETURN rv;
	END IF;

	RAISE EXCEPTION 'Unable to process relkind %', rk;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'reset_table_sequence');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.reset_table_sequence ( schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence(schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r	RECORD;
	m	BIGINT;
BEGIN
	FOR _r IN
		WITH s AS (
			SELECT	pg_get_serial_sequence(schema||'.'||table_name,
				a.attname) as seq, a.attname as column
			FROM	pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE	c.relname = table_name
			AND	n.nspname = schema
				AND	a.attnum > 0
				AND	NOT a.attisdropped
		) SELECT s.*, nextval(s.seq) as nv FROM s WHERE seq IS NOT NULL
	LOOP
		EXECUTE 'SELECT max('||quote_ident(_r.column)||')+1 FROM  '
			|| quote_ident(schema)||'.'||quote_ident(table_name)
			INTO m;
		IF m IS NOT NULL THEN
			IF _r.nv > m THEN
				m := _r.nv;
			END IF;
			EXECUTE 'ALTER SEQUENCE ' || _r.seq || ' RESTART WITH '
				|| m;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_constraint_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in	SELECT n.nspname, c.relname, con.conname,
				pg_get_constraintdef(con.oid, true) as def
		FROM pg_constraint con
			INNER JOIN pg_class c on (c.relnamespace, c.oid) =
				(con.connamespace, con.conrelid)
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE con.confrelid in (
			select c.oid
			from pg_class c
				inner join pg_namespace n on n.oid = c.relnamespace
			WHERE c.relname = object
			AND n.nspname = schema
		) AND n.nspname != schema
	LOOP
		_ddl := 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
			' ADD CONSTRAINT ' || _r.conname || ' ' || _r.def;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define constraint for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'constraint', _ddl
			);
		IF dropit  THEN
			_cmd = 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
				' DROP CONSTRAINT ' || _r.conname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	-- process stored procedures
	FOR _r in SELECT  distinct np.nspname::text, dependent.proname::text
		FROM   pg_depend dep
			INNER join pg_type dependee on dependee.oid = dep.refobjid
			INNER join pg_namespace n on n.oid = dependee.typnamespace
			INNER join pg_proc dependent on dependent.oid = dep.objid
			INNER join pg_namespace np on np.oid = dependent.pronamespace
			WHERE   dependee.typname = object
			  AND	  n.nspname = schema
	LOOP
		-- RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.proname;
		PERFORM schema_support.save_constraint_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit);
	END LOOP;

	-- save any triggers on the view
	FOR _r in SELECT distinct n.nspname::text, dependee.relname::text, dependee.relkind
		FROM pg_depend
		JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
		JOIN pg_class as dependee ON pg_rewrite.ev_class = dependee.oid
		JOIN pg_class as dependent ON pg_depend.refobjid = dependent.oid
		JOIN pg_namespace n on n.oid = dependee.relnamespace
		JOIN pg_namespace sn on sn.oid = dependent.relnamespace
		JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
			AND pg_depend.refobjsubid = pg_attribute.attnum
		WHERE dependent.relname = object
		AND sn.nspname = schema
	LOOP
		IF _r.relkind = 'v' OR _r.relkind = 'm' THEN
			-- RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
		PERFORM schema_support.save_constraint_for_replay('jazzhands', 'table');
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_relations');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_relations ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object	varchar;
	_tabs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_fullgrant		varchar;
	_role		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();

	-- Handle table wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			c.relacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

	-- Handle column specific wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			a.attname as col,
			a.attacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
		ON a.attrelid = c.oid
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND a.attacl IS NOT NULL
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || '(' || _tabs.col || ')'
				' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.migrate_grants(username text, direction text, old_schema text DEFAULT 'jazzhands'::text, new_schema text DEFAULT 'jazzhands_legacy'::text)
 RETURNS text[]
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_rv	TEXT[];
	_r	RECORD;
	_q	TEXT;
BEGIN
	IF lower(direction) NOT IN ('grant','revoke') THEN
		RAISE EXCEPTION 'direction must be grant or revoke';
	END IF;

	FOR _r IN
		WITH x AS (
		SELECT *
			FROM (
		SELECT oid, schema, name,  typ,
			p->>'privilege_type' as privilege_type,
			col,
			r.usename as grantor, e.usename as grantee,
			r.usesysid as rid,  e.usesysid as eid,
			e.useconfig
		FROM (
			SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
				NULL::text as col,
			to_jsonb(pg_catalog.aclexplode(acl := c.relacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
		UNION ALL
		SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
			a.attname as col,
			to_jsonb(pg_catalog.aclexplode(a.attacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
				ON a.attrelid = c.oid
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
			AND a.attacl IS NOT NULL
		) x
		LEFT JOIN pg_user r ON r.usesysid = (p->>'grantor')::oid
		LEFT JOIN pg_user e ON e.usesysid = (p->>'grantee')::oid
		) i
		) select *
		FROM x
		WHERE ( schema = old_schema )
		AND grantee = username
		AND typ IN ('table', 'view', 'mview', 'foreign table')
		order by name, col
	LOOP
		IF _r.col IS NOT NULL THEN
			_q = concat(' (', _r.col, ') ');
		ELSE
			_q := NULL;
		END IF;
		IF lower(direction) = 'grant' THEN
			_q := concat('GRANT ', _r.privilege_type, _q, ' ON ', new_schema, '.', _r.name, ' TO ', _r.grantee);
		ELSIF lower(direction) = 'revoke' THEN
			_q := concat('REVOKE ', _r.privilege_type, _q, ' ON ', old_schema, '.', _r.name, ' FROM ', _r.grantee);
		END IF;


		_rv := array_append(_rv, _q);
		EXECUTE _q;
	END LOOP;
	RETURN _rv;
END;
$function$
;

-- DONE: process_ancillary_schema(schema_support)
--
-- Process middle (non-trigger) schema jazzhands_cache
--
--
-- Process middle (non-trigger) schema jazzhands
--
--
-- Process middle (non-trigger) schema net_manip
--
--
-- Process middle (non-trigger) schema network_strings
--
--
-- Process middle (non-trigger) schema time_util
--
--
-- Process middle (non-trigger) schema dns_utils
--
--
-- Process middle (non-trigger) schema person_manip
--
--
-- Process middle (non-trigger) schema layerx_network_manip
--
--
-- Process middle (non-trigger) schema auto_ac_manip
--
--
-- Process middle (non-trigger) schema company_manip
--
--
-- Process middle (non-trigger) schema component_connection_utils
--
--
-- Process middle (non-trigger) schema token_utils
--
--
-- Process middle (non-trigger) schema port_support
--
--
-- Process middle (non-trigger) schema port_utils
--
--
-- Process middle (non-trigger) schema device_utils
--
--
-- Process middle (non-trigger) schema netblock_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'calculate_intermediate_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.calculate_intermediate_netblocks ( ip_block_1 inet, ip_block_2 inet, netblock_type text, ip_universe_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.calculate_intermediate_netblocks(ip_block_1 inet DEFAULT NULL::inet, ip_block_2 inet DEFAULT NULL::inet, netblock_type text DEFAULT 'default'::text, ip_universe_id integer DEFAULT 0)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	current_nb		inet;
	new_nb			inet;
	min_addr		inet;
	max_addr		inet;
	family_bits		integer;
BEGIN
	IF ip_block_1 IS NULL OR ip_block_2 IS NULL THEN
		RAISE EXCEPTION 'Must specify both ip_block_1 and ip_block_2';
	END IF;

	IF family(ip_block_1) != family(ip_block_2) THEN
		RAISE EXCEPTION 'families of ip_block_1 and ip_block_2 must match';
	END IF;

	-- Make sure these are network blocks
	ip_block_1 := network(ip_block_1);
	ip_block_2 := network(ip_block_2);

	-- If the blocks are subsets of each other, then error

	IF ip_block_1 <<= ip_block_2 AND ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks % and % intersect each other',
			ip_block_1,
			ip_block_2;
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	family_bits := CASE WHEN family(ip_block_1) = 4 THEN 32 ELSE 128 END;

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;

		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), family_bits) >
			set_masklen(max_addr, family_bits)
		THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < family_bits THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			max_addr := broadcast(new_nb);
		END IF;
		current_nb := new_nb;
	END LOOP;

	-- Now loop through there to find the unused blocks at the front

	LOOP
		IF host(current_nb) = host(ip_block_2) OR
			masklen(current_nb) >= family_bits
		THEN
			RETURN;
		END IF;

		current_nb := set_masklen(current_nb, masklen(current_nb) + 1);
		IF NOT (current_nb >>= ip_block_2) THEN
			ip_addr := current_nb;
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < family_bits THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			current_nb := broadcast(current_nb) + 1;
			CONTINUE;
		END IF;
	END LOOP;
	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'delete_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.delete_netblock ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.delete_netblock(in_netblock_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE
		netblock_id = in_netblock_id;

	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;

	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_ip_universe');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_best_ip_universe ( ip_address inet, ip_namespace character varying );
CREATE OR REPLACE FUNCTION netblock_utils.find_best_ip_universe(ip_address inet, ip_namespace character varying DEFAULT 'default'::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	u_id	ip_universe.ip_universe_id%TYPE;
	ip	inet;
	nsp	text;
BEGIN
	ip := ip_address;
	nsp := ip_namespace;

	SELECT	nb.ip_universe_id
	INTO	u_id
	FROM	netblock nb
		JOIN ip_universe u USING (ip_universe_id)
	WHERE	is_single_address = 'N'
	AND	nb.ip_address >>= ip
	AND	u.ip_namespace = 'default'
	ORDER BY masklen(nb.ip_address) desc
	LIMIT 1;

	IF u_id IS NOT NULL THEN
		RETURN u_id;
	END IF;
	RETURN 0;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_parent_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id ( in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer, in_fuzzy_can_subnet boolean, can_fix_can_subnet boolean );
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer DEFAULT NULL::integer, in_netblock_type character varying DEFAULT 'default'::character varying, in_ip_universe_id integer DEFAULT 0, in_is_single_address character DEFAULT 'N'::bpchar, in_netblock_id integer DEFAULT NULL::integer, in_fuzzy_can_subnet boolean DEFAULT false, can_fix_can_subnet boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	IF (in_netmask_bits IS NOT NULL) THEN
		in_IpAddress := set_masklen(in_IpAddress, in_Netmask_Bits);
	END IF;

	select  Netblock_Id
	  into	par_nbid
	  from  ( select Netblock_Id, Ip_Address
		    from jazzhands.netblock
		   where
		   	in_IpAddress <<= ip_address
		    and is_single_address = 'N'
			and netblock_type = in_netblock_type
			and ip_universe_id = in_ip_universe_id
		    and (
				(in_is_single_address = 'N' AND
					masklen(ip_address) < masklen(In_IpAddress))
				OR
				(in_is_single_address = 'Y' AND can_subnet = 'N' AND
					(in_Netmask_Bits IS NULL
						OR masklen(Ip_Address) = in_Netmask_Bits))
			)
			and (in_netblock_id IS NULL OR
				netblock_id != in_netblock_id)
		order by masklen(ip_address) desc
	) subq LIMIT 1;

	IF par_nbid IS NULL AND in_is_single_address = 'Y' AND in_fuzzy_can_subnet THEN
		select  Netblock_Id
		  into	par_nbid
		  from  ( select Netblock_Id, Ip_Address
			    from jazzhands.netblock
			   where
			   	in_IpAddress <<= ip_address
			    and is_single_address = 'N'
				and netblock_type = in_netblock_type
				and ip_universe_id = in_ip_universe_id
			    and
					(in_is_single_address = 'Y' AND can_subnet = 'Y' AND
						(in_Netmask_Bits IS NULL
							OR masklen(Ip_Address) = in_Netmask_Bits))
				and (in_netblock_id IS NULL OR
					netblock_id != in_netblock_id)
				and netblock_id not IN (
					select parent_netblock_id from jazzhands.netblock
						where is_single_address = 'N'
						and parent_netblock_id is not null
				)
			order by masklen(ip_address) desc
		) subq LIMIT 1;

		IF can_fix_can_subnet AND par_nbid IS NOT NULL THEN
			UPDATE netblock SET can_subnet = 'N' where netblock_id = par_nbid;
		END IF;
	END IF;


	return par_nbid;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_parent_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nbrec		RECORD;
BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE
		netblock_id = in_netblock_id;

	RETURN netblock_utils.find_best_parent_id(
		nbrec.ip_address,
		masklen(nbrec.ip_address),
		nbrec.netblock_type,
		nbrec.ip_universe_id,
		nbrec.is_single_address,
		in_netblock_id
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblock ( parent_netblock_id integer, netmask_bits integer, single_address boolean, allocation_method text, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	RETURN QUERY SELECT * FROM netblock_utils.find_free_netblocks(
			parent_netblock_id := parent_netblock_id,
			netmask_bits := netmask_bits,
			single_address := single_address,
			allocate_from_bottom := allocate_from_bottom,
			desired_ip_address := desired_ip_address,
			max_addresses := 1);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_id integer, netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	RETURN QUERY SELECT * FROM netblock_utils.find_free_netblocks(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		single_address := single_address,
		allocation_method := allocation_method,
		desired_ip_address := desired_ip_address,
		max_addresses := max_addresses);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	netrange_rec	RECORD;
	inet_list		inet[];
	current_ip		inet;
	saved_method	text;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	rnd_matches		integer;
	max_rnd_value	bigint;
	rnd_value		bigint;
	family_bits		integer;
BEGIN
	matches := 0;
	saved_method = allocation_method;

	IF allocation_method IS NOT NULL AND allocation_method
			NOT IN ('top', 'bottom', 'random', 'default') THEN
		RAISE 'address_type must be one of top, bottom, random, or default'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- Sanitize masklen input.  This is a little complicated.
	--
	-- If a single address is desired, we always use a /32 or /128
	-- in the parent loop and everything else is ignored
	--
	-- Otherwise, if netmask_bits is passed, that wins, otherwise
	-- the netmask of whatever is passed with desired_ip_address wins
	--
	-- If none of these are the case, then things are wrong and we
	-- bail
	--

	IF NOT single_address THEN
		IF desired_ip_address IS NOT NULL AND netmask_bits IS NULL THEN
			netmask_bits := masklen(desired_ip_address);
		ELSIF desired_ip_address IS NOT NULL AND
				netmask_bits IS NOT NULL THEN
			desired_ip_address := set_masklen(desired_ip_address,
				netmask_bits);
		END IF;
		IF netmask_bits IS NULL THEN
			RAISE EXCEPTION 'netmask_bits must be set'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF allocation_method = 'random' THEN
			RAISE EXCEPTION 'random netblocks may only be returned for single addresses'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		rnd_matches := 0;
		--
		-- Restore this, because we may have overrridden it for a previous
		-- block
		--
		allocation_method = saved_method;
		SELECT
			* INTO netblock_rec
		FROM
			jazzhands.netblock n
		WHERE
			n.netblock_id = parent_nbid;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Netblock % does not exist', parent_nbid;
		END IF;

		family_bits :=
			(CASE family(netblock_rec.ip_address) WHEN 4 THEN 32 ELSE 128 END);

		-- If desired_ip_address is passed, then allocation_method is
		-- irrelevant

		IF desired_ip_address IS NOT NULL THEN
			--
			-- If the IP address is not the same family as the parent block,
			-- we aren't going to find it
			--
			IF family(desired_ip_address) !=
					family(netblock_rec.ip_address) THEN
				CONTINUE;
			END IF;
			allocation_method := 'bottom';
		END IF;

		--
		-- If allocation_method is 'default' or NULL, then use 'bottom'
		-- unless it's for a single IPv6 address in a netblock larger than
		-- rnd_masklen_threshold
		--
		IF allocation_method IS NULL OR allocation_method = 'default' THEN
			allocation_method :=
				CASE WHEN
					single_address AND
					family(netblock_rec.ip_address) = 6 AND
					masklen(netblock_rec.ip_address) <= rnd_masklen_threshold
				THEN
					'random'
				ELSE
					'bottom'
				END;
		END IF;

		IF allocation_method = 'random' AND
				family_bits - masklen(netblock_rec.ip_address) < 2 THEN
			-- Random allocation doesn't work if we don't have enough
			-- bits to play with, so just do sequential.
			allocation_method := 'bottom';
		END IF;

		IF single_address THEN
			netmask_bits := family_bits;
			IF desired_ip_address IS NOT NULL THEN
				desired_ip_address := set_masklen(desired_ip_address,
					masklen(netblock_rec.ip_address));
			END IF;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			-- If the netmask is not for a smaller netblock than this parent,
			-- then bounce to the next one, because maybe it's larger
			RAISE DEBUG
				'netblock (%) is not larger than netmask_bits of % - skipping',
				masklen(netblock_rec.ip_address),
				netmask_bits;
			CONTINUE;
		END IF;

		IF netmask_bits > family_bits THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		--
		-- Short circuit the check if we're looking for a specific address
		-- and it's not in this netblock
		--

		IF desired_ip_address IS NOT NULL AND
				NOT (desired_ip_address <<= netblock_rec.ip_address) THEN
			RAISE DEBUG 'desired_ip_address % is not in netblock %',
				desired_ip_address,
				netblock_rec.ip_address;
			CONTINUE;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		RAISE DEBUG 'Searching netblock % (%) using the % allocation method',
			netblock_rec.netblock_id,
			netblock_rec.ip_address,
			allocation_method;

		IF desired_ip_address IS NOT NULL THEN
			min_ip := desired_ip_address;
			max_ip := desired_ip_address + 1;
		ELSE
			min_ip := netblock_rec.ip_address;
			max_ip := broadcast(min_ip) + 1;
		END IF;

		IF allocation_method = 'top' THEN
			current_ip := network(set_masklen(max_ip - 1, netmask_bits));
		ELSIF allocation_method = 'random' THEN
			max_rnd_value := (x'7fffffffffffffff'::bigint >> CASE
				WHEN family_bits - masklen(netblock_rec.ip_address) >= 63
				THEN 0
				ELSE 63 - (family_bits - masklen(netblock_rec.ip_address))
				END) - 2;
			-- random() appears to only do 32-bits, which is dumb
			-- I'm pretty sure that all of the casts are not required here,
			-- but better to make sure
			current_ip := min_ip +
					((((random() * x'7fffffff'::bigint)::bigint << 32) +
					(random() * x'ffffffff'::bigint)::bigint + 1)
					% max_rnd_value) + 1;
		ELSE -- it's 'bottom'
			current_ip := set_masklen(min_ip, netmask_bits);
		END IF;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses
		-- We shouldn't need to skip for IPv6 addresses, but some things
		-- apparently suck

		IF single_address THEN
			current_ip := set_masklen(current_ip,
				masklen(netblock_rec.ip_address));
			--
			-- If we're not allocating a single /31 or /32 for IPv4 or
			-- /127 or /128 for IPv6, then we want to skip the all-zeros
			-- and all-ones addresses
			--
			IF masklen(netblock_rec.ip_address) < (family_bits - 1) AND
					desired_ip_address IS NULL THEN
				current_ip := current_ip +
					CASE WHEN allocation_method = 'top' THEN -1 ELSE 1 END;
				min_ip := min_ip + 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step masklen of %',
			current_ip,
			netmask_bits;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses AND
				rnd_matches < rnd_max_count
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			IF single_address THEN
				--
				-- Check to see if netblock is in a network_range, and if it is,
				-- then set the value to the top or bottom of the range, or
				-- another random value as appropriate
				--
				SELECT
					network_range_id,
					start_nb.ip_address AS start_ip_address,
					stop_nb.ip_address AS stop_ip_address
				INTO netrange_rec
				FROM
					jazzhands.network_range nr,
					jazzhands.netblock start_nb,
					jazzhands.netblock stop_nb
				WHERE
					family(current_ip) = family(start_nb.ip_address) AND
					family(current_ip) = family(stop_nb.ip_address) AND
					(
						nr.start_netblock_id = start_nb.netblock_id AND
						nr.stop_netblock_id = stop_nb.netblock_id AND
						nr.parent_netblock_id = netblock_rec.netblock_id AND
						start_nb.ip_address <=
							set_masklen(current_ip, masklen(start_nb.ip_address))
						AND stop_nb.ip_address >=
							set_masklen(current_ip, masklen(stop_nb.ip_address))
					);

				IF FOUND THEN
					current_ip := CASE
						WHEN allocation_method = 'bottom' THEN
							netrange_rec.stop_ip_address + 1
						WHEN allocation_method = 'top' THEN
							netrange_rec.start_ip_address - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32)
							+
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1
					END;
					CONTINUE;
				END IF;
			END IF;


			PERFORM * FROM jazzhands.netblock n WHERE
				n.ip_universe_id = netblock_rec.ip_universe_id AND
				n.netblock_type = netblock_rec.netblock_type AND
				-- A block with the parent either contains or is contained
				-- by this block
				n.parent_netblock_id = netblock_rec.netblock_id AND
				CASE WHEN single_address THEN
					n.ip_address = current_ip
				ELSE
					(n.ip_address >>= current_ip OR current_ip >>= n.ip_address)
				END;
			IF NOT FOUND AND (inet_list IS NULL OR
					NOT (current_ip = ANY(inet_list))) THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				inet_list := array_append(inet_list, current_ip);
				matches := matches + 1;
				-- Reset random counter if we found something
				rnd_matches := 0;
			ELSIF allocation_method = 'random' THEN
				-- Increase random counter if we didn't find something
				rnd_matches := rnd_matches + 1;
			END IF;

			-- Select the next IP address
			current_ip :=
				CASE WHEN single_address THEN
					CASE
						WHEN allocation_method = 'bottom' THEN current_ip + 1
						WHEN allocation_method = 'top' THEN current_ip - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32)
							+
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1
					END
				ELSE
					CASE WHEN allocation_method = 'bottom' THEN
						network(broadcast(current_ip) + 1)
					ELSE
						network(current_ip - 1)
					END
				END;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_rvs_zone_from_netblock_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_rvs_zone_from_netblock_id ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_rvs_zone_from_netblock_id(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	v_rv	jazzhands.dns_domain.dns_domain_id%type;
	v_domid	jazzhands.dns_domain.dns_domain_id%type;
	v_lhsip	jazzhands.netblock.ip_address%type;
	v_rhsip	jazzhands.netblock.ip_address%type;
	nb_match CURSOR ( in_nb_id jazzhands.netblock.netblock_id%type) FOR
		select  rootd.dns_domain_id,
				 network(set_masklen(nb.ip_address, masklen(root.ip_address))),
				 network(root.ip_address)
		  from  jazzhands.netblock nb,
			jazzhands.netblock root
				inner join jazzhands.dns_record rootd
					on rootd.netblock_id = root.netblock_id
					and rootd.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		 where
		  	nb.netblock_id = in_nb_id;
BEGIN
	v_rv := NULL;
	OPEN nb_match(in_netblock_id);
	LOOP
		FETCH  nb_match INTO v_domid, v_lhsip, v_rhsip;
		if NOT FOUND THEN
			EXIT;
		END IF;

		if v_lhsip = v_rhsip THEN
			v_rv := v_domid;
			EXIT;
		END IF;
	END LOOP;
	CLOSE nb_match;
	return v_rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'list_unallocated_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.list_unallocated_netblocks ( netblock_id integer, ip_address inet, ip_universe_id integer, netblock_type text );
CREATE OR REPLACE FUNCTION netblock_utils.list_unallocated_netblocks(netblock_id integer DEFAULT NULL::integer, ip_address inet DEFAULT NULL::inet, ip_universe_id integer DEFAULT 0, netblock_type text DEFAULT 'default'::text)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ip_array		inet[];
	netblock_rec	RECORD;
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	family_bits		integer;
	idx				integer;
	subnettable		boolean;
BEGIN
	subnettable := true;
	IF netblock_id IS NOT NULL THEN
		SELECT * INTO netblock_rec FROM jazzhands.netblock n WHERE n.netblock_id =
			list_unallocated_netblocks.netblock_id;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'netblock_id % not found', netblock_id;
		END IF;
		IF netblock_rec.is_single_address = 'Y' THEN
			RETURN;
		END IF;
		ip_address := netblock_rec.ip_address;
		ip_universe_id := netblock_rec.ip_universe_id;
		netblock_type := netblock_rec.netblock_type;
		subnettable := CASE WHEN netblock_rec.can_subnet = 'N'
			THEN false ELSE true
			END;
	ELSIF ip_address IS NOT NULL THEN
		ip_universe_id := 0;
		netblock_type := 'default';
	ELSE
		RAISE EXCEPTION 'netblock_id or ip_address must be passed';
	END IF;
	IF (subnettable) THEN
		SELECT ARRAY(
			SELECT
				n.ip_address
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type AND
				is_single_address = 'N' AND
				can_subnet = 'N'
			ORDER BY
				n.ip_address
		) INTO ip_array;
	ELSE
		SELECT ARRAY(
			SELECT
				set_masklen(n.ip_address,
					CASE WHEN family(n.ip_address) = 4 THEN 32
					ELSE 128
					END)
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_address != list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type
			ORDER BY
				n.ip_address
		) INTO ip_array;
	END IF;

	IF array_length(ip_array, 1) IS NULL THEN
		ip_addr := ip_address;
		RETURN NEXT;
		RETURN;
	END IF;

	ip_array := array_prepend(
		list_unallocated_netblocks.ip_address - 1,
		array_append(
			ip_array,
			broadcast(list_unallocated_netblocks.ip_address) + 1
			));

	idx := 1;
	WHILE idx < array_length(ip_array, 1) LOOP
		RETURN QUERY SELECT cin.ip_addr FROM
			netblock_utils.calculate_intermediate_netblocks(ip_array[idx], ip_array[idx + 1]) cin;
		idx := idx + 1;
	END LOOP;

	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'recalculate_parentage');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.recalculate_parentage ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.recalculate_parentage(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		jazzhands.netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE
		netblock_id = in_netblock_id;

	nbid := netblock_utils.find_best_parent_id(in_netblock_id);

	UPDATE jazzhands.netblock SET parent_netblock_id = nbid
		WHERE netblock_id = in_netblock_id;

	FOR childrec IN SELECT * FROM jazzhands.netblock WHERE
		parent_netblock_id = nbid
		AND netblock_id != in_netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE jazzhands.netblock SET parent_netblock_id = in_netblock_id
				WHERE netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$function$
;

--
-- Process middle (non-trigger) schema rack_utils
--
--
-- Process middle (non-trigger) schema schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table_other_indexes');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table_other_indexes ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_other_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r	RECORD;
	sch	TEXT;
BEGIN
	-- one day, I will want to construct the list of columns by hand rather
	-- than use pg_get_constraintdef.  watch me...

	sch := quote_ident( aud_schema );
	FOR _r IN
		SELECT c2.relname, pg_get_indexdef(i.indexrelid) as def, con.contype
	FROM pg_catalog.pg_class c
	    INNER JOIN pg_namespace n
		ON relnamespace = n.oid
	    INNER JOIN pg_catalog.pg_index i
		ON c.oid = i.indrelid
	    INNER JOIN pg_catalog.pg_class c2
		ON i.indexrelid = c2.oid
	   LEFT JOIN pg_catalog.pg_constraint con ON
		(con.conrelid = i.indrelid
		AND con.conindid = i.indexrelid )
	WHERE c.relname =  table_name
	AND      n.nspname = tbl_schema
	AND	con.contype IS NULL

	LOOP
		_r.def := regexp_replace(_r.def, ' ON ', ' ON ' || sch || '.');
		EXECUTE _r.def;
	END LOOP;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_columns ( _schema text, _table text );
CREATE OR REPLACE FUNCTION schema_support.get_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			record;
BEGIN
	FOR _r IN SELECT  a.attname as colname,
	    pg_catalog.format_type(a.atttypid, a.atttypmod) as coltype,
	    a.attnotnull, a.attnum
	FROM    pg_catalog.pg_attribute a
				INNER JOIN pg_class c on a.attrelid = c.oid
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
	WHERE   c.relname = _table
		  AND	n.nspname = _schema
	  AND   a.attnum > 0
	  AND   NOT a.attisdropped
		  AND	lower(a.attname) not like 'data_%'
	ORDER BY a.attnum
	LOOP
		SELECT array_append(cols, _r.colname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols	text[];
BEGIN
    _q := 'WITH cols AS (
	SELECT  n.nspname as schema, c.relname as relation, a.attname as colname, t.typoutput as type,
		a.attnum
	    FROM    pg_catalog.pg_attribute a
		INNER JOIN pg_catalog.pg_class c
		    ON a.attrelid = c.oid
		INNER JOIN pg_catalog.pg_namespace n
		    ON c.relnamespace = n.oid
				INNER JOIN pg_catalog.pg_type t
					ON  t.oid = a.atttypid
	    WHERE   a.attnum > 0
	    AND   NOT a.attisdropped
	    ORDER BY a.attnum
       ) SELECT array_agg(colname ORDER BY attnum) as cols
	FROM ( SELECT CASE WHEN ( o.type::text ~ ''enum'' OR n.type::text ~ ''enum'')  AND o.type != n.type THEN concat(quote_ident(n.colname), ''::text'')
					ELSE quote_ident(n.colname)
					END  AS colname,
				o.attnum
			FROM cols  o
	    INNER JOIN cols n USING (schema, colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.relation = $3
		) as prett
	';
	EXECUTE _q INTO cols USING _schema, _table1, _table2;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_pk_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_pk_columns ( _schema text, _table text );
CREATE OR REPLACE FUNCTION schema_support.get_pk_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			RECORD;
BEGIN
	for _r IN SELECT a.attname
			FROM pg_class c
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
				INNER JOIN pg_index i ON i.indrelid = c.oid
				INNER JOIN pg_attribute  a ON   a.attrelid = c.oid AND
								a.attnum = any(i.indkey)
			WHERE	c.relname = _table
			AND		n.nspname = _schema
			AND		indisprimary
	LOOP
		SELECT array_append(cols, _r.attname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_t1		integer;
	_t2		integer;
	_cnt	integer;
	_cols	TEXT[];
	_pkcol	TEXT[];
	_q		TEXT;
	_f		TEXT;
	_c		RECORD;
	_w		TEXT[];
	_ctl		TEXT[];
	_rv	boolean;
	_oj		jsonb;
	_nj		jsonb;
BEGIN
	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(schema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(schema, old_rel, new_rel);

	_ctl := NULL;
	FOREACH _f IN ARRAY prikeys
	LOOP
		SELECT array_append(_ctl, quote_ident(_f) ) INTO _ctl;
	END LOOP;
	_pkcol := _ctl;

	--
	-- Number of rows mismatch.  Show the missing rows based on the
	-- primary key.
	--
	IF _t1 != _t2 THEN
		RAISE NOTICE 'table % has % rows; table % has % rows (%)', old_rel, _t1, new_rel, _t2, _t1 - _t2;
		_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel)  ||
			' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' EXCEPT ( '
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' )) ';

		_cnt := 0;
		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE 'InOld/%: %', _cnt, _r;
			_cnt := _cnt + 1;
		END LOOP;

		_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel)  ||
			' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' EXCEPT ( '
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' )) ';

		_cnt := 0;
		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE 'InNew/%: %', _cnt, _r;
			_cnt := _cnt + 1;
		END LOOP;

		_rv := false;
	END IF;

	IF NOT _rv THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Relations do not match';
		END IF;
		RETURN false;
	END IF;

	-- At this point, the same number of rows appear in both, so need to
	-- figure out rows that are different between them.


	-- SELECT row_to_json(o) as old, row_to_json(n) as new
	-- FROM ( SELECT cols FROM old WHERE prikeys in Vv ) old,
	-- JOIN ( SELECT cols FROM new WHERE prikeys in Vv ) new
	-- USING (prikeys);
	-- WHERE (prikeys) IN
	-- ( SELECT  prikeys FROM (
	--		( SELECT cols FROM old EXCEPT ( SELECT cols FROM new ) )
	-- ))

	_q := ' SELECT row_to_json(old) as old, row_to_json(new) as new FROM ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel) || ' )) ' ||
		' ) subq) ORDER BY ' || array_to_string(_pkcol,',')
	;

	_t1 := 0;
	FOR _r IN EXECUTE _q
	LOOP
		_t1 := _t1 + 1;
		FOR _f IN SELECT json_object_keys(_r.new)
		LOOP
			IF _f = ANY ( prikeys ) OR _r.old->>_f IS DISTINCT FROM _r.new->>_f
			THEN
				IF _oj IS NULL THEN
					_oj := jsonb_build_object(_f, _r.old->>_f);
					_nj := jsonb_build_object(_f, _r.new->>_f);
				ELSE
					_oj := _oj || jsonb_build_object(_f, _r.old->>_f);
					_nj := _nj || jsonb_build_object(_f, _r.new->>_f);
				END IF;
			END IF;
		END LOOP;
		RAISE NOTICE 'mismatched row:';
		RAISE NOTICE 'OLD: %', _oj;
		RAISE NOTICE 'NEW: %', _nj;
		_rv := false;
	END LOOP;

	IF NOT _rv AND raise_exception THEN
		RAISE EXCEPTION 'Relations do not match (% rows)', _t1;
	ELSE
		RAISE NOTICE '% rows mismatch', _t1;
	END IF;
	return _rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	audsch	text;
	rk	char;
	rv	timestamp;
	ts	timestamp;
	obj	text;
	objaud text;
	objkind text;
	objschema text;
BEGIN
	SELECT	audit_schema
	INTO	audsch
	FROM	schema_support.schema_audit_map m
	WHERE	m.schema = relation_last_changed.schema;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Schema % not configured for this', schema;
	END IF;

	SELECT	relkind
	INTO	rk
	FROM	pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE	n.nspname = relation_last_changed.schema
	AND	c.relname = relation_last_changed.relation;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'No such object %.%', schema, relation;
	END IF;

	IF rk = 'r' THEN
		EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
			FROM '||quote_ident(audsch)||'.'|| quote_ident(relation)
		INTO rv;
		IF rv IS NULL THEN
			EXECUTE '
				SELECT	max("aud#timestamp")
				FROM	'||quote_ident(audsch)||'.'||quote_ident(relation)
			INTO rv;
		END IF;

		IF rv IS NULL THEN
			RETURN '-infinity'::timestamp;
		ELSE
			RETURN rv;
		END IF;
	END IF;

	IF rk = 'v' OR rk = 'm' THEN
		FOR obj,objaud,objkind, objschema IN WITH RECURSIVE recur AS (
		SELECT distinct rewrite.ev_class as root_oid, d.refobjid as oid
		FROM pg_depend d
		    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
		    JOIN pg_class c on rewrite.ev_class = c.oid
		    JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE c.relname = relation
		AND n.nspname = relation_last_changed.schema
		AND d.refobjsubid > 0
	    UNION ALL
		SELECT recur.root_oid, d.refobjid as oid
		FROM pg_depend d
		    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
		    JOIN pg_class c on rewrite.ev_class = c.oid
		JOIN recur ON recur.oid = rewrite.ev_class
		AND d.refobjsubid > 0
		AND c.relkind != 'm'
	    ), list AS ( select distinct m.audit_schema, c.relname, c.relkind, n.nspname as relschema, recur.*
		FROM pg_class c
		    JOIN recur on recur.oid = c.oid
		    JOIN pg_namespace n on c.relnamespace = n.oid
		    JOIN schema_support.schema_audit_map m
			ON m.schema = n.nspname
		WHERE relkind IN ('r', 'm')
		) SELECT relname, audit_schema, relkind, relschema from list
		LOOP
			-- if there is no audit table, assume its kept current.  This is
			-- likely some sort of cache table.  XXX - should probably be
			-- updated to use the materialized view update bits
			BEGIN
				IF objkind = 'r' THEN
					EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
						FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) ||'
						WHERE "aud#timestamp" > (
								SELECT max("aud#timestamp")
								FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) || '
							) - ''10 day''::interval'
						INTO ts;
					IF ts IS NULL THEN
						EXECUTE 'SELECT max("aud#timestamp")
							FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
							INTO ts;
					END IF;
				ELSIF objkind = 'm' THEN
					SELECT refresh INTO ts FROM schema_support.mv_refresh m WHERE m.schema = objschema
						AND m.view = obj;
				ELSE
					RAISE NOTICE 'Unknown object kind % for %.%', objkind, objaud, obj;
				END IF;
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): %.% -> %', objaud, obj, ts;
				END IF;
				IF rv IS NULL OR ts > rv THEN
					rv := ts;
				END IF;
			EXCEPTION WHEN undefined_table THEN
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): skipping %.%', schema, obj;
				END IF;
			END;
		END LOOP;
		RETURN rv;
	END IF;

	RAISE EXCEPTION 'Unable to process relkind %', rk;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'reset_table_sequence');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.reset_table_sequence ( schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence(schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r	RECORD;
	m	BIGINT;
BEGIN
	FOR _r IN
		WITH s AS (
			SELECT	pg_get_serial_sequence(schema||'.'||table_name,
				a.attname) as seq, a.attname as column
			FROM	pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE	c.relname = table_name
			AND	n.nspname = schema
				AND	a.attnum > 0
				AND	NOT a.attisdropped
		) SELECT s.*, nextval(s.seq) as nv FROM s WHERE seq IS NOT NULL
	LOOP
		EXECUTE 'SELECT max('||quote_ident(_r.column)||')+1 FROM  '
			|| quote_ident(schema)||'.'||quote_ident(table_name)
			INTO m;
		IF m IS NOT NULL THEN
			IF _r.nv > m THEN
				m := _r.nv;
			END IF;
			EXECUTE 'ALTER SEQUENCE ' || _r.seq || ' RESTART WITH '
				|| m;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_constraint_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in	SELECT n.nspname, c.relname, con.conname,
				pg_get_constraintdef(con.oid, true) as def
		FROM pg_constraint con
			INNER JOIN pg_class c on (c.relnamespace, c.oid) =
				(con.connamespace, con.conrelid)
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE con.confrelid in (
			select c.oid
			from pg_class c
				inner join pg_namespace n on n.oid = c.relnamespace
			WHERE c.relname = object
			AND n.nspname = schema
		) AND n.nspname != schema
	LOOP
		_ddl := 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
			' ADD CONSTRAINT ' || _r.conname || ' ' || _r.def;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define constraint for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'constraint', _ddl
			);
		IF dropit  THEN
			_cmd = 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
				' DROP CONSTRAINT ' || _r.conname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	-- process stored procedures
	FOR _r in SELECT  distinct np.nspname::text, dependent.proname::text
		FROM   pg_depend dep
			INNER join pg_type dependee on dependee.oid = dep.refobjid
			INNER join pg_namespace n on n.oid = dependee.typnamespace
			INNER join pg_proc dependent on dependent.oid = dep.objid
			INNER join pg_namespace np on np.oid = dependent.pronamespace
			WHERE   dependee.typname = object
			  AND	  n.nspname = schema
	LOOP
		-- RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.proname;
		PERFORM schema_support.save_constraint_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit);
	END LOOP;

	-- save any triggers on the view
	FOR _r in SELECT distinct n.nspname::text, dependee.relname::text, dependee.relkind
		FROM pg_depend
		JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
		JOIN pg_class as dependee ON pg_rewrite.ev_class = dependee.oid
		JOIN pg_class as dependent ON pg_depend.refobjid = dependent.oid
		JOIN pg_namespace n on n.oid = dependee.relnamespace
		JOIN pg_namespace sn on sn.oid = dependent.relnamespace
		JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
			AND pg_depend.refobjsubid = pg_attribute.attnum
		WHERE dependent.relname = object
		AND sn.nspname = schema
	LOOP
		IF _r.relkind = 'v' OR _r.relkind = 'm' THEN
			-- RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
		PERFORM schema_support.save_constraint_for_replay('jazzhands', 'table');
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_relations');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_relations ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object	varchar;
	_tabs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_fullgrant		varchar;
	_role		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();

	-- Handle table wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			c.relacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

	-- Handle column specific wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			a.attname as col,
			a.attacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
		ON a.attrelid = c.oid
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND a.attacl IS NOT NULL
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || '(' || _tabs.col || ')'
				' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.migrate_grants(username text, direction text, old_schema text DEFAULT 'jazzhands'::text, new_schema text DEFAULT 'jazzhands_legacy'::text)
 RETURNS text[]
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_rv	TEXT[];
	_r	RECORD;
	_q	TEXT;
BEGIN
	IF lower(direction) NOT IN ('grant','revoke') THEN
		RAISE EXCEPTION 'direction must be grant or revoke';
	END IF;

	FOR _r IN
		WITH x AS (
		SELECT *
			FROM (
		SELECT oid, schema, name,  typ,
			p->>'privilege_type' as privilege_type,
			col,
			r.usename as grantor, e.usename as grantee,
			r.usesysid as rid,  e.usesysid as eid,
			e.useconfig
		FROM (
			SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
				NULL::text as col,
			to_jsonb(pg_catalog.aclexplode(acl := c.relacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
		UNION ALL
		SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
			a.attname as col,
			to_jsonb(pg_catalog.aclexplode(a.attacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
				ON a.attrelid = c.oid
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
			AND a.attacl IS NOT NULL
		) x
		LEFT JOIN pg_user r ON r.usesysid = (p->>'grantor')::oid
		LEFT JOIN pg_user e ON e.usesysid = (p->>'grantee')::oid
		) i
		) select *
		FROM x
		WHERE ( schema = old_schema )
		AND grantee = username
		AND typ IN ('table', 'view', 'mview', 'foreign table')
		order by name, col
	LOOP
		IF _r.col IS NOT NULL THEN
			_q = concat(' (', _r.col, ') ');
		ELSE
			_q := NULL;
		END IF;
		IF lower(direction) = 'grant' THEN
			_q := concat('GRANT ', _r.privilege_type, _q, ' ON ', new_schema, '.', _r.name, ' TO ', _r.grantee);
		ELSIF lower(direction) = 'revoke' THEN
			_q := concat('REVOKE ', _r.privilege_type, _q, ' ON ', old_schema, '.', _r.name, ' FROM ', _r.grantee);
		END IF;


		_rv := array_append(_rv, _q);
		EXECUTE _q;
	END LOOP;
	RETURN _rv;
END;
$function$
;

--
-- Process middle (non-trigger) schema property_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
--
-- Process middle (non-trigger) schema physical_address_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('physical_address_utils', 'localized_physical_address');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS physical_address_utils.localized_physical_address ( physical_address_id integer, line_separator text, include_country boolean );
CREATE OR REPLACE FUNCTION physical_address_utils.localized_physical_address(physical_address_id integer, line_separator text DEFAULT ', '::text, include_country boolean DEFAULT true)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	address	text;
BEGIN
	SELECT concat_ws(line_separator,
			CASE WHEN iso_country_code IN 
					('SG', 'US', 'CA', 'UK', 'GB', 'FR', 'AU') THEN 
				concat_ws(' ', address_housename, address_street)
			WHEN iso_country_code IN ('IL') THEN
				concat_ws(', ', address_housename, address_street)
			WHEN iso_country_code IN ('ES') THEN
				concat_ws(', ', address_street, address_housename)
			ELSE
				concat_ws(' ', address_street, address_housename)
			END,
			address_pobox,
			address_building,
			address_neighborhood,
			CASE WHEN iso_country_code IN ('US', 'CA', 'UK') THEN 
				concat_ws(', ', address_city, 
					concat_ws(' ', address_region, postal_code))
			WHEN iso_country_code IN ('SG', 'AU') THEN
				concat_ws(' ', address_city, address_region, postal_code)
			ELSE
				concat_ws(' ', postal_code, address_city, address_region)
			END,
			iso_country_code
		)
	INTO address
	FROM
		physical_address pa
	WHERE
		pa.physical_address_id = 
			localized_physical_address.physical_address_id;
	RETURN address;
END; $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('physical_address_utils', 'localized_street_address');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS physical_address_utils.localized_street_address ( address_housename text, address_street text, address_building text, address_pobox text, iso_country_code text, line_separator text );
CREATE OR REPLACE FUNCTION physical_address_utils.localized_street_address(address_housename text DEFAULT NULL::text, address_street text DEFAULT NULL::text, address_building text DEFAULT NULL::text, address_pobox text DEFAULT NULL::text, iso_country_code text DEFAULT NULL::text, line_separator text DEFAULT ', '::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	RETURN concat_ws(line_separator,
			CASE WHEN iso_country_code IN 
					('SG', 'US', 'CA', 'UK', 'GB', 'FR', 'AU') THEN 
				concat_ws(' ', address_housename, address_street)
			WHEN iso_country_code IN ('IL') THEN
				concat_ws(', ', address_housename, address_street)
			WHEN iso_country_code IN ('ES') THEN
				concat_ws(', ', address_street, address_housename)
			ELSE
				concat_ws(' ', address_street, address_housename)
			END,
			address_pobox,
			address_building
		);
END; $function$
;

--
-- Process middle (non-trigger) schema component_utils
--
--
-- Process middle (non-trigger) schema snapshot_manip
--
--
-- Process middle (non-trigger) schema lv_manip
--
--
-- Process middle (non-trigger) schema approval_utils
--
--
-- Process middle (non-trigger) schema account_collection_manip
--
--
-- Process middle (non-trigger) schema script_hooks
--
--
-- Process middle (non-trigger) schema backend_utils
--
-- Creating new sequences....
CREATE SEQUENCE device_note_note_id_seq;
CREATE SEQUENCE encapsulation_range_encapsulation_range_id_seq;
CREATE SEQUENCE layer2_connection_layer2_connection_id_seq;
CREATE SEQUENCE person_parking_pass_person_parking_pass_id_seq;
CREATE SEQUENCE snmp_commstr_snmp_commstr_id_seq;
CREATE SEQUENCE val_auth_question_auth_question_id_seq;
CREATE SEQUENCE val_encryption_key_purpose_encryption_key_purpose_version_seq;


--------------------------------------------------------------------
-- DEALING WITH TABLE val_auth_question
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_auth_question', 'val_auth_question');

-- FOREIGN KEYS FROM
ALTER TABLE person_auth_question DROP CONSTRAINT IF EXISTS fk_person_aq_val_auth_ques;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_auth_question');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_auth_question DROP CONSTRAINT IF EXISTS pk_val_auth_question;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_auth_question ON jazzhands.val_auth_question;
DROP TRIGGER IF EXISTS trigger_audit_val_auth_question ON jazzhands.val_auth_question;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_auth_question');
---- BEGIN audit.val_auth_question TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_auth_question', 'val_auth_question');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_auth_question');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_auth_question DROP CONSTRAINT IF EXISTS val_auth_question_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_auth_question_pk_val_auth_question";
DROP INDEX IF EXISTS "audit"."val_auth_question_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."val_auth_question_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."val_auth_question_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_auth_question TEARDOWN


ALTER TABLE val_auth_question RENAME TO val_auth_question_v86;
ALTER TABLE audit.val_auth_question RENAME TO val_auth_question_v86;

CREATE TABLE jazzhands.val_auth_question
(
	auth_question_id	integer NOT NULL,
	question_text	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_auth_question', false);
ALTER TABLE val_auth_question
	ALTER auth_question_id
	SET DEFAULT nextval('jazzhands.val_auth_question_auth_question_id_seq'::regclass);
INSERT INTO val_auth_question (
	auth_question_id,
	question_text,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	auth_question_id,
	question_text,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_auth_question_v86;

INSERT INTO audit.val_auth_question (
	auth_question_id,
	question_text,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	auth_question_id,
	question_text,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.val_auth_question_v86;

ALTER TABLE jazzhands.val_auth_question
	ALTER auth_question_id
	SET DEFAULT nextval('jazzhands.val_auth_question_auth_question_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_auth_question ADD CONSTRAINT pk_val_auth_question PRIMARY KEY (auth_question_id);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_auth_question and jazzhands.person_auth_question
ALTER TABLE jazzhands.person_auth_question
	ADD CONSTRAINT fk_person_aq_val_auth_ques
	FOREIGN KEY (auth_question_id) REFERENCES jazzhands.val_auth_question(auth_question_id);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_auth_question');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_auth_question');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_auth_question');
ALTER SEQUENCE jazzhands.val_auth_question_auth_question_id_seq
	 OWNED BY val_auth_question.auth_question_id;
DROP TABLE IF EXISTS val_auth_question_v86;
DROP TABLE IF EXISTS audit.val_auth_question_v86;
-- DONE DEALING WITH TABLE val_auth_question (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_encryption_key_purpose
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_encryption_key_purpose', 'val_encryption_key_purpose');

-- FOREIGN KEYS FROM
ALTER TABLE encryption_key DROP CONSTRAINT IF EXISTS fk_enckey_enckeypurpose_val;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_encryption_key_purpose');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_encryption_key_purpose DROP CONSTRAINT IF EXISTS pk_val_encryption_key_purpose;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_encryption_key_purpose ON jazzhands.val_encryption_key_purpose;
DROP TRIGGER IF EXISTS trigger_audit_val_encryption_key_purpose ON jazzhands.val_encryption_key_purpose;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_encryption_key_purpose');
---- BEGIN audit.val_encryption_key_purpose TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_encryption_key_purpose', 'val_encryption_key_purpose');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_encryption_key_purpose');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_encryption_key_purpose DROP CONSTRAINT IF EXISTS val_encryption_key_purpose_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_encryption_key_purpose_pk_val_encryption_key_purpose";
DROP INDEX IF EXISTS "audit"."val_encryption_key_purpose_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."val_encryption_key_purpose_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."val_encryption_key_purpose_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_encryption_key_purpose TEARDOWN


ALTER TABLE val_encryption_key_purpose RENAME TO val_encryption_key_purpose_v86;
ALTER TABLE audit.val_encryption_key_purpose RENAME TO val_encryption_key_purpose_v86;

CREATE TABLE jazzhands.val_encryption_key_purpose
(
	encryption_key_purpose	varchar(50) NOT NULL,
	encryption_key_purpose_version	integer NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_encryption_key_purpose', false);
ALTER TABLE val_encryption_key_purpose
	ALTER encryption_key_purpose_version
	SET DEFAULT nextval('jazzhands.val_encryption_key_purpose_encryption_key_purpose_version_seq'::regclass);
INSERT INTO val_encryption_key_purpose (
	encryption_key_purpose,
	encryption_key_purpose_version,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	encryption_key_purpose,
	encryption_key_purpose_version,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_encryption_key_purpose_v86;

INSERT INTO audit.val_encryption_key_purpose (
	encryption_key_purpose,
	encryption_key_purpose_version,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	encryption_key_purpose,
	encryption_key_purpose_version,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.val_encryption_key_purpose_v86;

ALTER TABLE jazzhands.val_encryption_key_purpose
	ALTER encryption_key_purpose_version
	SET DEFAULT nextval('jazzhands.val_encryption_key_purpose_encryption_key_purpose_version_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_encryption_key_purpose ADD CONSTRAINT pk_val_encryption_key_purpose PRIMARY KEY (encryption_key_purpose, encryption_key_purpose_version);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.val_encryption_key_purpose IS 'Valid purpose of encryption used by the key_crypto package; Used to identify which functional application knows the app provided portion of the encryption key';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_encryption_key_purpose and jazzhands.encryption_key
ALTER TABLE jazzhands.encryption_key
	ADD CONSTRAINT fk_enckey_enckeypurpose_val
	FOREIGN KEY (encryption_key_purpose, encryption_key_purpose_version) REFERENCES jazzhands.val_encryption_key_purpose(encryption_key_purpose, encryption_key_purpose_version);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_encryption_key_purpose');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_encryption_key_purpose');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_encryption_key_purpose');
ALTER SEQUENCE jazzhands.val_encryption_key_purpose_encryption_key_purpose_version_seq
	 OWNED BY val_encryption_key_purpose.encryption_key_purpose_version;
DROP TABLE IF EXISTS val_encryption_key_purpose_v86;
DROP TABLE IF EXISTS audit.val_encryption_key_purpose_v86;
-- DONE DEALING WITH TABLE val_encryption_key_purpose (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_person_status
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_status', 'val_person_status');

-- FOREIGN KEYS FROM
ALTER TABLE account DROP CONSTRAINT IF EXISTS fk_acct_stat_id;
ALTER TABLE person_company DROP CONSTRAINT IF EXISTS fk_person_company_prsncmpy_status;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_person_status');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_person_status DROP CONSTRAINT IF EXISTS pk_val_person_status;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_person_status DROP CONSTRAINT IF EXISTS check_yes_no_856940377;
ALTER TABLE jazzhands.val_person_status DROP CONSTRAINT IF EXISTS check_yes_no_vpers_stat_enabled;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_person_status ON jazzhands.val_person_status;
DROP TRIGGER IF EXISTS trigger_audit_val_person_status ON jazzhands.val_person_status;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_person_status');
---- BEGIN audit.val_person_status TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_person_status', 'val_person_status');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_person_status');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.val_person_status DROP CONSTRAINT IF EXISTS val_person_status_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_val_person_status_pk_val_person_status";
DROP INDEX IF EXISTS "audit"."val_person_status_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."val_person_status_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."val_person_status_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.val_person_status TEARDOWN


ALTER TABLE val_person_status RENAME TO val_person_status_v86;
ALTER TABLE audit.val_person_status RENAME TO val_person_status_v86;

CREATE TABLE jazzhands.val_person_status
(
	person_status	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	is_enabled	character(1) NOT NULL,
	propagate_from_person	character(1) NOT NULL,
	is_forced	character(1) NOT NULL,
	is_db_enforced	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_person_status', false);
ALTER TABLE val_person_status
	ALTER is_forced
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_person_status
	ALTER is_db_enforced
	SET DEFAULT 'N'::bpchar;
INSERT INTO val_person_status (
	person_status,
	description,
	is_enabled,
	propagate_from_person,
	is_forced,		-- new column (is_forced)
	is_db_enforced,		-- new column (is_db_enforced)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	person_status,
	description,
	is_enabled,
	propagate_from_person,
	'N'::bpchar,		-- new column (is_forced)
	'N'::bpchar,		-- new column (is_db_enforced)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_person_status_v86;

INSERT INTO audit.val_person_status (
	person_status,
	description,
	is_enabled,
	propagate_from_person,
	is_forced,		-- new column (is_forced)
	is_db_enforced,		-- new column (is_db_enforced)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	person_status,
	description,
	is_enabled,
	propagate_from_person,
	NULL,		-- new column (is_forced)
	NULL,		-- new column (is_db_enforced)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.val_person_status_v86;

ALTER TABLE jazzhands.val_person_status
	ALTER is_forced
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands.val_person_status
	ALTER is_db_enforced
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.val_person_status ADD CONSTRAINT pk_val_person_status PRIMARY KEY (person_status);

-- Table/Column Comments
COMMENT ON COLUMN jazzhands.val_person_status.is_forced IS 'apps external can use this to indicate that the status is an override that should generally not be chagned.';
COMMENT ON COLUMN jazzhands.val_person_status.is_db_enforced IS 'If set, account and person rows with this setting can not be updated directly should go through stored procedures.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.val_person_status ADD CONSTRAINT check_yes_no_856940377
	CHECK (propagate_from_person = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE jazzhands.val_person_status ADD CONSTRAINT check_yes_no_vpers_stat_enabled
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_person_status and jazzhands.account
ALTER TABLE jazzhands.account
	ADD CONSTRAINT fk_acct_stat_id
	FOREIGN KEY (account_status) REFERENCES jazzhands.val_person_status(person_status);
-- consider FK between val_person_status and jazzhands.person_company
ALTER TABLE jazzhands.person_company
	ADD CONSTRAINT fk_person_company_prsncmpy_status
	FOREIGN KEY (person_company_status) REFERENCES jazzhands.val_person_status(person_status);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_person_status');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'val_person_status');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_person_status');
DROP TABLE IF EXISTS val_person_status_v86;
DROP TABLE IF EXISTS audit.val_person_status_v86;
-- DONE DEALING WITH TABLE val_person_status (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE account_auth_log
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_auth_log', 'account_auth_log');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account_auth_log DROP CONSTRAINT IF EXISTS fk_acctauthlog_accid;
ALTER TABLE jazzhands.account_auth_log DROP CONSTRAINT IF EXISTS fk_auth_resource;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'account_auth_log');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.account_auth_log DROP CONSTRAINT IF EXISTS pk_account_auth_log;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xieacctauthlog_ts_arsrc";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.account_auth_log DROP CONSTRAINT IF EXISTS check_yes_no_1416198228;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_account_auth_log ON jazzhands.account_auth_log;
DROP TRIGGER IF EXISTS trigger_audit_account_auth_log ON jazzhands.account_auth_log;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'account_auth_log');
---- BEGIN audit.account_auth_log TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'account_auth_log', 'account_auth_log');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'account_auth_log');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.account_auth_log DROP CONSTRAINT IF EXISTS account_auth_log_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_auth_log_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."account_auth_log_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."account_auth_log_aud#txid_idx";
DROP INDEX IF EXISTS "audit"."aud_account_auth_log_pk_account_auth_log";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.account_auth_log TEARDOWN


ALTER TABLE account_auth_log RENAME TO account_auth_log_v86;
ALTER TABLE audit.account_auth_log RENAME TO account_auth_log_v86;

CREATE TABLE jazzhands.account_auth_log
(
	account_id	integer NOT NULL,
	account_auth_ts	timestamp without time zone NOT NULL,
	auth_resource	varchar(50) NOT NULL,
	account_auth_seq	integer NOT NULL,
	was_auth_success	character(1) NOT NULL,
	auth_resource_instance	varchar(50) NOT NULL,
	auth_origin	varchar(50) NOT NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_auth_log', false);
INSERT INTO account_auth_log (
	account_id,
	account_auth_ts,
	auth_resource,
	account_auth_seq,
	was_auth_success,
	auth_resource_instance,
	auth_origin,
	data_ins_date,
	data_ins_user
) SELECT
	account_id,
	account_auth_ts,
	auth_resource,
	account_auth_seq,
	was_auth_success,
	auth_resource_instance,
	auth_origin,
	data_ins_date,
	data_ins_user
FROM account_auth_log_v86;

INSERT INTO audit.account_auth_log (
	account_id,
	account_auth_ts,
	auth_resource,
	account_auth_seq,
	was_auth_success,
	auth_resource_instance,
	auth_origin,
	data_ins_date,
	data_ins_user,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	account_id,
	account_auth_ts,
	auth_resource,
	account_auth_seq,
	was_auth_success,
	auth_resource_instance,
	auth_origin,
	data_ins_date,
	data_ins_user,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.account_auth_log_v86;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.account_auth_log ADD CONSTRAINT pk_account_auth_log PRIMARY KEY (account_id, account_auth_ts, auth_resource, account_auth_seq);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.account_auth_log IS 'Captures all system user authorizations for access to Vonage resources.';
COMMENT ON COLUMN jazzhands.account_auth_log.account_auth_seq IS 'This sequence is to support table PK with timestamps recived rounded to the secend and generating duplicates.';
COMMENT ON COLUMN jazzhands.account_auth_log.auth_resource_instance IS 'Keeps track of the server where a user was authenticating for a given resource';
COMMENT ON COLUMN jazzhands.account_auth_log.auth_origin IS 'Keeps track of where the request for authentication originated from.';
-- INDEXES
CREATE INDEX xieacctauthlog_ts_arsrc ON jazzhands.account_auth_log USING btree (account_auth_ts, auth_resource);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.account_auth_log ADD CONSTRAINT check_yes_no_1416198228
	CHECK (was_auth_success = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK account_auth_log and account
ALTER TABLE jazzhands.account_auth_log
	ADD CONSTRAINT fk_acctauthlog_accid
	FOREIGN KEY (account_id) REFERENCES jazzhands.account(account_id);
-- consider FK account_auth_log and val_auth_resource
ALTER TABLE jazzhands.account_auth_log
	ADD CONSTRAINT fk_auth_resource
	FOREIGN KEY (auth_resource) REFERENCES jazzhands.val_auth_resource(auth_resource);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_auth_log');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'account_auth_log');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_auth_log');
DROP TABLE IF EXISTS account_auth_log_v86;
DROP TABLE IF EXISTS audit.account_auth_log_v86;
-- DONE DEALING WITH TABLE account_auth_log (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE encapsulation_range
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'encapsulation_range', 'encapsulation_range');

-- FOREIGN KEYS FROM
ALTER TABLE layer2_network DROP CONSTRAINT IF EXISTS fk_l2_net_encap_range_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.encapsulation_range DROP CONSTRAINT IF EXISTS fk_encap_range_parent_encap_id;
ALTER TABLE jazzhands.encapsulation_range DROP CONSTRAINT IF EXISTS fk_encap_range_sitecode;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'encapsulation_range');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.encapsulation_range DROP CONSTRAINT IF EXISTS pk_vlan_range;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."ixf_encap_range_parentvlan";
DROP INDEX IF EXISTS "jazzhands"."ixf_encap_range_sitecode";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_encapsulation_range ON jazzhands.encapsulation_range;
DROP TRIGGER IF EXISTS trigger_audit_encapsulation_range ON jazzhands.encapsulation_range;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'encapsulation_range');
---- BEGIN audit.encapsulation_range TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'encapsulation_range', 'encapsulation_range');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'encapsulation_range');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.encapsulation_range DROP CONSTRAINT IF EXISTS encapsulation_range_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_encapsulation_range_pk_vlan_range";
DROP INDEX IF EXISTS "audit"."encapsulation_range_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."encapsulation_range_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."encapsulation_range_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.encapsulation_range TEARDOWN


ALTER TABLE encapsulation_range RENAME TO encapsulation_range_v86;
ALTER TABLE audit.encapsulation_range RENAME TO encapsulation_range_v86;

CREATE TABLE jazzhands.encapsulation_range
(
	encapsulation_range_id	integer NOT NULL,
	parent_encapsulation_range_id	integer  NULL,
	site_code	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'encapsulation_range', false);
ALTER TABLE encapsulation_range
	ALTER encapsulation_range_id
	SET DEFAULT nextval('jazzhands.encapsulation_range_encapsulation_range_id_seq'::regclass);
INSERT INTO encapsulation_range (
	encapsulation_range_id,
	parent_encapsulation_range_id,
	site_code,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	encapsulation_range_id,
	parent_encapsulation_range_id,
	site_code,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM encapsulation_range_v86;

INSERT INTO audit.encapsulation_range (
	encapsulation_range_id,
	parent_encapsulation_range_id,
	site_code,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	encapsulation_range_id,
	parent_encapsulation_range_id,
	site_code,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.encapsulation_range_v86;

ALTER TABLE jazzhands.encapsulation_range
	ALTER encapsulation_range_id
	SET DEFAULT nextval('jazzhands.encapsulation_range_encapsulation_range_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.encapsulation_range ADD CONSTRAINT pk_vlan_range PRIMARY KEY (encapsulation_range_id);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.encapsulation_range IS 'Captures how tables are assigned administratively.  This is not use for enforcement but primarily for presentation';
-- INDEXES
CREATE INDEX ixf_encap_range_parentvlan ON jazzhands.encapsulation_range USING btree (parent_encapsulation_range_id);
CREATE INDEX ixf_encap_range_sitecode ON jazzhands.encapsulation_range USING btree (site_code);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between encapsulation_range and jazzhands.layer2_network
ALTER TABLE jazzhands.layer2_network
	ADD CONSTRAINT fk_l2_net_encap_range_id
	FOREIGN KEY (encapsulation_range_id) REFERENCES jazzhands.encapsulation_range(encapsulation_range_id);

-- FOREIGN KEYS TO
-- consider FK encapsulation_range and encapsulation_range
ALTER TABLE jazzhands.encapsulation_range
	ADD CONSTRAINT fk_encap_range_parent_encap_id
	FOREIGN KEY (parent_encapsulation_range_id) REFERENCES jazzhands.encapsulation_range(encapsulation_range_id);
-- consider FK encapsulation_range and site
ALTER TABLE jazzhands.encapsulation_range
	ADD CONSTRAINT fk_encap_range_sitecode
	FOREIGN KEY (site_code) REFERENCES jazzhands.site(site_code);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'encapsulation_range');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'encapsulation_range');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'encapsulation_range');
ALTER SEQUENCE jazzhands.encapsulation_range_encapsulation_range_id_seq
	 OWNED BY encapsulation_range.encapsulation_range_id;
DROP TABLE IF EXISTS encapsulation_range_v86;
DROP TABLE IF EXISTS audit.encapsulation_range_v86;
-- DONE DEALING WITH TABLE encapsulation_range (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer2_connection
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_connection', 'layer2_connection');

-- FOREIGN KEYS FROM
ALTER TABLE layer2_connection_l2_network DROP CONSTRAINT IF EXISTS fk_l2c_l2n_l2connid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.layer2_connection DROP CONSTRAINT IF EXISTS fk_l2_conn_l1port;
ALTER TABLE jazzhands.layer2_connection DROP CONSTRAINT IF EXISTS fk_l2_conn_l2port;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'layer2_connection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.layer2_connection DROP CONSTRAINT IF EXISTS pk_layer2_connection;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_l2_conn_l1port";
DROP INDEX IF EXISTS "jazzhands"."xif_l2_conn_l2port";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_layer2_connection ON jazzhands.layer2_connection;
DROP TRIGGER IF EXISTS trigger_audit_layer2_connection ON jazzhands.layer2_connection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'layer2_connection');
---- BEGIN audit.layer2_connection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'layer2_connection', 'layer2_connection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'layer2_connection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.layer2_connection DROP CONSTRAINT IF EXISTS layer2_connection_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_layer2_connection_pk_layer2_connection";
DROP INDEX IF EXISTS "audit"."layer2_connection_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."layer2_connection_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."layer2_connection_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.layer2_connection TEARDOWN


ALTER TABLE layer2_connection RENAME TO layer2_connection_v86;
ALTER TABLE audit.layer2_connection RENAME TO layer2_connection_v86;

CREATE TABLE jazzhands.layer2_connection
(
	layer2_connection_id	integer NOT NULL,
	logical_port1_id	integer  NULL,
	logical_port2_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_connection', false);
ALTER TABLE layer2_connection
	ALTER layer2_connection_id
	SET DEFAULT nextval('jazzhands.layer2_connection_layer2_connection_id_seq'::regclass);
INSERT INTO layer2_connection (
	layer2_connection_id,
	logical_port1_id,
	logical_port2_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer2_connection_id,
	logical_port1_id,
	logical_port2_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM layer2_connection_v86;

INSERT INTO audit.layer2_connection (
	layer2_connection_id,
	logical_port1_id,
	logical_port2_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	layer2_connection_id,
	logical_port1_id,
	logical_port2_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.layer2_connection_v86;

ALTER TABLE jazzhands.layer2_connection
	ALTER layer2_connection_id
	SET DEFAULT nextval('jazzhands.layer2_connection_layer2_connection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.layer2_connection ADD CONSTRAINT pk_layer2_connection PRIMARY KEY (layer2_connection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_l2_conn_l1port ON jazzhands.layer2_connection USING btree (logical_port1_id);
CREATE INDEX xif_l2_conn_l2port ON jazzhands.layer2_connection USING btree (logical_port2_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between layer2_connection and jazzhands.layer2_connection_l2_network
ALTER TABLE jazzhands.layer2_connection_l2_network
	ADD CONSTRAINT fk_l2c_l2n_l2connid
	FOREIGN KEY (layer2_connection_id) REFERENCES jazzhands.layer2_connection(layer2_connection_id);

-- FOREIGN KEYS TO
-- consider FK layer2_connection and logical_port
ALTER TABLE jazzhands.layer2_connection
	ADD CONSTRAINT fk_l2_conn_l1port
	FOREIGN KEY (logical_port1_id) REFERENCES jazzhands.logical_port(logical_port_id);
-- consider FK layer2_connection and logical_port
ALTER TABLE jazzhands.layer2_connection
	ADD CONSTRAINT fk_l2_conn_l2port
	FOREIGN KEY (logical_port2_id) REFERENCES jazzhands.logical_port(logical_port_id);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_connection');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'layer2_connection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_connection');
ALTER SEQUENCE jazzhands.layer2_connection_layer2_connection_id_seq
	 OWNED BY layer2_connection.layer2_connection_id;
DROP TABLE IF EXISTS layer2_connection_v86;
DROP TABLE IF EXISTS audit.layer2_connection_v86;
-- DONE DEALING WITH TABLE layer2_connection (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE logical_port
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_port', 'logical_port');

-- FOREIGN KEYS FROM
ALTER TABLE layer2_connection DROP CONSTRAINT IF EXISTS fk_l2_conn_l1port;
ALTER TABLE layer2_connection DROP CONSTRAINT IF EXISTS fk_l2_conn_l2port;
ALTER TABLE logical_port_slot DROP CONSTRAINT IF EXISTS fk_lgl_port_slot_lgl_port_id;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_net_int_lgl_port_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS fk_logical_port_lg_port_type;
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS fk_logical_port_parent_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'logical_port');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS pk_logical_port;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_logical_port_lg_port_type";
DROP INDEX IF EXISTS "jazzhands"."xif_logical_port_parnet_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_logical_port ON jazzhands.logical_port;
DROP TRIGGER IF EXISTS trigger_audit_logical_port ON jazzhands.logical_port;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'logical_port');
---- BEGIN audit.logical_port TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'logical_port', 'logical_port');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'logical_port');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.logical_port DROP CONSTRAINT IF EXISTS logical_port_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_logical_port_pk_logical_port";
DROP INDEX IF EXISTS "audit"."logical_port_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."logical_port_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."logical_port_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.logical_port TEARDOWN


ALTER TABLE logical_port RENAME TO logical_port_v86;
ALTER TABLE audit.logical_port RENAME TO logical_port_v86;

CREATE TABLE jazzhands.logical_port
(
	logical_port_id	integer NOT NULL,
	logical_port_name	varchar(50) NOT NULL,
	logical_port_type	varchar(50) NOT NULL,
	device_id	integer  NULL,
	mlag_peering_id	integer  NULL,
	parent_logical_port_id	integer  NULL,
	mac_address	macaddr  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'logical_port', false);
ALTER TABLE logical_port
	ALTER logical_port_id
	SET DEFAULT nextval('jazzhands.logical_port_logical_port_id_seq'::regclass);
INSERT INTO logical_port (
	logical_port_id,
	logical_port_name,
	logical_port_type,
	device_id,		-- new column (device_id)
	mlag_peering_id,		-- new column (mlag_peering_id)
	parent_logical_port_id,
	mac_address,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	logical_port_id,
	logical_port_name,
	logical_port_type,
	NULL,		-- new column (device_id)
	NULL,		-- new column (mlag_peering_id)
	parent_logical_port_id,
	mac_address,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM logical_port_v86;

INSERT INTO audit.logical_port (
	logical_port_id,
	logical_port_name,
	logical_port_type,
	device_id,		-- new column (device_id)
	mlag_peering_id,		-- new column (mlag_peering_id)
	parent_logical_port_id,
	mac_address,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	logical_port_id,
	logical_port_name,
	logical_port_type,
	NULL,		-- new column (device_id)
	NULL,		-- new column (mlag_peering_id)
	parent_logical_port_id,
	mac_address,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.logical_port_v86;

ALTER TABLE jazzhands.logical_port
	ALTER logical_port_id
	SET DEFAULT nextval('jazzhands.logical_port_logical_port_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.logical_port ADD CONSTRAINT pk_logical_port PRIMARY KEY (logical_port_id);
ALTER TABLE jazzhands.logical_port ADD CONSTRAINT uq_device_id_logical_port_id UNIQUE (logical_port_id, device_id);
ALTER TABLE jazzhands.logical_port ADD CONSTRAINT uq_lg_port_name_type_device UNIQUE (logical_port_name, logical_port_type, device_id);
ALTER TABLE jazzhands.logical_port ADD CONSTRAINT uq_lg_port_name_type_mlag UNIQUE (logical_port_name, logical_port_type, mlag_peering_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif3logical_port ON jazzhands.logical_port USING btree (device_id);
CREATE INDEX xif4logical_port ON jazzhands.logical_port USING btree (mlag_peering_id);
CREATE INDEX xif_logical_port_lg_port_type ON jazzhands.logical_port USING btree (logical_port_type);
CREATE INDEX xif_logical_port_parnet_id ON jazzhands.logical_port USING btree (parent_logical_port_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between logical_port and jazzhands.layer2_connection
ALTER TABLE jazzhands.layer2_connection
	ADD CONSTRAINT fk_l2_conn_l1port
	FOREIGN KEY (logical_port1_id) REFERENCES jazzhands.logical_port(logical_port_id);
-- consider FK between logical_port and jazzhands.layer2_connection
ALTER TABLE jazzhands.layer2_connection
	ADD CONSTRAINT fk_l2_conn_l2port
	FOREIGN KEY (logical_port2_id) REFERENCES jazzhands.logical_port(logical_port_id);
-- consider FK between logical_port and jazzhands.logical_port_slot
ALTER TABLE jazzhands.logical_port_slot
	ADD CONSTRAINT fk_lgl_port_slot_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES jazzhands.logical_port(logical_port_id);
-- consider FK between logical_port and jazzhands.network_interface
ALTER TABLE jazzhands.network_interface
	ADD CONSTRAINT fk_net_int_lgl_port_id
	FOREIGN KEY (logical_port_id, device_id) REFERENCES jazzhands.logical_port(logical_port_id, device_id);

-- FOREIGN KEYS TO
-- consider FK logical_port and mlag_peering
--ALTER TABLE jazzhands.logical_port
--	ADD CONSTRAINT fk_logcal_port_mlag_peering_id
--	FOREIGN KEY (mlag_peering_id) REFERENCES jazzhands.mlag_peering(mlag_peering_id);
-- consider FK logical_port and device
ALTER TABLE jazzhands.logical_port
	ADD CONSTRAINT fk_logical_port_device_id
	FOREIGN KEY (device_id) REFERENCES jazzhands.device(device_id);
-- consider FK logical_port and val_logical_port_type
ALTER TABLE jazzhands.logical_port
	ADD CONSTRAINT fk_logical_port_lg_port_type
	FOREIGN KEY (logical_port_type) REFERENCES jazzhands.val_logical_port_type(logical_port_type);
-- consider FK logical_port and logical_port
ALTER TABLE jazzhands.logical_port
	ADD CONSTRAINT fk_logical_port_parent_id
	FOREIGN KEY (parent_logical_port_id) REFERENCES jazzhands.logical_port(logical_port_id);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_port');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'logical_port');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'logical_port');
ALTER SEQUENCE jazzhands.logical_port_logical_port_id_seq
	 OWNED BY logical_port.logical_port_id;
DROP TABLE IF EXISTS logical_port_v86;
DROP TABLE IF EXISTS audit.logical_port_v86;
-- DONE DEALING WITH TABLE logical_port (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE mlag_peering
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'mlag_peering', 'mlag_peering');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid1;
ALTER TABLE jazzhands.mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid2;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'mlag_peering');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.mlag_peering DROP CONSTRAINT IF EXISTS pk_mlag_peering;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_mlag_peering_devid1";
DROP INDEX IF EXISTS "jazzhands"."xif_mlag_peering_devid2";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_mlag_peering ON jazzhands.mlag_peering;
DROP TRIGGER IF EXISTS trigger_audit_mlag_peering ON jazzhands.mlag_peering;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'mlag_peering');
---- BEGIN audit.mlag_peering TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'mlag_peering', 'mlag_peering');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'mlag_peering');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.mlag_peering DROP CONSTRAINT IF EXISTS mlag_peering_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_mlag_peering_pk_mlag_peering";
DROP INDEX IF EXISTS "audit"."mlag_peering_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."mlag_peering_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."mlag_peering_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.mlag_peering TEARDOWN


ALTER TABLE mlag_peering RENAME TO mlag_peering_v86;
ALTER TABLE audit.mlag_peering RENAME TO mlag_peering_v86;

CREATE TABLE jazzhands.mlag_peering
(
	mlag_peering_id	integer NOT NULL,
	device1_id	integer NOT NULL,
	device2_id	integer NOT NULL,
	domain_id	varchar(50)  NULL,
	system_id	macaddr  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'mlag_peering', false);
ALTER TABLE mlag_peering
	ALTER mlag_peering_id
	SET DEFAULT nextval('jazzhands.mlag_peering_mlag_peering_id_seq'::regclass);
INSERT INTO mlag_peering (
	mlag_peering_id,
	device1_id,
	device2_id,
	domain_id,		-- new column (domain_id)
	system_id,		-- new column (system_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	mlag_peering_id,
	device1_id,
	device2_id,
	NULL,		-- new column (domain_id)
	NULL,		-- new column (system_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM mlag_peering_v86;

INSERT INTO audit.mlag_peering (
	mlag_peering_id,
	device1_id,
	device2_id,
	domain_id,		-- new column (domain_id)
	system_id,		-- new column (system_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	mlag_peering_id,
	device1_id,
	device2_id,
	NULL,		-- new column (domain_id)
	NULL,		-- new column (system_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.mlag_peering_v86;

ALTER TABLE jazzhands.mlag_peering
	ALTER mlag_peering_id
	SET DEFAULT nextval('jazzhands.mlag_peering_mlag_peering_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.mlag_peering ADD CONSTRAINT pk_mlag_peering PRIMARY KEY (mlag_peering_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_mlag_peering_devid1 ON jazzhands.mlag_peering USING btree (device1_id);
CREATE INDEX xif_mlag_peering_devid2 ON jazzhands.mlag_peering USING btree (device2_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between mlag_peering and jazzhands.logical_port
ALTER TABLE jazzhands.logical_port
	ADD CONSTRAINT fk_logcal_port_mlag_peering_id
	FOREIGN KEY (mlag_peering_id) REFERENCES jazzhands.mlag_peering(mlag_peering_id);

-- FOREIGN KEYS TO
-- consider FK mlag_peering and device
ALTER TABLE jazzhands.mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid1
	FOREIGN KEY (device1_id) REFERENCES jazzhands.device(device_id);
-- consider FK mlag_peering and device
ALTER TABLE jazzhands.mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid2
	FOREIGN KEY (device2_id) REFERENCES jazzhands.device(device_id);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'mlag_peering');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'mlag_peering');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'mlag_peering');
ALTER SEQUENCE jazzhands.mlag_peering_mlag_peering_id_seq
	 OWNED BY mlag_peering.mlag_peering_id;
DROP TABLE IF EXISTS mlag_peering_v86;
DROP TABLE IF EXISTS audit.mlag_peering_v86;
-- DONE DEALING WITH TABLE mlag_peering (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE operating_system
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'operating_system', 'operating_system');

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_os_id;
ALTER TABLE operating_system_snapshot DROP CONSTRAINT IF EXISTS fk_os_snap_osid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_osid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_company;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_os_family;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS r_819;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'operating_system');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS ak_operating_system_name_version;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS pk_operating_system;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS uq_operating_system_short_name;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif7operating_system";
DROP INDEX IF EXISTS "jazzhands"."xif_os_company";
DROP INDEX IF EXISTS "jazzhands"."xif_os_os_family";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_operating_system ON jazzhands.operating_system;
DROP TRIGGER IF EXISTS trigger_audit_operating_system ON jazzhands.operating_system;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'operating_system');
---- BEGIN audit.operating_system TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'operating_system', 'operating_system');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'operating_system');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.operating_system DROP CONSTRAINT IF EXISTS operating_system_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_operating_system_ak_operating_system_name_version";
DROP INDEX IF EXISTS "audit"."aud_operating_system_pk_operating_system";
DROP INDEX IF EXISTS "audit"."aud_operating_system_uq_operating_system_short_name";
DROP INDEX IF EXISTS "audit"."operating_system_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."operating_system_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."operating_system_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.operating_system TEARDOWN


ALTER TABLE operating_system RENAME TO operating_system_v86;
ALTER TABLE audit.operating_system RENAME TO operating_system_v86;

CREATE TABLE jazzhands.operating_system
(
	operating_system_id	integer NOT NULL,
	operating_system_name	varchar(255) NOT NULL,
	operating_system_short_name	varchar(255)  NULL,
	company_id	integer  NULL,
	major_version	varchar(50) NOT NULL,
	version	varchar(255) NOT NULL,
	operating_system_family	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'operating_system', false);
ALTER TABLE operating_system
	ALTER operating_system_id
	SET DEFAULT nextval('jazzhands.operating_system_operating_system_id_seq'::regclass);
INSERT INTO operating_system (
	operating_system_id,
	operating_system_name,
	operating_system_short_name,
	company_id,
	major_version,
	version,
	operating_system_family,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	operating_system_id,
	operating_system_name,
	operating_system_short_name,
	company_id,
	major_version,
	version,
	operating_system_family,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM operating_system_v86;

INSERT INTO audit.operating_system (
	operating_system_id,
	operating_system_name,
	operating_system_short_name,
	company_id,
	major_version,
	version,
	operating_system_family,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	operating_system_id,
	operating_system_name,
	operating_system_short_name,
	company_id,
	major_version,
	version,
	operating_system_family,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.operating_system_v86;

ALTER TABLE jazzhands.operating_system
	ALTER operating_system_id
	SET DEFAULT nextval('jazzhands.operating_system_operating_system_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.operating_system ADD CONSTRAINT ak_operating_system_name_version UNIQUE (operating_system_name, version);
ALTER TABLE jazzhands.operating_system ADD CONSTRAINT pk_operating_system PRIMARY KEY (operating_system_id);
ALTER TABLE jazzhands.operating_system ADD CONSTRAINT uq_operating_system_short_name UNIQUE (operating_system_short_name);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_os_company ON jazzhands.operating_system USING btree (company_id);
CREATE INDEX xif_os_os_family ON jazzhands.operating_system USING btree (operating_system_family);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between operating_system and jazzhands.device
ALTER TABLE jazzhands.device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES jazzhands.operating_system(operating_system_id);
-- consider FK between operating_system and jazzhands.operating_system_snapshot
ALTER TABLE jazzhands.operating_system_snapshot
	ADD CONSTRAINT fk_os_snap_osid
	FOREIGN KEY (operating_system_id) REFERENCES jazzhands.operating_system(operating_system_id);
-- consider FK between operating_system and jazzhands.property
ALTER TABLE jazzhands.property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES jazzhands.operating_system(operating_system_id);

-- FOREIGN KEYS TO
-- consider FK operating_system and company
ALTER TABLE jazzhands.operating_system
	ADD CONSTRAINT fk_os_company
	FOREIGN KEY (company_id) REFERENCES jazzhands.company(company_id) DEFERRABLE;
-- consider FK operating_system and val_operating_system_family
ALTER TABLE jazzhands.operating_system
	ADD CONSTRAINT fk_os_os_family
	FOREIGN KEY (operating_system_family) REFERENCES jazzhands.val_operating_system_family(operating_system_family);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'operating_system');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'operating_system');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'operating_system');
ALTER SEQUENCE jazzhands.operating_system_operating_system_id_seq
	 OWNED BY operating_system.operating_system_id;
DROP TABLE IF EXISTS operating_system_v86;
DROP TABLE IF EXISTS audit.operating_system_v86;
-- DONE DEALING WITH TABLE operating_system (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE person_parking_pass
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'person_parking_pass', 'person_parking_pass');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.person_parking_pass DROP CONSTRAINT IF EXISTS fk_person_parking_pass_personid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'person_parking_pass');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.person_parking_pass DROP CONSTRAINT IF EXISTS pk_system_parking_pass;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif2person_parking_pass";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_person_parking_pass ON jazzhands.person_parking_pass;
DROP TRIGGER IF EXISTS trigger_audit_person_parking_pass ON jazzhands.person_parking_pass;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'person_parking_pass');
---- BEGIN audit.person_parking_pass TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'person_parking_pass', 'person_parking_pass');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'person_parking_pass');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.person_parking_pass DROP CONSTRAINT IF EXISTS person_parking_pass_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_person_parking_pass_pk_system_parking_pass";
DROP INDEX IF EXISTS "audit"."person_parking_pass_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."person_parking_pass_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."person_parking_pass_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.person_parking_pass TEARDOWN


ALTER TABLE person_parking_pass RENAME TO person_parking_pass_v86;
ALTER TABLE audit.person_parking_pass RENAME TO person_parking_pass_v86;

CREATE TABLE jazzhands.person_parking_pass
(
	person_parking_pass_id	integer NOT NULL,
	person_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'person_parking_pass', false);
ALTER TABLE person_parking_pass
	ALTER person_parking_pass_id
	SET DEFAULT nextval('jazzhands.person_parking_pass_person_parking_pass_id_seq'::regclass);
INSERT INTO person_parking_pass (
	person_parking_pass_id,
	person_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	person_parking_pass_id,
	person_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM person_parking_pass_v86;

INSERT INTO audit.person_parking_pass (
	person_parking_pass_id,
	person_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	person_parking_pass_id,
	person_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.person_parking_pass_v86;

ALTER TABLE jazzhands.person_parking_pass
	ALTER person_parking_pass_id
	SET DEFAULT nextval('jazzhands.person_parking_pass_person_parking_pass_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.person_parking_pass ADD CONSTRAINT pk_system_parking_pass PRIMARY KEY (person_parking_pass_id, person_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif2person_parking_pass ON jazzhands.person_parking_pass USING btree (person_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK person_parking_pass and person
ALTER TABLE jazzhands.person_parking_pass
	ADD CONSTRAINT fk_person_parking_pass_personid
	FOREIGN KEY (person_id) REFERENCES jazzhands.person(person_id);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'person_parking_pass');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'person_parking_pass');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'person_parking_pass');
ALTER SEQUENCE jazzhands.person_parking_pass_person_parking_pass_id_seq
	 OWNED BY person_parking_pass.person_parking_pass_id;
DROP TABLE IF EXISTS person_parking_pass_v86;
DROP TABLE IF EXISTS audit.person_parking_pass_v86;
-- DONE DEALING WITH TABLE person_parking_pass (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE snmp_commstr
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'snmp_commstr', 'snmp_commstr');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.snmp_commstr DROP CONSTRAINT IF EXISTS fk_snmpstr_device_id;
ALTER TABLE jazzhands.snmp_commstr DROP CONSTRAINT IF EXISTS fk_snmpstr_snmpstrtyp_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'snmp_commstr');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.snmp_commstr DROP CONSTRAINT IF EXISTS ak_uq_snmp_commstr_de_snmp_com;
ALTER TABLE jazzhands.snmp_commstr DROP CONSTRAINT IF EXISTS pk_snmp_commstr;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."ix_snmp_commstr_netdev_id";
DROP INDEX IF EXISTS "jazzhands"."ix_snmp_commstr_type_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_snmp_commstr ON jazzhands.snmp_commstr;
DROP TRIGGER IF EXISTS trigger_audit_snmp_commstr ON jazzhands.snmp_commstr;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'snmp_commstr');
---- BEGIN audit.snmp_commstr TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'snmp_commstr', 'snmp_commstr');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'snmp_commstr');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.snmp_commstr DROP CONSTRAINT IF EXISTS snmp_commstr_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_snmp_commstr_ak_uq_snmp_commstr_de_snmp_com";
DROP INDEX IF EXISTS "audit"."aud_snmp_commstr_pk_snmp_commstr";
DROP INDEX IF EXISTS "audit"."snmp_commstr_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."snmp_commstr_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."snmp_commstr_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.snmp_commstr TEARDOWN


ALTER TABLE snmp_commstr RENAME TO snmp_commstr_v86;
ALTER TABLE audit.snmp_commstr RENAME TO snmp_commstr_v86;

CREATE TABLE jazzhands.snmp_commstr
(
	snmp_commstr_id	integer NOT NULL,
	device_id	integer NOT NULL,
	snmp_commstr_type	varchar(50) NOT NULL,
	rd_string	varchar(255)  NULL,
	wr_string	varchar(255)  NULL,
	purpose	varchar(255) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'snmp_commstr', false);
ALTER TABLE snmp_commstr
	ALTER snmp_commstr_id
	SET DEFAULT nextval('jazzhands.snmp_commstr_snmp_commstr_id_seq'::regclass);
INSERT INTO snmp_commstr (
	snmp_commstr_id,
	device_id,
	snmp_commstr_type,
	rd_string,
	wr_string,
	purpose,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	snmp_commstr_id,
	device_id,
	snmp_commstr_type,
	rd_string,
	wr_string,
	purpose,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM snmp_commstr_v86;

INSERT INTO audit.snmp_commstr (
	snmp_commstr_id,
	device_id,
	snmp_commstr_type,
	rd_string,
	wr_string,
	purpose,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	snmp_commstr_id,
	device_id,
	snmp_commstr_type,
	rd_string,
	wr_string,
	purpose,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.snmp_commstr_v86;

ALTER TABLE jazzhands.snmp_commstr
	ALTER snmp_commstr_id
	SET DEFAULT nextval('jazzhands.snmp_commstr_snmp_commstr_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.snmp_commstr ADD CONSTRAINT ak_uq_snmp_commstr_de_snmp_com UNIQUE (device_id, snmp_commstr_type);
ALTER TABLE jazzhands.snmp_commstr ADD CONSTRAINT pk_snmp_commstr PRIMARY KEY (snmp_commstr_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX ix_snmp_commstr_netdev_id ON jazzhands.snmp_commstr USING btree (device_id);
CREATE INDEX ix_snmp_commstr_type_id ON jazzhands.snmp_commstr USING btree (snmp_commstr_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK snmp_commstr and device
ALTER TABLE jazzhands.snmp_commstr
	ADD CONSTRAINT fk_snmpstr_device_id
	FOREIGN KEY (device_id) REFERENCES jazzhands.device(device_id);
-- consider FK snmp_commstr and val_snmp_commstr_type
ALTER TABLE jazzhands.snmp_commstr
	ADD CONSTRAINT fk_snmpstr_snmpstrtyp_id
	FOREIGN KEY (snmp_commstr_type) REFERENCES jazzhands.val_snmp_commstr_type(snmp_commstr_type);

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'snmp_commstr');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'snmp_commstr');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'snmp_commstr');
ALTER SEQUENCE jazzhands.snmp_commstr_snmp_commstr_id_seq
	 OWNED BY snmp_commstr.snmp_commstr_id;
DROP TABLE IF EXISTS snmp_commstr_v86;
DROP TABLE IF EXISTS audit.snmp_commstr_v86;
-- DONE DEALING WITH TABLE snmp_commstr (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE x509_signed_certificate
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_signed_certificate', 'x509_signed_certificate');

-- FOREIGN KEYS FROM
ALTER TABLE x509_key_usage_default DROP CONSTRAINT IF EXISTS fk_keyusg_deflt_x509crtid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_prop_x509_crt_id;
ALTER TABLE x509_key_usage_attribute DROP CONSTRAINT IF EXISTS fk_x509_certificate;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_csr_pvtkeyid;
ALTER TABLE jazzhands.x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_pvtkey_x509crt;
ALTER TABLE jazzhands.x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_cert;
ALTER TABLE jazzhands.x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_revoc_reason;
ALTER TABLE jazzhands.x509_signed_certificate DROP CONSTRAINT IF EXISTS fk_x509crtid_crttype;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'x509_signed_certificate');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.x509_signed_certificate DROP CONSTRAINT IF EXISTS ak_x509_cert_cert_ca_ser;
ALTER TABLE jazzhands.x509_signed_certificate DROP CONSTRAINT IF EXISTS pk_x509_certificate;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif3x509_signed_certificate";
DROP INDEX IF EXISTS "jazzhands"."xif4x509_signed_certificate";
DROP INDEX IF EXISTS "jazzhands"."xif5x509_signed_certificate";
DROP INDEX IF EXISTS "jazzhands"."xif6x509_signed_certificate";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.x509_signed_certificate DROP CONSTRAINT IF EXISTS check_yes_no_1566384929;
ALTER TABLE jazzhands.x509_signed_certificate DROP CONSTRAINT IF EXISTS check_yes_no_715951406;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_x509_signed_certificate ON jazzhands.x509_signed_certificate;
DROP TRIGGER IF EXISTS trigger_audit_x509_signed_certificate ON jazzhands.x509_signed_certificate;
DROP TRIGGER IF EXISTS trigger_x509_signed_ski_pvtkey_validate ON jazzhands.x509_signed_certificate;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'x509_signed_certificate');
---- BEGIN audit.x509_signed_certificate TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'x509_signed_certificate', 'x509_signed_certificate');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'x509_signed_certificate');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE audit.x509_signed_certificate DROP CONSTRAINT IF EXISTS x509_signed_certificate_pkey;
-- INDEXES
DROP INDEX IF EXISTS "audit"."aud_x509_signed_certificate_ak_x509_cert_cert_ca_ser";
DROP INDEX IF EXISTS "audit"."aud_x509_signed_certificate_pk_x509_certificate";
DROP INDEX IF EXISTS "audit"."x509_signed_certificate_aud#realtime_idx";
DROP INDEX IF EXISTS "audit"."x509_signed_certificate_aud#timestamp_idx";
DROP INDEX IF EXISTS "audit"."x509_signed_certificate_aud#txid_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
---- DONE audit.x509_signed_certificate TEARDOWN


ALTER TABLE x509_signed_certificate RENAME TO x509_signed_certificate_v86;
ALTER TABLE audit.x509_signed_certificate RENAME TO x509_signed_certificate_v86;

CREATE TABLE jazzhands.x509_signed_certificate
(
	x509_signed_certificate_id	integer NOT NULL,
	x509_certificate_type	varchar(50)  NULL,
	subject	varchar(255) NOT NULL,
	friendly_name	varchar(255) NOT NULL,
	subject_key_identifier	varchar(255)  NULL,
	is_active	character(1) NOT NULL,
	is_certificate_authority	character(1) NOT NULL,
	signing_cert_id	integer  NULL,
	x509_ca_cert_serial_number	numeric  NULL,
	public_key	text  NULL,
	private_key_id	integer  NULL,
	certificate_signing_request_id	integer  NULL,
	valid_from	timestamp without time zone NOT NULL,
	valid_to	timestamp without time zone NOT NULL,
	x509_revocation_date	timestamp with time zone  NULL,
	x509_revocation_reason	varchar(50)  NULL,
	ocsp_uri	varchar(255)  NULL,
	crl_uri	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'x509_signed_certificate', false);
ALTER TABLE x509_signed_certificate
	ALTER x509_signed_certificate_id
	SET DEFAULT nextval('jazzhands.x509_signed_certificate_x509_signed_certificate_id_seq'::regclass);
ALTER TABLE x509_signed_certificate
	ALTER x509_certificate_type
	SET DEFAULT 'default'::character varying;
ALTER TABLE x509_signed_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE x509_signed_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;
INSERT INTO x509_signed_certificate (
	x509_signed_certificate_id,
	x509_certificate_type,
	subject,
	friendly_name,
	subject_key_identifier,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key_id,
	certificate_signing_request_id,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	ocsp_uri,
	crl_uri,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	x509_signed_certificate_id,
	x509_certificate_type,
	subject,
	friendly_name,
	subject_key_identifier,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key_id,
	certificate_signing_request_id,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	ocsp_uri,
	crl_uri,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM x509_signed_certificate_v86;

INSERT INTO audit.x509_signed_certificate (
	x509_signed_certificate_id,
	x509_certificate_type,
	subject,
	friendly_name,
	subject_key_identifier,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key_id,
	certificate_signing_request_id,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	ocsp_uri,
	crl_uri,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
) SELECT
	x509_signed_certificate_id,
	x509_certificate_type,
	subject,
	friendly_name,
	subject_key_identifier,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key_id,
	certificate_signing_request_id,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	ocsp_uri,
	crl_uri,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM audit.x509_signed_certificate_v86;

ALTER TABLE jazzhands.x509_signed_certificate
	ALTER x509_signed_certificate_id
	SET DEFAULT nextval('jazzhands.x509_signed_certificate_x509_signed_certificate_id_seq'::regclass);
ALTER TABLE jazzhands.x509_signed_certificate
	ALTER x509_certificate_type
	SET DEFAULT 'default'::character varying;
ALTER TABLE jazzhands.x509_signed_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands.x509_signed_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.x509_signed_certificate ADD CONSTRAINT ak_x509_cert_cert_ca_ser UNIQUE (signing_cert_id, x509_ca_cert_serial_number);
ALTER TABLE jazzhands.x509_signed_certificate ADD CONSTRAINT pk_x509_certificate PRIMARY KEY (x509_signed_certificate_id);

-- Table/Column Comments
COMMENT ON TABLE jazzhands.x509_signed_certificate IS 'Signed X509 Certificate';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.x509_signed_certificate_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.x509_certificate_type IS 'business rule; default set but should be set to something else.
';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.friendly_name IS 'human readable name for certificate.  often just the CN.';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.subject_key_identifier IS 'x509 ski (hash, usually sha1 of public key).  must match private_key column if private key is set.';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.is_active IS 'indicates certificate is in active use.  This is used by tools to decide how to show it; does not indicate revocation';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.signing_cert_id IS 'x509_cert_id for the certificate that has signed this one.';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.x509_ca_cert_serial_number IS 'Serial number assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.public_key IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.  This will become mandatory in a future release.';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.private_key_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.certificate_signing_request_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.valid_from IS 'Timestamp indicating when the certificate becomes valid and can be used.';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.valid_to IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.x509_revocation_date IS 'if certificate was revoked, when it was revokeed.  reason must also be set.   NULL means not revoked';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.x509_revocation_reason IS 'if certificate was revoked, why iit was revokeed.  date must also be set.   NULL means not revoked';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.ocsp_uri IS 'The URI (without URI: prefix) of the OCSP server for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';
COMMENT ON COLUMN jazzhands.x509_signed_certificate.crl_uri IS 'The URI (without URI: prefix) of the CRL for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';
-- INDEXES
CREATE INDEX xif3x509_signed_certificate ON jazzhands.x509_signed_certificate USING btree (x509_revocation_reason);
CREATE INDEX xif4x509_signed_certificate ON jazzhands.x509_signed_certificate USING btree (private_key_id);
CREATE INDEX xif5x509_signed_certificate ON jazzhands.x509_signed_certificate USING btree (certificate_signing_request_id);
CREATE INDEX xif6x509_signed_certificate ON jazzhands.x509_signed_certificate USING btree (x509_certificate_type);

-- CHECK CONSTRAINTS
ALTER TABLE jazzhands.x509_signed_certificate ADD CONSTRAINT check_yes_no_1566384929
	CHECK (is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE jazzhands.x509_signed_certificate ADD CONSTRAINT check_yes_no_715951406
	CHECK (is_certificate_authority = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between x509_signed_certificate and jazzhands.x509_key_usage_default
ALTER TABLE jazzhands.x509_key_usage_default
	ADD CONSTRAINT fk_keyusg_deflt_x509crtid
	FOREIGN KEY (x509_signed_certificate_id) REFERENCES jazzhands.x509_signed_certificate(x509_signed_certificate_id);
-- consider FK between x509_signed_certificate and jazzhands.property
ALTER TABLE jazzhands.property
	ADD CONSTRAINT fk_prop_x509_crt_id
	FOREIGN KEY (x509_signed_certificate_id) REFERENCES jazzhands.x509_signed_certificate(x509_signed_certificate_id);
-- consider FK between x509_signed_certificate and jazzhands.x509_key_usage_attribute
ALTER TABLE jazzhands.x509_key_usage_attribute
	ADD CONSTRAINT fk_x509_certificate
	FOREIGN KEY (x509_cert_id) REFERENCES jazzhands.x509_signed_certificate(x509_signed_certificate_id);

-- FOREIGN KEYS TO
-- consider FK x509_signed_certificate and certificate_signing_request
ALTER TABLE jazzhands.x509_signed_certificate
	ADD CONSTRAINT fk_csr_pvtkeyid
	FOREIGN KEY (certificate_signing_request_id) REFERENCES jazzhands.certificate_signing_request(certificate_signing_request_id);
-- consider FK x509_signed_certificate and private_key
ALTER TABLE jazzhands.x509_signed_certificate
	ADD CONSTRAINT fk_pvtkey_x509crt
	FOREIGN KEY (private_key_id) REFERENCES jazzhands.private_key(private_key_id);
-- consider FK x509_signed_certificate and x509_signed_certificate
ALTER TABLE jazzhands.x509_signed_certificate
	ADD CONSTRAINT fk_x509_cert_cert
	FOREIGN KEY (signing_cert_id) REFERENCES jazzhands.x509_signed_certificate(x509_signed_certificate_id);
-- consider FK x509_signed_certificate and val_x509_revocation_reason
ALTER TABLE jazzhands.x509_signed_certificate
	ADD CONSTRAINT fk_x509_cert_revoc_reason
	FOREIGN KEY (x509_revocation_reason) REFERENCES jazzhands.val_x509_revocation_reason(x509_revocation_reason);
-- consider FK x509_signed_certificate and val_x509_certificate_type
ALTER TABLE jazzhands.x509_signed_certificate
	ADD CONSTRAINT fk_x509crtid_crttype
	FOREIGN KEY (x509_certificate_type) REFERENCES jazzhands.val_x509_certificate_type(x509_certificate_type);

-- TRIGGERS
-- consider NEW jazzhands.x509_signed_ski_pvtkey_validate
CREATE OR REPLACE FUNCTION jazzhands.x509_signed_ski_pvtkey_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ski	TEXT;
BEGIN
	--
	-- XXX needs to be tweaked to ensure that both are set or not set.
	--
	IF NEW.private_key_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	subject_key_identifier
	INTO	ski
	FROM	private_key p
	WHERE	p.private_key_id = NEW.private_key_id;

	IF FOUND AND ski != NEW.subject_key_identifier THEN
		RAISE EXCEPTION 'subject key identifier must match private key in private_key' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_x509_signed_ski_pvtkey_validate AFTER INSERT OR UPDATE OF subject_key_identifier, private_key_id ON jazzhands.x509_signed_certificate FOR EACH ROW EXECUTE PROCEDURE jazzhands.x509_signed_ski_pvtkey_validate();

-- XXX - may need to include trigger function
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'x509_signed_certificate');
SELECT schema_support.build_audit_table_pkak_indexes('audit', 'jazzhands', 'x509_signed_certificate');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'x509_signed_certificate');
ALTER SEQUENCE jazzhands.x509_signed_certificate_x509_signed_certificate_id_seq
	 OWNED BY x509_signed_certificate.x509_signed_certificate_id;
DROP TABLE IF EXISTS x509_signed_certificate_v86;
DROP TABLE IF EXISTS audit.x509_signed_certificate_v86;
-- DONE DEALING WITH TABLE x509_signed_certificate (jazzhands)
--------------------------------------------------------------------
--
-- BEGIN: process_ancillary_schema(jazzhands_cache)
--
-- DONE: process_ancillary_schema(jazzhands_cache)
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_site_netblock_expanded_assigned (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_site_netblock_expanded_assigned');
DROP VIEW IF EXISTS jazzhands.v_site_netblock_expanded_assigned;
CREATE VIEW jazzhands.v_site_netblock_expanded_assigned AS
 SELECT meat.site_code,
    meat.netblock_id
   FROM ( SELECT p.site_code,
            n.netblock_id,
            rank() OVER (PARTITION BY n.netblock_id ORDER BY (array_length(hc.path, 1)), (array_length(n.path, 1))) AS tier
           FROM jazzhands.netblock_collection_netblock ncn
             JOIN jazzhands_cache.ct_netblock_collection_hier_from_ancestor hc USING (netblock_collection_id)
             JOIN jazzhands_cache.ct_netblock_hier n ON ncn.netblock_id = n.root_netblock_id
             JOIN ( SELECT property.property_id,
                    property.account_collection_id,
                    property.account_id,
                    property.account_realm_id,
                    property.company_collection_id,
                    property.company_id,
                    property.device_collection_id,
                    property.dns_domain_collection_id,
                    property.layer2_network_collection_id,
                    property.layer3_network_collection_id,
                    property.netblock_collection_id,
                    property.network_range_id,
                    property.operating_system_id,
                    property.operating_system_snapshot_id,
                    property.person_id,
                    property.property_collection_id,
                    property.service_env_collection_id,
                    property.site_code,
                    property.x509_signed_certificate_id,
                    property.property_name,
                    property.property_type,
                    property.property_value,
                    property.property_value_timestamp,
                    property.property_value_account_coll_id,
                    property.property_value_device_coll_id,
                    property.property_value_json,
                    property.property_value_nblk_coll_id,
                    property.property_value_password_type,
                    property.property_value_person_id,
                    property.property_value_sw_package_id,
                    property.property_value_token_col_id,
                    property.property_rank,
                    property.start_date,
                    property.finish_date,
                    property.is_enabled,
                    property.data_ins_user,
                    property.data_ins_date,
                    property.data_upd_user,
                    property.data_upd_date
                   FROM jazzhands.property
                  WHERE property.property_name::text = 'per-site-netblock_collection'::text AND property.property_type::text = 'automated'::text) p USING (netblock_collection_id)) meat
  WHERE meat.tier = 1;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_site_netblock_expanded_assigned';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_site_netblock_expanded_assigned failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_site_netblock_expanded_assigned (jazzhands)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_hier_expanded (jazzhands)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_netblock_hier_expanded');
DROP VIEW IF EXISTS jazzhands.v_netblock_hier_expanded;
CREATE VIEW jazzhands.v_netblock_hier_expanded AS
 SELECT array_length(ct_netblock_hier.path, 1) AS netblock_level,
    ct_netblock_hier.root_netblock_id,
    v_site_netblock_expanded.site_code,
    ct_netblock_hier.path,
    nb.netblock_id,
    nb.ip_address,
    nb.netblock_type,
    nb.is_single_address,
    nb.can_subnet,
    nb.parent_netblock_id,
    nb.netblock_status,
    nb.ip_universe_id,
    nb.description,
    nb.external_id,
    nb.data_ins_user,
    nb.data_ins_date,
    nb.data_upd_user,
    nb.data_upd_date
   FROM jazzhands_cache.ct_netblock_hier
     JOIN jazzhands.netblock nb USING (netblock_id)
     LEFT JOIN jazzhands.v_site_netblock_expanded USING (netblock_id);

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands' AND type = 'view' AND object = 'v_netblock_hier_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_hier_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_hier_expanded (jazzhands)
--------------------------------------------------------------------
--
-- Process drops in jazzhands_cache
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands_cache', 'cache_netblock_hier_handler');
CREATE OR REPLACE FUNCTION jazzhands_cache.cache_netblock_hier_handler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_cnt	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP IN ('UPDATE','INSERT') AND NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF TG_OP = 'DELETE' THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		WHERE	OLD.netblock_id = ANY(path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/DEL %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netblock % from cache == %',
			OLD.netblock_id, _cnt;
	ELSIF TG_OP = 'UPDATE' AND OLD.parent_netblock_id IS NOT NULL THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		WHERE	OLD.parent_netblock_id IS NOT NULL
					AND		OLD.parent_netblock_id = ANY (path)
					AND		OLD.netblock_id = ANY (path)
					AND		netblock_id = OLD.netblock_id
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/upd %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netblock %/% from cache == %',
			OLD.netblock_id, OLD.parent_netblock_id, _cnt;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--


	IF TG_OP IN ('INSERT') THEN
		RAISE DEBUG 'Inserting reference for new netblock % into cache [%]',
			NEW.netblock_id, NEW.parent_netblock_id;

		FOR _r IN
		WITH RECURSIVE tier (
			root_netblock_id,
			intermediate_netblock_id,
			netblock_id,
			path
		)AS (
			SELECT parent_netblock_id,
				parent_netblock_id,
				netblock_id,
				ARRAY[netblock_id, parent_netblock_id]
			FROM netblock WHERE netblock_id = NEW.netblock_id
			AND parent_netblock_id IS NOT NULL
		UNION ALL
			SELECT n.parent_netblock_id,
				tier.intermediate_netblock_id,
				tier.netblock_id,
				array_append(tier.path, n.parent_netblock_id)
			FROM tier
				JOIN netblock n ON n.netblock_id = tier.root_netblock_id
			WHERE n.parent_netblock_id IS NOT NULL
		), combo AS (
			 SELECT * FROM tier
			UNION ALL
			SELECT netblock_id, netblock_id, netblock_id, ARRAY[netblock_id]
			FROM netblock WHERE netblock_id = NEW.netblock_id
		) SELECT * FROM combo
		LOOP
			RAISE DEBUG 'nb/ins up %', to_json(_r);
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id, intermediate_netblock_id, 
				netblock_id, path
			) VALUES (
				_r.root_netblock_id, _r.intermediate_netblock_id, 
				_r.netblock_id, _r.path
			);
		END LOOP;

	ELSIF (TG_OP = 'UPDATE' AND NEW.parent_netblock_id IS NOT NULL) THEN

		FOR _r IN
		WITH base AS (
			SELECT *
			FROM jazzhands_cache.ct_netblock_hier
			WHERE NEW.netblock_id = ANY (path)
			AND array_length(path, 1) > 2

		), inew AS (
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id,
				intermediate_netblock_id,
				netblock_id,
				path
			)  SELECT
				base.root_netblock_id,
				NEW.parent_netblock_id,
				netblock_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.netblock_id)-1)],
						ARRAY[NEW.netblock_id, NEW.parent_netblock_id]
					),
					path[(array_position(path, NEW.netblock_id)+1) :]
				)
				FROM base
				RETURNING *
		), uold AS (
			UPDATE jazzhands_cache.ct_netblock_hier n
			SET root_netblock_id = base.root_netblock_id,
				intermediate_netblock_id = NEW.parent_netblock_id,
			path = array_replace(base.path, base.root_netblock_id, NEW.parent_netblock_id)
			FROM base
			WHERE n.path = base.path
				RETURNING n.*
		) SELECT 'ins' as "what", * FROM inew
			UNION
			SELECT 'upd' as "what", * FROM uold

		LOOP
			RAISE DEBUG 'down:%', to_json(_r);
		END LOOP;

		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references down for updated netblock %/% into cache == %',
			NEW.netblock_id, NEW.parent_netblock_id, _cnt;

		-- walk up and install rows for all the things above due to change
		FOR _r IN
		WITH RECURSIVE tier (
			root_netblock_id,
			intermediate_netblock_id,
			netblock_id,
			path,
			cycle
		)AS (
			SELECT parent_netblock_id,
                parent_netblock_id,
                netblock_id,
                ARRAY[netblock_id, parent_netblock_id],
                false
            FROM netblock WHERE netblock_id = NEW.netblock_id
        UNION ALL
            SELECT n.parent_netblock_id,
                n.netblock_Id,
                tier.netblock_id,
                array_append(tier.path, n.parent_netblock_id),
                n.parent_netblock_id = ANY(path)
            FROM tier
                JOIN netblock n ON n.netblock_id = tier.root_netblock_id
            WHERE n.parent_netblock_id IS NOT NULL
			AND NOT cycle
        ) SELECT * FROM tier
		LOOP
			IF _r.cycle THEN
				RAISE EXCEPTION 'Insert Created a netblock loop.'
					USING ERRCODE = 'JH101';
			END IF;
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id, intermediate_netblock_id, netblock_id, path
			) VALUES (
				_r.root_netblock_id, _r.intermediate_netblock_id, _r.netblock_id, _r.path
			);

			RAISE DEBUG 'nb/upd up %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references up for updated netblock %/% into cache == %',
			NEW.netblock_id, NEW.parent_netblock_id, _cnt;
	END IF;
	RETURN NULL;
END
$function$
;

--
-- Process drops in jazzhands
--
-- New function
CREATE OR REPLACE FUNCTION jazzhands.val_property_value_del_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	_tal	INTEGER;
BEGIN

	SELECT COUNT(*)
	INTO _tal
	FROM property p
	WHERE p.property_name = OLD.property_name
	AND p.property_type = OLD.property_type
	AND p.property_value = OLD.valid_property_value;

	IF _tal > 0 THEN
		RAISE EXCEPTION '% instances of %:% with value %',
			_tal, OLD.property_type, OLD.property_name, OLD.valid_property_value
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN OLD;
END;
$function$
;

--
-- Process drops in net_manip
--
--
-- Process drops in network_strings
--
--
-- Process drops in time_util
--
--
-- Process drops in dns_utils
--
--
-- Process drops in person_manip
--
--
-- Process drops in layerx_network_manip
--
--
-- Process drops in auto_ac_manip
--
--
-- Process drops in company_manip
--
--
-- Process drops in component_connection_utils
--
--
-- Process drops in token_utils
--
--
-- Process drops in port_support
--
--
-- Process drops in port_utils
--
--
-- Process drops in device_utils
--
--
-- Process drops in netblock_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'calculate_intermediate_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.calculate_intermediate_netblocks ( ip_block_1 inet, ip_block_2 inet, netblock_type text, ip_universe_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.calculate_intermediate_netblocks(ip_block_1 inet DEFAULT NULL::inet, ip_block_2 inet DEFAULT NULL::inet, netblock_type text DEFAULT 'default'::text, ip_universe_id integer DEFAULT 0)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	current_nb		inet;
	new_nb			inet;
	min_addr		inet;
	max_addr		inet;
	family_bits		integer;
BEGIN
	IF ip_block_1 IS NULL OR ip_block_2 IS NULL THEN
		RAISE EXCEPTION 'Must specify both ip_block_1 and ip_block_2';
	END IF;

	IF family(ip_block_1) != family(ip_block_2) THEN
		RAISE EXCEPTION 'families of ip_block_1 and ip_block_2 must match';
	END IF;

	-- Make sure these are network blocks
	ip_block_1 := network(ip_block_1);
	ip_block_2 := network(ip_block_2);

	-- If the blocks are subsets of each other, then error

	IF ip_block_1 <<= ip_block_2 AND ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks % and % intersect each other',
			ip_block_1,
			ip_block_2;
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	family_bits := CASE WHEN family(ip_block_1) = 4 THEN 32 ELSE 128 END;

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;

		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), family_bits) >
			set_masklen(max_addr, family_bits)
		THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < family_bits THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			max_addr := broadcast(new_nb);
		END IF;
		current_nb := new_nb;
	END LOOP;

	-- Now loop through there to find the unused blocks at the front

	LOOP
		IF host(current_nb) = host(ip_block_2) OR
			masklen(current_nb) >= family_bits
		THEN
			RETURN;
		END IF;

		current_nb := set_masklen(current_nb, masklen(current_nb) + 1);
		IF NOT (current_nb >>= ip_block_2) THEN
			ip_addr := current_nb;
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND AND masklen(ip_addr) < family_bits THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			current_nb := broadcast(current_nb) + 1;
			CONTINUE;
		END IF;
	END LOOP;
	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'delete_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.delete_netblock ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.delete_netblock(in_netblock_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE
		netblock_id = in_netblock_id;

	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;

	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_ip_universe');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_best_ip_universe ( ip_address inet, ip_namespace character varying );
CREATE OR REPLACE FUNCTION netblock_utils.find_best_ip_universe(ip_address inet, ip_namespace character varying DEFAULT 'default'::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	u_id	ip_universe.ip_universe_id%TYPE;
	ip	inet;
	nsp	text;
BEGIN
	ip := ip_address;
	nsp := ip_namespace;

	SELECT	nb.ip_universe_id
	INTO	u_id
	FROM	netblock nb
		JOIN ip_universe u USING (ip_universe_id)
	WHERE	is_single_address = 'N'
	AND	nb.ip_address >>= ip
	AND	u.ip_namespace = 'default'
	ORDER BY masklen(nb.ip_address) desc
	LIMIT 1;

	IF u_id IS NOT NULL THEN
		RETURN u_id;
	END IF;
	RETURN 0;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_parent_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id ( in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer, in_fuzzy_can_subnet boolean, can_fix_can_subnet boolean );
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer DEFAULT NULL::integer, in_netblock_type character varying DEFAULT 'default'::character varying, in_ip_universe_id integer DEFAULT 0, in_is_single_address character DEFAULT 'N'::bpchar, in_netblock_id integer DEFAULT NULL::integer, in_fuzzy_can_subnet boolean DEFAULT false, can_fix_can_subnet boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	IF (in_netmask_bits IS NOT NULL) THEN
		in_IpAddress := set_masklen(in_IpAddress, in_Netmask_Bits);
	END IF;

	select  Netblock_Id
	  into	par_nbid
	  from  ( select Netblock_Id, Ip_Address
		    from jazzhands.netblock
		   where
		   	in_IpAddress <<= ip_address
		    and is_single_address = 'N'
			and netblock_type = in_netblock_type
			and ip_universe_id = in_ip_universe_id
		    and (
				(in_is_single_address = 'N' AND
					masklen(ip_address) < masklen(In_IpAddress))
				OR
				(in_is_single_address = 'Y' AND can_subnet = 'N' AND
					(in_Netmask_Bits IS NULL
						OR masklen(Ip_Address) = in_Netmask_Bits))
			)
			and (in_netblock_id IS NULL OR
				netblock_id != in_netblock_id)
		order by masklen(ip_address) desc
	) subq LIMIT 1;

	IF par_nbid IS NULL AND in_is_single_address = 'Y' AND in_fuzzy_can_subnet THEN
		select  Netblock_Id
		  into	par_nbid
		  from  ( select Netblock_Id, Ip_Address
			    from jazzhands.netblock
			   where
			   	in_IpAddress <<= ip_address
			    and is_single_address = 'N'
				and netblock_type = in_netblock_type
				and ip_universe_id = in_ip_universe_id
			    and
					(in_is_single_address = 'Y' AND can_subnet = 'Y' AND
						(in_Netmask_Bits IS NULL
							OR masklen(Ip_Address) = in_Netmask_Bits))
				and (in_netblock_id IS NULL OR
					netblock_id != in_netblock_id)
				and netblock_id not IN (
					select parent_netblock_id from jazzhands.netblock
						where is_single_address = 'N'
						and parent_netblock_id is not null
				)
			order by masklen(ip_address) desc
		) subq LIMIT 1;

		IF can_fix_can_subnet AND par_nbid IS NOT NULL THEN
			UPDATE netblock SET can_subnet = 'N' where netblock_id = par_nbid;
		END IF;
	END IF;


	return par_nbid;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_parent_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nbrec		RECORD;
BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE
		netblock_id = in_netblock_id;

	RETURN netblock_utils.find_best_parent_id(
		nbrec.ip_address,
		masklen(nbrec.ip_address),
		nbrec.netblock_type,
		nbrec.ip_universe_id,
		nbrec.is_single_address,
		in_netblock_id
	);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblock ( parent_netblock_id integer, netmask_bits integer, single_address boolean, allocation_method text, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	RETURN QUERY SELECT * FROM netblock_utils.find_free_netblocks(
			parent_netblock_id := parent_netblock_id,
			netmask_bits := netmask_bits,
			single_address := single_address,
			allocate_from_bottom := allocate_from_bottom,
			desired_ip_address := desired_ip_address,
			max_addresses := 1);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_id integer, netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	RETURN QUERY SELECT * FROM netblock_utils.find_free_netblocks(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		single_address := single_address,
		allocation_method := allocation_method,
		desired_ip_address := desired_ip_address,
		max_addresses := max_addresses);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	netrange_rec	RECORD;
	inet_list		inet[];
	current_ip		inet;
	saved_method	text;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	rnd_matches		integer;
	max_rnd_value	bigint;
	rnd_value		bigint;
	family_bits		integer;
BEGIN
	matches := 0;
	saved_method = allocation_method;

	IF allocation_method IS NOT NULL AND allocation_method
			NOT IN ('top', 'bottom', 'random', 'default') THEN
		RAISE 'address_type must be one of top, bottom, random, or default'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- Sanitize masklen input.  This is a little complicated.
	--
	-- If a single address is desired, we always use a /32 or /128
	-- in the parent loop and everything else is ignored
	--
	-- Otherwise, if netmask_bits is passed, that wins, otherwise
	-- the netmask of whatever is passed with desired_ip_address wins
	--
	-- If none of these are the case, then things are wrong and we
	-- bail
	--

	IF NOT single_address THEN
		IF desired_ip_address IS NOT NULL AND netmask_bits IS NULL THEN
			netmask_bits := masklen(desired_ip_address);
		ELSIF desired_ip_address IS NOT NULL AND
				netmask_bits IS NOT NULL THEN
			desired_ip_address := set_masklen(desired_ip_address,
				netmask_bits);
		END IF;
		IF netmask_bits IS NULL THEN
			RAISE EXCEPTION 'netmask_bits must be set'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF allocation_method = 'random' THEN
			RAISE EXCEPTION 'random netblocks may only be returned for single addresses'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		rnd_matches := 0;
		--
		-- Restore this, because we may have overrridden it for a previous
		-- block
		--
		allocation_method = saved_method;
		SELECT
			* INTO netblock_rec
		FROM
			jazzhands.netblock n
		WHERE
			n.netblock_id = parent_nbid;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Netblock % does not exist', parent_nbid;
		END IF;

		family_bits :=
			(CASE family(netblock_rec.ip_address) WHEN 4 THEN 32 ELSE 128 END);

		-- If desired_ip_address is passed, then allocation_method is
		-- irrelevant

		IF desired_ip_address IS NOT NULL THEN
			--
			-- If the IP address is not the same family as the parent block,
			-- we aren't going to find it
			--
			IF family(desired_ip_address) !=
					family(netblock_rec.ip_address) THEN
				CONTINUE;
			END IF;
			allocation_method := 'bottom';
		END IF;

		--
		-- If allocation_method is 'default' or NULL, then use 'bottom'
		-- unless it's for a single IPv6 address in a netblock larger than
		-- rnd_masklen_threshold
		--
		IF allocation_method IS NULL OR allocation_method = 'default' THEN
			allocation_method :=
				CASE WHEN
					single_address AND
					family(netblock_rec.ip_address) = 6 AND
					masklen(netblock_rec.ip_address) <= rnd_masklen_threshold
				THEN
					'random'
				ELSE
					'bottom'
				END;
		END IF;

		IF allocation_method = 'random' AND
				family_bits - masklen(netblock_rec.ip_address) < 2 THEN
			-- Random allocation doesn't work if we don't have enough
			-- bits to play with, so just do sequential.
			allocation_method := 'bottom';
		END IF;

		IF single_address THEN
			netmask_bits := family_bits;
			IF desired_ip_address IS NOT NULL THEN
				desired_ip_address := set_masklen(desired_ip_address,
					masklen(netblock_rec.ip_address));
			END IF;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			-- If the netmask is not for a smaller netblock than this parent,
			-- then bounce to the next one, because maybe it's larger
			RAISE DEBUG
				'netblock (%) is not larger than netmask_bits of % - skipping',
				masklen(netblock_rec.ip_address),
				netmask_bits;
			CONTINUE;
		END IF;

		IF netmask_bits > family_bits THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		--
		-- Short circuit the check if we're looking for a specific address
		-- and it's not in this netblock
		--

		IF desired_ip_address IS NOT NULL AND
				NOT (desired_ip_address <<= netblock_rec.ip_address) THEN
			RAISE DEBUG 'desired_ip_address % is not in netblock %',
				desired_ip_address,
				netblock_rec.ip_address;
			CONTINUE;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		RAISE DEBUG 'Searching netblock % (%) using the % allocation method',
			netblock_rec.netblock_id,
			netblock_rec.ip_address,
			allocation_method;

		IF desired_ip_address IS NOT NULL THEN
			min_ip := desired_ip_address;
			max_ip := desired_ip_address + 1;
		ELSE
			min_ip := netblock_rec.ip_address;
			max_ip := broadcast(min_ip) + 1;
		END IF;

		IF allocation_method = 'top' THEN
			current_ip := network(set_masklen(max_ip - 1, netmask_bits));
		ELSIF allocation_method = 'random' THEN
			max_rnd_value := (x'7fffffffffffffff'::bigint >> CASE
				WHEN family_bits - masklen(netblock_rec.ip_address) >= 63
				THEN 0
				ELSE 63 - (family_bits - masklen(netblock_rec.ip_address))
				END) - 2;
			-- random() appears to only do 32-bits, which is dumb
			-- I'm pretty sure that all of the casts are not required here,
			-- but better to make sure
			current_ip := min_ip +
					((((random() * x'7fffffff'::bigint)::bigint << 32) +
					(random() * x'ffffffff'::bigint)::bigint + 1)
					% max_rnd_value) + 1;
		ELSE -- it's 'bottom'
			current_ip := set_masklen(min_ip, netmask_bits);
		END IF;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses
		-- We shouldn't need to skip for IPv6 addresses, but some things
		-- apparently suck

		IF single_address THEN
			current_ip := set_masklen(current_ip,
				masklen(netblock_rec.ip_address));
			--
			-- If we're not allocating a single /31 or /32 for IPv4 or
			-- /127 or /128 for IPv6, then we want to skip the all-zeros
			-- and all-ones addresses
			--
			IF masklen(netblock_rec.ip_address) < (family_bits - 1) AND
					desired_ip_address IS NULL THEN
				current_ip := current_ip +
					CASE WHEN allocation_method = 'top' THEN -1 ELSE 1 END;
				min_ip := min_ip + 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step masklen of %',
			current_ip,
			netmask_bits;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses AND
				rnd_matches < rnd_max_count
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			IF single_address THEN
				--
				-- Check to see if netblock is in a network_range, and if it is,
				-- then set the value to the top or bottom of the range, or
				-- another random value as appropriate
				--
				SELECT
					network_range_id,
					start_nb.ip_address AS start_ip_address,
					stop_nb.ip_address AS stop_ip_address
				INTO netrange_rec
				FROM
					jazzhands.network_range nr,
					jazzhands.netblock start_nb,
					jazzhands.netblock stop_nb
				WHERE
					family(current_ip) = family(start_nb.ip_address) AND
					family(current_ip) = family(stop_nb.ip_address) AND
					(
						nr.start_netblock_id = start_nb.netblock_id AND
						nr.stop_netblock_id = stop_nb.netblock_id AND
						nr.parent_netblock_id = netblock_rec.netblock_id AND
						start_nb.ip_address <=
							set_masklen(current_ip, masklen(start_nb.ip_address))
						AND stop_nb.ip_address >=
							set_masklen(current_ip, masklen(stop_nb.ip_address))
					);

				IF FOUND THEN
					current_ip := CASE
						WHEN allocation_method = 'bottom' THEN
							netrange_rec.stop_ip_address + 1
						WHEN allocation_method = 'top' THEN
							netrange_rec.start_ip_address - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32)
							+
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1
					END;
					CONTINUE;
				END IF;
			END IF;


			PERFORM * FROM jazzhands.netblock n WHERE
				n.ip_universe_id = netblock_rec.ip_universe_id AND
				n.netblock_type = netblock_rec.netblock_type AND
				-- A block with the parent either contains or is contained
				-- by this block
				n.parent_netblock_id = netblock_rec.netblock_id AND
				CASE WHEN single_address THEN
					n.ip_address = current_ip
				ELSE
					(n.ip_address >>= current_ip OR current_ip >>= n.ip_address)
				END;
			IF NOT FOUND AND (inet_list IS NULL OR
					NOT (current_ip = ANY(inet_list))) THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				inet_list := array_append(inet_list, current_ip);
				matches := matches + 1;
				-- Reset random counter if we found something
				rnd_matches := 0;
			ELSIF allocation_method = 'random' THEN
				-- Increase random counter if we didn't find something
				rnd_matches := rnd_matches + 1;
			END IF;

			-- Select the next IP address
			current_ip :=
				CASE WHEN single_address THEN
					CASE
						WHEN allocation_method = 'bottom' THEN current_ip + 1
						WHEN allocation_method = 'top' THEN current_ip - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32)
							+
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1
					END
				ELSE
					CASE WHEN allocation_method = 'bottom' THEN
						network(broadcast(current_ip) + 1)
					ELSE
						network(current_ip - 1)
					END
				END;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_rvs_zone_from_netblock_id');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_rvs_zone_from_netblock_id ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_rvs_zone_from_netblock_id(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	v_rv	jazzhands.dns_domain.dns_domain_id%type;
	v_domid	jazzhands.dns_domain.dns_domain_id%type;
	v_lhsip	jazzhands.netblock.ip_address%type;
	v_rhsip	jazzhands.netblock.ip_address%type;
	nb_match CURSOR ( in_nb_id jazzhands.netblock.netblock_id%type) FOR
		select  rootd.dns_domain_id,
				 network(set_masklen(nb.ip_address, masklen(root.ip_address))),
				 network(root.ip_address)
		  from  jazzhands.netblock nb,
			jazzhands.netblock root
				inner join jazzhands.dns_record rootd
					on rootd.netblock_id = root.netblock_id
					and rootd.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		 where
		  	nb.netblock_id = in_nb_id;
BEGIN
	v_rv := NULL;
	OPEN nb_match(in_netblock_id);
	LOOP
		FETCH  nb_match INTO v_domid, v_lhsip, v_rhsip;
		if NOT FOUND THEN
			EXIT;
		END IF;

		if v_lhsip = v_rhsip THEN
			v_rv := v_domid;
			EXIT;
		END IF;
	END LOOP;
	CLOSE nb_match;
	return v_rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'list_unallocated_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.list_unallocated_netblocks ( netblock_id integer, ip_address inet, ip_universe_id integer, netblock_type text );
CREATE OR REPLACE FUNCTION netblock_utils.list_unallocated_netblocks(netblock_id integer DEFAULT NULL::integer, ip_address inet DEFAULT NULL::inet, ip_universe_id integer DEFAULT 0, netblock_type text DEFAULT 'default'::text)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	ip_array		inet[];
	netblock_rec	RECORD;
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	family_bits		integer;
	idx				integer;
	subnettable		boolean;
BEGIN
	subnettable := true;
	IF netblock_id IS NOT NULL THEN
		SELECT * INTO netblock_rec FROM jazzhands.netblock n WHERE n.netblock_id =
			list_unallocated_netblocks.netblock_id;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'netblock_id % not found', netblock_id;
		END IF;
		IF netblock_rec.is_single_address = 'Y' THEN
			RETURN;
		END IF;
		ip_address := netblock_rec.ip_address;
		ip_universe_id := netblock_rec.ip_universe_id;
		netblock_type := netblock_rec.netblock_type;
		subnettable := CASE WHEN netblock_rec.can_subnet = 'N'
			THEN false ELSE true
			END;
	ELSIF ip_address IS NOT NULL THEN
		ip_universe_id := 0;
		netblock_type := 'default';
	ELSE
		RAISE EXCEPTION 'netblock_id or ip_address must be passed';
	END IF;
	IF (subnettable) THEN
		SELECT ARRAY(
			SELECT
				n.ip_address
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type AND
				is_single_address = 'N' AND
				can_subnet = 'N'
			ORDER BY
				n.ip_address
		) INTO ip_array;
	ELSE
		SELECT ARRAY(
			SELECT
				set_masklen(n.ip_address,
					CASE WHEN family(n.ip_address) = 4 THEN 32
					ELSE 128
					END)
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_address != list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type
			ORDER BY
				n.ip_address
		) INTO ip_array;
	END IF;

	IF array_length(ip_array, 1) IS NULL THEN
		ip_addr := ip_address;
		RETURN NEXT;
		RETURN;
	END IF;

	ip_array := array_prepend(
		list_unallocated_netblocks.ip_address - 1,
		array_append(
			ip_array,
			broadcast(list_unallocated_netblocks.ip_address) + 1
			));

	idx := 1;
	WHILE idx < array_length(ip_array, 1) LOOP
		RETURN QUERY SELECT cin.ip_addr FROM
			netblock_utils.calculate_intermediate_netblocks(ip_array[idx], ip_array[idx + 1]) cin;
		idx := idx + 1;
	END LOOP;

	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'recalculate_parentage');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.recalculate_parentage ( in_netblock_id integer );
CREATE OR REPLACE FUNCTION netblock_utils.recalculate_parentage(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		jazzhands.netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE
		netblock_id = in_netblock_id;

	nbid := netblock_utils.find_best_parent_id(in_netblock_id);

	UPDATE jazzhands.netblock SET parent_netblock_id = nbid
		WHERE netblock_id = in_netblock_id;

	FOR childrec IN SELECT * FROM jazzhands.netblock WHERE
		parent_netblock_id = nbid
		AND netblock_id != in_netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE jazzhands.netblock SET parent_netblock_id = in_netblock_id
				WHERE netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$function$
;

--
-- Process drops in rack_utils
--
--
-- Process drops in schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table_other_indexes');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table_other_indexes ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table_other_indexes(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r	RECORD;
	sch	TEXT;
BEGIN
	-- one day, I will want to construct the list of columns by hand rather
	-- than use pg_get_constraintdef.  watch me...

	sch := quote_ident( aud_schema );
	FOR _r IN
		SELECT c2.relname, pg_get_indexdef(i.indexrelid) as def, con.contype
	FROM pg_catalog.pg_class c
	    INNER JOIN pg_namespace n
		ON relnamespace = n.oid
	    INNER JOIN pg_catalog.pg_index i
		ON c.oid = i.indrelid
	    INNER JOIN pg_catalog.pg_class c2
		ON i.indexrelid = c2.oid
	   LEFT JOIN pg_catalog.pg_constraint con ON
		(con.conrelid = i.indrelid
		AND con.conindid = i.indexrelid )
	WHERE c.relname =  table_name
	AND      n.nspname = tbl_schema
	AND	con.contype IS NULL

	LOOP
		_r.def := regexp_replace(_r.def, ' ON ', ' ON ' || sch || '.');
		EXECUTE _r.def;
	END LOOP;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_columns ( _schema text, _table text );
CREATE OR REPLACE FUNCTION schema_support.get_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			record;
BEGIN
	FOR _r IN SELECT  a.attname as colname,
	    pg_catalog.format_type(a.atttypid, a.atttypmod) as coltype,
	    a.attnotnull, a.attnum
	FROM    pg_catalog.pg_attribute a
				INNER JOIN pg_class c on a.attrelid = c.oid
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
	WHERE   c.relname = _table
		  AND	n.nspname = _schema
	  AND   a.attnum > 0
	  AND   NOT a.attisdropped
		  AND	lower(a.attname) not like 'data_%'
	ORDER BY a.attnum
	LOOP
		SELECT array_append(cols, _r.colname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols	text[];
BEGIN
    _q := 'WITH cols AS (
	SELECT  n.nspname as schema, c.relname as relation, a.attname as colname, t.typoutput as type,
		a.attnum
	    FROM    pg_catalog.pg_attribute a
		INNER JOIN pg_catalog.pg_class c
		    ON a.attrelid = c.oid
		INNER JOIN pg_catalog.pg_namespace n
		    ON c.relnamespace = n.oid
				INNER JOIN pg_catalog.pg_type t
					ON  t.oid = a.atttypid
	    WHERE   a.attnum > 0
	    AND   NOT a.attisdropped
	    ORDER BY a.attnum
       ) SELECT array_agg(colname ORDER BY attnum) as cols
	FROM ( SELECT CASE WHEN ( o.type::text ~ ''enum'' OR n.type::text ~ ''enum'')  AND o.type != n.type THEN concat(quote_ident(n.colname), ''::text'')
					ELSE quote_ident(n.colname)
					END  AS colname,
				o.attnum
			FROM cols  o
	    INNER JOIN cols n USING (schema, colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.relation = $3
		) as prett
	';
	EXECUTE _q INTO cols USING _schema, _table1, _table2;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_pk_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_pk_columns ( _schema text, _table text );
CREATE OR REPLACE FUNCTION schema_support.get_pk_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			RECORD;
BEGIN
	for _r IN SELECT a.attname
			FROM pg_class c
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
				INNER JOIN pg_index i ON i.indrelid = c.oid
				INNER JOIN pg_attribute  a ON   a.attrelid = c.oid AND
								a.attnum = any(i.indkey)
			WHERE	c.relname = _table
			AND		n.nspname = _schema
			AND		indisprimary
	LOOP
		SELECT array_append(cols, _r.attname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_t1		integer;
	_t2		integer;
	_cnt	integer;
	_cols	TEXT[];
	_pkcol	TEXT[];
	_q		TEXT;
	_f		TEXT;
	_c		RECORD;
	_w		TEXT[];
	_ctl		TEXT[];
	_rv	boolean;
	_oj		jsonb;
	_nj		jsonb;
BEGIN
	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, new_rel;
		_rv := false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(schema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(schema, old_rel, new_rel);

	_ctl := NULL;
	FOREACH _f IN ARRAY prikeys
	LOOP
		SELECT array_append(_ctl, quote_ident(_f) ) INTO _ctl;
	END LOOP;
	_pkcol := _ctl;

	--
	-- Number of rows mismatch.  Show the missing rows based on the
	-- primary key.
	--
	IF _t1 != _t2 THEN
		RAISE NOTICE 'table % has % rows; table % has % rows (%)', old_rel, _t1, new_rel, _t2, _t1 - _t2;
		_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel)  ||
			' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' EXCEPT ( '
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' )) ';

		_cnt := 0;
		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE 'InOld/%: %', _cnt, _r;
			_cnt := _cnt + 1;
		END LOOP;

		_q := 'SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel)  ||
			' WHERE (' || array_to_string(_pkcol,',') || ') IN ( ' ||
				' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel)  ||
				' EXCEPT ( '
					' SELECT ' || array_to_string(_pkcol,',') || ' FROM ' ||
					quote_ident(schema) || '.' || quote_ident(old_rel)  ||
				' )) ';

		_cnt := 0;
		FOR _r IN EXECUTE 'SELECT row_to_json(x) as r FROM (' || _q || ') x'
		LOOP
			RAISE NOTICE 'InNew/%: %', _cnt, _r;
			_cnt := _cnt + 1;
		END LOOP;

		_rv := false;
	END IF;

	IF NOT _rv THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Relations do not match';
		END IF;
		RETURN false;
	END IF;

	-- At this point, the same number of rows appear in both, so need to
	-- figure out rows that are different between them.


	-- SELECT row_to_json(o) as old, row_to_json(n) as new
	-- FROM ( SELECT cols FROM old WHERE prikeys in Vv ) old,
	-- JOIN ( SELECT cols FROM new WHERE prikeys in Vv ) new
	-- USING (prikeys);
	-- WHERE (prikeys) IN
	-- ( SELECT  prikeys FROM (
	--		( SELECT cols FROM old EXCEPT ( SELECT cols FROM new ) )
	-- ))

	_q := ' SELECT row_to_json(old) as old, row_to_json(new) as new FROM ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(old_rel) || ' ) old ' ||
		' JOIN ' ||
		'( SELECT '  || array_to_string(_cols,',') || ' FROM ' ||
			quote_ident(schema) || '.' || quote_ident(new_rel) || ' ) new ' ||
		' USING ( ' ||  array_to_string(_pkcol,',') ||
		' ) WHERE (' || array_to_string(_pkcol,',') || ' ) IN (' ||
		'SELECT ' || array_to_string(_pkcol,',')  || ' FROM ( ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(old_rel) ||
			' EXCEPT ' ||
			'( SELECT ' || array_to_string(_cols,',') || ' FROM ' ||
				quote_ident(schema) || '.' || quote_ident(new_rel) || ' )) ' ||
		' ) subq) ORDER BY ' || array_to_string(_pkcol,',')
	;

	_t1 := 0;
	FOR _r IN EXECUTE _q
	LOOP
		_t1 := _t1 + 1;
		FOR _f IN SELECT json_object_keys(_r.new)
		LOOP
			IF _f = ANY ( prikeys ) OR _r.old->>_f IS DISTINCT FROM _r.new->>_f
			THEN
				IF _oj IS NULL THEN
					_oj := jsonb_build_object(_f, _r.old->>_f);
					_nj := jsonb_build_object(_f, _r.new->>_f);
				ELSE
					_oj := _oj || jsonb_build_object(_f, _r.old->>_f);
					_nj := _nj || jsonb_build_object(_f, _r.new->>_f);
				END IF;
			END IF;
		END LOOP;
		RAISE NOTICE 'mismatched row:';
		RAISE NOTICE 'OLD: %', _oj;
		RAISE NOTICE 'NEW: %', _nj;
		_rv := false;
	END LOOP;

	IF NOT _rv AND raise_exception THEN
		RAISE EXCEPTION 'Relations do not match (% rows)', _t1;
	ELSE
		RAISE NOTICE '% rows mismatch', _t1;
	END IF;
	return _rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_last_changed');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_last_changed ( relation text, schema text, debug boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	audsch	text;
	rk	char;
	rv	timestamp;
	ts	timestamp;
	obj	text;
	objaud text;
	objkind text;
	objschema text;
BEGIN
	SELECT	audit_schema
	INTO	audsch
	FROM	schema_support.schema_audit_map m
	WHERE	m.schema = relation_last_changed.schema;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Schema % not configured for this', schema;
	END IF;

	SELECT	relkind
	INTO	rk
	FROM	pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE	n.nspname = relation_last_changed.schema
	AND	c.relname = relation_last_changed.relation;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'No such object %.%', schema, relation;
	END IF;

	IF rk = 'r' THEN
		EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
			FROM '||quote_ident(audsch)||'.'|| quote_ident(relation)
		INTO rv;
		IF rv IS NULL THEN
			EXECUTE '
				SELECT	max("aud#timestamp")
				FROM	'||quote_ident(audsch)||'.'||quote_ident(relation)
			INTO rv;
		END IF;

		IF rv IS NULL THEN
			RETURN '-infinity'::timestamp;
		ELSE
			RETURN rv;
		END IF;
	END IF;

	IF rk = 'v' OR rk = 'm' THEN
		FOR obj,objaud,objkind, objschema IN WITH RECURSIVE recur AS (
		SELECT distinct rewrite.ev_class as root_oid, d.refobjid as oid
		FROM pg_depend d
		    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
		    JOIN pg_class c on rewrite.ev_class = c.oid
		    JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE c.relname = relation
		AND n.nspname = relation_last_changed.schema
		AND d.refobjsubid > 0
	    UNION ALL
		SELECT recur.root_oid, d.refobjid as oid
		FROM pg_depend d
		    JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
		    JOIN pg_class c on rewrite.ev_class = c.oid
		JOIN recur ON recur.oid = rewrite.ev_class
		AND d.refobjsubid > 0
		AND c.relkind != 'm'
	    ), list AS ( select distinct m.audit_schema, c.relname, c.relkind, n.nspname as relschema, recur.*
		FROM pg_class c
		    JOIN recur on recur.oid = c.oid
		    JOIN pg_namespace n on c.relnamespace = n.oid
		    JOIN schema_support.schema_audit_map m
			ON m.schema = n.nspname
		WHERE relkind IN ('r', 'm')
		) SELECT relname, audit_schema, relkind, relschema from list
		LOOP
			-- if there is no audit table, assume its kept current.  This is
			-- likely some sort of cache table.  XXX - should probably be
			-- updated to use the materialized view update bits
			BEGIN
				IF objkind = 'r' THEN
					EXECUTE 'SELECT max(pg_xact_commit_timestamp(xmin))
						FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) ||'
						WHERE "aud#timestamp" > (
								SELECT max("aud#timestamp")
								FROM '||quote_ident(objaud)||'.'|| quote_ident(obj) || '
							) - ''10 day''::interval'
						INTO ts;
					IF ts IS NULL THEN
						EXECUTE 'SELECT max("aud#timestamp")
							FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
							INTO ts;
					END IF;
				ELSIF objkind = 'm' THEN
					SELECT refresh INTO ts FROM schema_support.mv_refresh m WHERE m.schema = objschema
						AND m.view = obj;
				ELSE
					RAISE NOTICE 'Unknown object kind % for %.%', objkind, objaud, obj;
				END IF;
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): %.% -> %', objaud, obj, ts;
				END IF;
				IF rv IS NULL OR ts > rv THEN
					rv := ts;
				END IF;
			EXCEPTION WHEN undefined_table THEN
				IF debug THEN
					RAISE NOTICE 'schema_support.relation_last_changed(): skipping %.%', schema, obj;
				END IF;
			END;
		END LOOP;
		RETURN rv;
	END IF;

	RAISE EXCEPTION 'Unable to process relkind %', rk;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'reset_table_sequence');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.reset_table_sequence ( schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence(schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r	RECORD;
	m	BIGINT;
BEGIN
	FOR _r IN
		WITH s AS (
			SELECT	pg_get_serial_sequence(schema||'.'||table_name,
				a.attname) as seq, a.attname as column
			FROM	pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE	c.relname = table_name
			AND	n.nspname = schema
				AND	a.attnum > 0
				AND	NOT a.attisdropped
		) SELECT s.*, nextval(s.seq) as nv FROM s WHERE seq IS NOT NULL
	LOOP
		EXECUTE 'SELECT max('||quote_ident(_r.column)||')+1 FROM  '
			|| quote_ident(schema)||'.'||quote_ident(table_name)
			INTO m;
		IF m IS NOT NULL THEN
			IF _r.nv > m THEN
				m := _r.nv;
			END IF;
			EXECUTE 'ALTER SEQUENCE ' || _r.seq || ' RESTART WITH '
				|| m;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_constraint_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in	SELECT n.nspname, c.relname, con.conname,
				pg_get_constraintdef(con.oid, true) as def
		FROM pg_constraint con
			INNER JOIN pg_class c on (c.relnamespace, c.oid) =
				(con.connamespace, con.conrelid)
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE con.confrelid in (
			select c.oid
			from pg_class c
				inner join pg_namespace n on n.oid = c.relnamespace
			WHERE c.relname = object
			AND n.nspname = schema
		) AND n.nspname != schema
	LOOP
		_ddl := 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
			' ADD CONSTRAINT ' || _r.conname || ' ' || _r.def;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define constraint for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'constraint', _ddl
			);
		IF dropit  THEN
			_cmd = 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
				' DROP CONSTRAINT ' || _r.conname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	-- process stored procedures
	FOR _r in SELECT  distinct np.nspname::text, dependent.proname::text
		FROM   pg_depend dep
			INNER join pg_type dependee on dependee.oid = dep.refobjid
			INNER join pg_namespace n on n.oid = dependee.typnamespace
			INNER join pg_proc dependent on dependent.oid = dep.objid
			INNER join pg_namespace np on np.oid = dependent.pronamespace
			WHERE   dependee.typname = object
			  AND	  n.nspname = schema
	LOOP
		-- RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.proname;
		PERFORM schema_support.save_constraint_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit);
	END LOOP;

	-- save any triggers on the view
	FOR _r in SELECT distinct n.nspname::text, dependee.relname::text, dependee.relkind
		FROM pg_depend
		JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
		JOIN pg_class as dependee ON pg_rewrite.ev_class = dependee.oid
		JOIN pg_class as dependent ON pg_depend.refobjid = dependent.oid
		JOIN pg_namespace n on n.oid = dependee.relnamespace
		JOIN pg_namespace sn on sn.oid = dependent.relnamespace
		JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
			AND pg_depend.refobjsubid = pg_attribute.attnum
		WHERE dependent.relname = object
		AND sn.nspname = schema
	LOOP
		IF _r.relkind = 'v' OR _r.relkind = 'm' THEN
			-- RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
		PERFORM schema_support.save_constraint_for_replay('jazzhands', 'table');
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_relations');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_relations ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object	varchar;
	_tabs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_fullgrant		varchar;
	_role		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();

	-- Handle table wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			c.relacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

	-- Handle column specific wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			a.attname as col,
			a.attacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
		ON a.attrelid = c.oid
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND a.attacl IS NOT NULL
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || '(' || _tabs.col || ')'
				' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.migrate_grants(username text, direction text, old_schema text DEFAULT 'jazzhands'::text, new_schema text DEFAULT 'jazzhands_legacy'::text)
 RETURNS text[]
 LANGUAGE plpgsql
 SET search_path TO 'schema_support'
AS $function$
DECLARE
	_rv	TEXT[];
	_r	RECORD;
	_q	TEXT;
BEGIN
	IF lower(direction) NOT IN ('grant','revoke') THEN
		RAISE EXCEPTION 'direction must be grant or revoke';
	END IF;

	FOR _r IN
		WITH x AS (
		SELECT *
			FROM (
		SELECT oid, schema, name,  typ,
			p->>'privilege_type' as privilege_type,
			col,
			r.usename as grantor, e.usename as grantee,
			r.usesysid as rid,  e.usesysid as eid,
			e.useconfig
		FROM (
			SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'm' THEN 'view'
				WHEN 'v' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
				NULL::text as col,
			to_jsonb(pg_catalog.aclexplode(acl := c.relacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
		UNION ALL
		SELECT  c.oid, n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'mv' THEN 'mview'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as typ,
			a.attname as col,
			to_jsonb(pg_catalog.aclexplode(a.attacl)) as p
			FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
				ON a.attrelid = c.oid
			WHERE c.relkind IN ('r', 'v', 'S', 'f')
			AND a.attacl IS NOT NULL
		) x
		LEFT JOIN pg_user r ON r.usesysid = (p->>'grantor')::oid
		LEFT JOIN pg_user e ON e.usesysid = (p->>'grantee')::oid
		) i
		) select *
		FROM x
		WHERE ( schema = old_schema )
		AND grantee = username
		AND typ IN ('table', 'view', 'mview', 'foreign table')
		order by name, col
	LOOP
		IF _r.col IS NOT NULL THEN
			_q = concat(' (', _r.col, ') ');
		ELSE
			_q := NULL;
		END IF;
		IF lower(direction) = 'grant' THEN
			_q := concat('GRANT ', _r.privilege_type, _q, ' ON ', new_schema, '.', _r.name, ' TO ', _r.grantee);
		ELSIF lower(direction) = 'revoke' THEN
			_q := concat('REVOKE ', _r.privilege_type, _q, ' ON ', old_schema, '.', _r.name, ' FROM ', _r.grantee);
		END IF;


		_rv := array_append(_rv, _q);
		EXECUTE _q;
	END LOOP;
	RETURN _rv;
END;
$function$
;

--
-- Process drops in property_utils
--
--
-- Process drops in netblock_manip
--
--
-- Process drops in physical_address_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('physical_address_utils', 'localized_physical_address');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS physical_address_utils.localized_physical_address ( physical_address_id integer, line_separator text, include_country boolean );
CREATE OR REPLACE FUNCTION physical_address_utils.localized_physical_address(physical_address_id integer, line_separator text DEFAULT ', '::text, include_country boolean DEFAULT true)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
DECLARE
	address	text;
BEGIN
	SELECT concat_ws(line_separator,
			CASE WHEN iso_country_code IN 
					('SG', 'US', 'CA', 'UK', 'GB', 'FR', 'AU') THEN 
				concat_ws(' ', address_housename, address_street)
			WHEN iso_country_code IN ('IL') THEN
				concat_ws(', ', address_housename, address_street)
			WHEN iso_country_code IN ('ES') THEN
				concat_ws(', ', address_street, address_housename)
			ELSE
				concat_ws(' ', address_street, address_housename)
			END,
			address_pobox,
			address_building,
			address_neighborhood,
			CASE WHEN iso_country_code IN ('US', 'CA', 'UK') THEN 
				concat_ws(', ', address_city, 
					concat_ws(' ', address_region, postal_code))
			WHEN iso_country_code IN ('SG', 'AU') THEN
				concat_ws(' ', address_city, address_region, postal_code)
			ELSE
				concat_ws(' ', postal_code, address_city, address_region)
			END,
			iso_country_code
		)
	INTO address
	FROM
		physical_address pa
	WHERE
		pa.physical_address_id = 
			localized_physical_address.physical_address_id;
	RETURN address;
END; $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('physical_address_utils', 'localized_street_address');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS physical_address_utils.localized_street_address ( address_housename text, address_street text, address_building text, address_pobox text, iso_country_code text, line_separator text );
CREATE OR REPLACE FUNCTION physical_address_utils.localized_street_address(address_housename text DEFAULT NULL::text, address_street text DEFAULT NULL::text, address_building text DEFAULT NULL::text, address_pobox text DEFAULT NULL::text, iso_country_code text DEFAULT NULL::text, line_separator text DEFAULT ', '::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'jazzhands'
AS $function$
BEGIN
	RETURN concat_ws(line_separator,
			CASE WHEN iso_country_code IN 
					('SG', 'US', 'CA', 'UK', 'GB', 'FR', 'AU') THEN 
				concat_ws(' ', address_housename, address_street)
			WHEN iso_country_code IN ('IL') THEN
				concat_ws(', ', address_housename, address_street)
			WHEN iso_country_code IN ('ES') THEN
				concat_ws(', ', address_street, address_housename)
			ELSE
				concat_ws(' ', address_street, address_housename)
			END,
			address_pobox,
			address_building
		);
END; $function$
;

--
-- Process drops in component_utils
--
--
-- Process drops in snapshot_manip
--
--
-- Process drops in lv_manip
--
--
-- Process drops in approval_utils
--
--
-- Process drops in account_collection_manip
--
--
-- Process drops in script_hooks
--
--
-- Process drops in backend_utils
--
--
-- Process post-schema jazzhands_legacy
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE ip_universe DROP CONSTRAINT IF EXISTS r_815;
ALTER TABLE ip_universe
	ADD CONSTRAINT fk_ip_universe_namespace
	FOREIGN KEY (ip_namespace) REFERENCES jazzhands.val_ip_namespace(ip_namespace);

ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_net_int_lgl_port_id;
ALTER TABLE network_interface
	ADD CONSTRAINT fk_net_int_lgl_port_id
	FOREIGN KEY (logical_port_id, device_id) REFERENCES jazzhands.logical_port(logical_port_id, device_id);

ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS uq_netint_device_id_logical_port_id;
ALTER TABLE network_interface
	ADD CONSTRAINT uq_netint_device_id_logical_port_id
	UNIQUE (device_id, logical_port_id);

-- index
DROP INDEX IF EXISTS "jazzhands"."uq_appaal_name";
CREATE UNIQUE INDEX uq_appaal_name ON jazzhands.appaal USING btree (appaal_name);
DROP INDEX IF EXISTS "jazzhands"."xif3approval_process_chain";
CREATE INDEX xif3approval_process_chain ON jazzhands.approval_process_chain USING btree (accept_app_process_chain_id);
DROP INDEX IF EXISTS "jazzhands"."xif_asset_comp_id";
CREATE INDEX xif_asset_comp_id ON jazzhands.asset USING btree (component_id);
DROP INDEX IF EXISTS "jazzhands"."xif_component_prnt_slt_id";
CREATE INDEX xif_component_prnt_slt_id ON jazzhands.component USING btree (parent_slot_id);
DROP INDEX IF EXISTS "jazzhands"."xif5department";
CREATE UNIQUE INDEX xif5department ON jazzhands.department USING btree (account_collection_id);
DROP INDEX IF EXISTS "jazzhands"."xif_chasloc_chass_devid";
CREATE INDEX xif_chasloc_chass_devid ON jazzhands.device USING btree (chassis_location_id);
DROP INDEX IF EXISTS "jazzhands"."xif_dev_devtp_id";
CREATE INDEX xif_dev_devtp_id ON jazzhands.device USING btree (device_type_id);
DROP INDEX IF EXISTS "jazzhands"."xif_dev_rack_location_id";
CREATE INDEX xif_dev_rack_location_id ON jazzhands.device USING btree (rack_location_id);
DROP INDEX IF EXISTS "jazzhands"."xif_intercomp_conn_slot1_id";
CREATE INDEX xif_intercomp_conn_slot1_id ON jazzhands.inter_component_connection USING btree (slot1_id);
DROP INDEX IF EXISTS "jazzhands"."xif_intercomp_conn_slot2_id";
CREATE INDEX xif_intercomp_conn_slot2_id ON jazzhands.inter_component_connection USING btree (slot2_id);
DROP INDEX IF EXISTS "jazzhands"."xif_layer3_network_netblock_id";
CREATE INDEX xif_layer3_network_netblock_id ON jazzhands.layer3_network USING btree (netblock_id);
DROP INDEX "jazzhands"."xif_net_int_lgl_port_id";
DROP INDEX IF EXISTS "jazzhands"."xif12network_interface";
CREATE INDEX xif12network_interface ON jazzhands.network_interface USING btree (logical_port_id, device_id);
DROP INDEX IF EXISTS "jazzhands"."xif_netint_nb_netint_id";
CREATE UNIQUE INDEX xif_netint_nb_netint_id ON jazzhands.network_interface_netblock USING btree (netblock_id);
DROP INDEX IF EXISTS "jazzhands"."xif2shared_netblock";
CREATE INDEX xif2shared_netblock ON jazzhands.shared_netblock USING btree (netblock_id);
DROP INDEX IF EXISTS "jazzhands"."xifunixgrp_uclass_id";
CREATE UNIQUE INDEX xifunixgrp_uclass_id ON jazzhands.unix_group USING btree (account_collection_id);
-- triggers
DROP TRIGGER IF EXISTS trigger_val_property_value_del_check ON val_property_value;
CREATE CONSTRAINT TRIGGER trigger_val_property_value_del_check AFTER DELETE ON jazzhands.val_property_value DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE jazzhands.val_property_value_del_check();


-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
SELECT schema_support.synchronize_cache_tables();


-- BEGIN Misc that does not apply to above
CREATE INDEX aud_network_interface_uq_netint_device_id_logical_port_id ON audit.network_interface USING btree (device_id, logical_port_id);

ALTER TABLE  logical_port ALTER logical_port_type SET NOT NULL;


-- END Misc that does not apply to above
--
-- BEGIN: process_ancillary_schema(jazzhands_legacy)
--
--------------------------------------------------------------------
-- DEALING WITH TABLE logical_port
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_port', 'logical_port');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'logical_port');
DROP VIEW IF EXISTS jazzhands_legacy.logical_port;
CREATE VIEW jazzhands_legacy.logical_port AS
 SELECT logical_port.logical_port_id,
    logical_port.logical_port_name,
    logical_port.logical_port_type,
    logical_port.device_id,
    logical_port.mlag_peering_id,
    logical_port.parent_logical_port_id,
    logical_port.mac_address,
    logical_port.data_ins_user,
    logical_port.data_ins_date,
    logical_port.data_upd_user,
    logical_port.data_upd_date
   FROM jazzhands.logical_port;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'logical_port';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of logical_port failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE logical_port (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE mlag_peering
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'mlag_peering', 'mlag_peering');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'mlag_peering');
DROP VIEW IF EXISTS jazzhands_legacy.mlag_peering;
CREATE VIEW jazzhands_legacy.mlag_peering AS
 SELECT mlag_peering.mlag_peering_id,
    mlag_peering.device1_id,
    mlag_peering.device2_id,
    mlag_peering.domain_id,
    mlag_peering.system_id,
    mlag_peering.data_ins_user,
    mlag_peering.data_ins_date,
    mlag_peering.data_upd_user,
    mlag_peering.data_upd_date
   FROM jazzhands.mlag_peering;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'mlag_peering';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of mlag_peering failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE mlag_peering (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_person_status
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_status', 'val_person_status');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'val_person_status');
DROP VIEW IF EXISTS jazzhands_legacy.val_person_status;
CREATE VIEW jazzhands_legacy.val_person_status AS
 SELECT val_person_status.person_status,
    val_person_status.description,
    val_person_status.is_enabled,
    val_person_status.propagate_from_person,
    val_person_status.is_forced,
    val_person_status.is_db_enforced,
    val_person_status.data_ins_user,
    val_person_status.data_ins_date,
    val_person_status.data_upd_user,
    val_person_status.data_upd_date
   FROM jazzhands.val_person_status;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'val_person_status';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of val_person_status failed but that is ok';
				NULL;
			END;
$$;

-- just in case
SELECT schema_support.prepare_for_object_replay();
ALTER TABLE jazzhands_legacy.val_person_status
	ALTER is_forced
	SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_person_status
	ALTER is_db_enforced
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE val_person_status (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_collection_hier_from_ancestor (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_account_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands_legacy.v_account_collection_hier_from_ancestor;
CREATE VIEW jazzhands_legacy.v_account_collection_hier_from_ancestor AS
 SELECT v_account_collection_hier_from_ancestor.root_account_collection_id,
    v_account_collection_hier_from_ancestor.intermediate_account_collection_id,
    v_account_collection_hier_from_ancestor.account_collection_id,
    v_account_collection_hier_from_ancestor.path,
    v_account_collection_hier_from_ancestor.cycle
   FROM jazzhands.v_account_collection_hier_from_ancestor;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_account_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_collection_hier_from_ancestor (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_name (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_account_name');
DROP VIEW IF EXISTS jazzhands_legacy.v_account_name;
CREATE VIEW jazzhands_legacy.v_account_name AS
 SELECT v_account_name.account_id,
    v_account_name.first_name,
    v_account_name.last_name,
    v_account_name.display_name
   FROM jazzhands.v_account_name;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_account_name';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_account_name failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_account_name (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_collection_hier_from_ancestor (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_device_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands_legacy.v_device_collection_hier_from_ancestor;
CREATE VIEW jazzhands_legacy.v_device_collection_hier_from_ancestor AS
 SELECT v_device_collection_hier_from_ancestor.root_device_collection_id,
    v_device_collection_hier_from_ancestor.intermediate_device_collection_id,
    v_device_collection_hier_from_ancestor.device_collection_id,
    v_device_collection_hier_from_ancestor.path,
    v_device_collection_hier_from_ancestor.cycle
   FROM jazzhands.v_device_collection_hier_from_ancestor;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_device_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_device_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_device_collection_hier_from_ancestor (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_collection_hier_from_ancestor (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_netblock_collection_hier_from_ancestor');
DROP VIEW IF EXISTS jazzhands_legacy.v_netblock_collection_hier_from_ancestor;
CREATE VIEW jazzhands_legacy.v_netblock_collection_hier_from_ancestor AS
 SELECT v_netblock_collection_hier_from_ancestor.root_netblock_collection_id,
    v_netblock_collection_hier_from_ancestor.intermediate_netblock_collection_id,
    v_netblock_collection_hier_from_ancestor.netblock_collection_id,
    v_netblock_collection_hier_from_ancestor.path,
    v_netblock_collection_hier_from_ancestor.cycle
   FROM jazzhands.v_netblock_collection_hier_from_ancestor;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_netblock_collection_hier_from_ancestor';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_collection_hier_from_ancestor failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_collection_hier_from_ancestor (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_netblock_hier_expanded (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_netblock_hier_expanded');
DROP VIEW IF EXISTS jazzhands_legacy.v_netblock_hier_expanded;
CREATE VIEW jazzhands_legacy.v_netblock_hier_expanded AS
 SELECT v_netblock_hier_expanded.netblock_level,
    v_netblock_hier_expanded.root_netblock_id,
    v_netblock_hier_expanded.site_code,
    v_netblock_hier_expanded.path,
    v_netblock_hier_expanded.netblock_id,
    v_netblock_hier_expanded.ip_address,
    v_netblock_hier_expanded.netblock_type,
    v_netblock_hier_expanded.is_single_address,
    v_netblock_hier_expanded.can_subnet,
    v_netblock_hier_expanded.parent_netblock_id,
    v_netblock_hier_expanded.netblock_status,
    v_netblock_hier_expanded.ip_universe_id,
    v_netblock_hier_expanded.description,
    v_netblock_hier_expanded.external_id,
    v_netblock_hier_expanded.data_ins_user,
    v_netblock_hier_expanded.data_ins_date,
    v_netblock_hier_expanded.data_upd_user,
    v_netblock_hier_expanded.data_upd_date
   FROM jazzhands.v_netblock_hier_expanded;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_netblock_hier_expanded';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_netblock_hier_expanded failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_netblock_hier_expanded (jazzhands_legacy)
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_site_netblock_expanded_assigned (jazzhands_legacy)
SELECT schema_support.save_dependent_objects_for_replay('jazzhands_legacy', 'v_site_netblock_expanded_assigned');
DROP VIEW IF EXISTS jazzhands_legacy.v_site_netblock_expanded_assigned;
CREATE VIEW jazzhands_legacy.v_site_netblock_expanded_assigned AS
 SELECT v_site_netblock_expanded_assigned.site_code,
    v_site_netblock_expanded_assigned.netblock_id
   FROM jazzhands.v_site_netblock_expanded_assigned;

DO $$

			BEGIN
				DELETE FROM __recreate WHERE schema = 'jazzhands_legacy' AND type = 'view' AND object = 'v_site_netblock_expanded_assigned';
			EXCEPTION WHEN undefined_table THEN
				RAISE NOTICE 'Drop of v_site_netblock_expanded_assigned failed but that is ok';
				NULL;
			END;
$$;


-- PRIMARY AND ALTERNATE KEYS

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
-- SELECT schema_support.replay_object_recreates();
-- DONE DEALING WITH TABLE v_site_netblock_expanded_assigned (jazzhands_legacy)
--------------------------------------------------------------------
-- DONE: process_ancillary_schema(jazzhands_legacy)
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
SELECT schema_support.end_maintenance();
--
-- BEGIN: Fix cache table entries.
--
-- removing old
-- adding new cache tables that are not there
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  WHERE ('jazzhands_cache' , 'ct_device_components' , 'jazzhands_cache' , 'v_device_components' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_hier' , 'jazzhands_cache' , 'v_netblock_hier' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_account_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_account_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_account_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_account_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_device_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_device_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_device_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_device_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
INSERT INTO schema_support.cache_table (cache_table_schema, cache_table, defining_view_schema, defining_view, updates_enabled 
	) SELECT 'jazzhands_cache' , 'ct_netblock_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_netblock_collection_hier_from_ancestor' , '1'  WHERE ('jazzhands_cache' , 'ct_netblock_collection_hier_from_ancestor' , 'jazzhands_cache' , 'v_netblock_collection_hier_from_ancestor' , '1'  ) NOT IN ( SELECT * FROM schema_support.cache_table );
--
-- DONE: Fix cache table entries.
--
select timeofday(), now();
