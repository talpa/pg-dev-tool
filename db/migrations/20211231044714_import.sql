-- migrate:up
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: data_mgmt; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA data_mgmt;


--
-- Name: sdm; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sdm;


--
-- Name: en_natural; Type: COLLATION; Schema: sdm; Owner: -
--

CREATE COLLATION sdm.en_natural (provider = icu, locale = 'en-US-u-kn-true');


--
-- Name: apply_for; Type: DOMAIN; Schema: sdm; Owner: -
--

CREATE DOMAIN sdm.apply_for AS text
	CONSTRAINT apply_for_check CHECK ((VALUE = ANY (ARRAY['none'::text, 'all'::text, 'batch_only'::text, 'selective_only'::text])));


--
-- Name: global_dependency; Type: TYPE; Schema: sdm; Owner: -
--

CREATE TYPE sdm.global_dependency AS (
	master_global_id text,
	child_global_ids text[]
);


--
-- Name: t_check_compatibility; Type: TYPE; Schema: sdm; Owner: -
--

CREATE TYPE sdm.t_check_compatibility AS (
	global_id text,
	version text
);


--
-- Name: t_check_flag; Type: TYPE; Schema: sdm; Owner: -
--

CREATE TYPE sdm.t_check_flag AS ENUM (
    'check_all',
    'check_tested_only'
);


--
-- Name: f_bundle_clean(text); Type: PROCEDURE; Schema: data_mgmt; Owner: -
--

CREATE PROCEDURE data_mgmt.f_bundle_clean(p_global_id text)
    LANGUAGE plpgsql
    AS $$
	declare
		v_id_bundle integer;
	begin

		select b.id into v_id_bundle from sdm.bundle b where b.global_id = p_global_id;
		if not found then
			raise notice 'Bundle record ''%'' does not exist in the database, nothing to clean.', p_global_id;
			return;
		end if;

		delete from sdm.bundle_version
		where bundle_id = v_id_bundle;

		delete from sdm.software_bundle
		where bundle_id = v_id_bundle;

		delete from sdm.bundle
		where id = v_id_bundle;

		raise notice 'Bundle record ''%'' and all dependent records have been deleted.', p_global_id;

	end;
$$;


--
-- Name: f_bundle_create(text, text, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_bundle_create(p_code_name text, p_name text, p_global_id text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id integer;

	begin

		select b.id into v_id from sdm.bundle b where b.code_name = p_code_name;

		if not found then

			insert into sdm.bundle (code_name, "name", global_id)
			values (p_code_name, p_name, p_global_id)
			returning id into v_id;

			raise notice '''% '' (''%'') bundle record created (id=%).', p_name, p_code_name, v_id;

        else

			raise notice '''% '' (''%'') bundle record already exists (id=%).', p_name, p_code_name, v_id;

        end if;

		return v_id;

	end;
$$;


--
-- Name: f_bundle_set(text, text, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_bundle_set(p_global_id text, p_code_name text, p_name text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id integer;

	begin

		select b.id into v_id from sdm.bundle b where b.global_id = p_global_id;

		if not found then

			insert into sdm.bundle (global_id, code_name, "name")
			values (p_global_id, p_code_name, p_name)
			returning id into v_id;

			raise notice '''% '' (''%'') bundle record CREATED (id=%).', p_name, p_code_name, v_id;

        else

        	update sdm.bundle set code_name = p_code_name, "name" = p_name where id = v_id;
			raise notice '''% '' (''%'') bundle record UPDATED (id=%).', p_name, p_code_name, v_id;

        end if;

		return v_id;

	end;
$$;


--
-- Name: f_compatibility_create(text, text, text, text, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_compatibility_create(p_name_parent text, p_version_parent text, p_name_child text, p_version_child text, p_recommended boolean, p_tested boolean, p_working boolean, p_mandatory boolean) RETURNS integer
    LANGUAGE plpgsql
    AS $$
   declare
		swid_parent int4 := null;
		swid_child int4 := null;
		verid_parent int4 := null;
		verid_child int4 := null;
		v_id integer;
	begin

		select s.id into swid_parent from sdm.software s where s.name = p_name_parent;
		if not found then
			raise exception 'Parent ''%'' SW record does not exist.', p_name_parent;
		end if;

		select s.id into swid_child from sdm.software s where s.name = p_name_child;
		if not found then
			raise exception 'Child ''%'' SW record does not exist.', p_name_child;
		end if;

		select sv.id into verid_parent from sdm.software_version sv where sv.software_id = swid_parent and sv."version" = p_version_parent;
		if not found then
			raise exception 'Parent ''% %'' version does not exist.', p_name_parent, p_version_parent;
		end if;

		select sv.id into verid_child from sdm.software_version sv where sv.software_id = swid_child and sv."version" = p_version_child;
		if not found then
			raise exception 'Child ''% %'' version does not exist.', p_name_child, p_version_child;
		end if;

		select c.id into v_id from sdm.compatibility c where c.parent_software_version_id = verid_parent and c.child_software_version_id = verid_child;

		if not found then

			if p_recommended is null then
				p_recommended := false;
			end if;

			if p_mandatory is null then
				p_mandatory := false;
			end if;

			insert into sdm.compatibility (parent_software_version_id, child_software_version_id, recommended, tested, working, mandatory)
			values (verid_parent, verid_child, p_recommended, p_tested, p_working, p_mandatory)
			returning id into v_id;

			raise notice '''% %''-''% %'' compatibility record created (id=%).', p_name_parent, p_version_parent, p_name_child, p_version_child, v_id;

        else

	        raise notice '''% %''-''% %'' compatibility record already exists (id=%).', p_name_parent, p_version_parent, p_name_child, p_version_child, v_id;

        end if;

		return v_id;

	END;
$$;


--
-- Name: f_compatibility_set_by_name(text, text, text, text, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_compatibility_set_by_name(p_name_parent text, p_version_parent text, p_name_child text, p_version_child text, p_recommended boolean, p_tested boolean, p_working boolean, p_mandatory boolean) RETURNS integer
    LANGUAGE plpgsql
    AS $$
   declare
		swid_parent int4 := null;
		swid_child int4 := null;
		verid_parent int4 := null;
		verid_child int4 := null;
		v_id integer;
	begin

		select s.id into swid_parent from sdm.software s where s.name = p_name_parent;
		if not found then
			raise exception 'Parent ''%'' SW record does not exist.', p_name_parent;
		end if;

		select s.id into swid_child from sdm.software s where s.name = p_name_child;
		if not found then
			raise exception 'Child ''%'' SW record does not exist.', p_name_child;
		end if;

		select sv.id into verid_parent from sdm.software_version sv where sv.software_id = swid_parent and sv."version" = p_version_parent;
		if not found then
			raise exception 'Parent ''% %'' version does not exist.', p_name_parent, p_version_parent;
		end if;

		select sv.id into verid_child from sdm.software_version sv where sv.software_id = swid_child and sv."version" = p_version_child;
		if not found then
			raise exception 'Child ''% %'' version does not exist.', p_name_child, p_version_child;
		end if;

		select c.id into v_id from sdm.compatibility c where c.parent_software_version_id = verid_parent and c.child_software_version_id = verid_child;

		if p_recommended is null then
			p_recommended := false;
		end if;

		if p_mandatory is null then
			p_mandatory := false;
		end if;

		if not found then

			insert into sdm.compatibility (parent_software_version_id, child_software_version_id, recommended, tested, working, mandatory)
			values (verid_parent, verid_child, p_recommended, p_tested, p_working, p_mandatory)
			returning id into v_id;

			raise notice '''% %''-''% %'' compatibility record CREATED (id=%).', p_name_parent, p_version_parent, p_name_child, p_version_child, v_id;

        else

        	update sdm.compatibility set recommended = p_recommended, tested = p_tested, working = p_working, mandatory = p_mandatory
        	where id = v_id;

	        raise notice '''% %''-''% %'' compatibility record UPDATED (id=%).', p_name_parent, p_version_parent, p_name_child, p_version_child, v_id;

        end if;

		return v_id;

	END;
$$;


--
-- Name: f_release_type_set(text, text, integer); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_release_type_set(p_code_name text, p_name text, p_weight integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
    declare
		v_id integer;
	begin
		select rt.id into v_id from sdm.release_type rt where rt.code_name = p_code_name;
		if not found then
			insert into  sdm.release_type (code_name, "name", weight) values (p_code_name, p_name, p_weight) returning id into v_id;
			raise notice '''%'' release type record CREATED (id=%).', p_code_name, v_id;
		else
			update  sdm.release_type set "name" = p_name, weight = p_weight where id = v_id;
			raise notice '''%'' release type record UPDATED (id=%).', p_code_name, v_id;
		end if;
		return v_id;
	end;
$$;


--
-- Name: f_software_bundle_create(text, text); Type: PROCEDURE; Schema: data_mgmt; Owner: -
--

CREATE PROCEDURE data_mgmt.f_software_bundle_create(p_bundle_name text, p_software_name text)
    LANGUAGE plpgsql
    AS $$
    declare
		v_id_sw integer;
		v_id_bun integer;
		v_cnt int4;
	begin

		select s.id into v_id_sw from sdm.software s where s.name = p_software_name;
		if not found then
			raise exception '''%'' SW record does not exist.', p_software_name;
		end if;

		select b.id into v_id_bun from sdm.bundle b where b.name = p_bundle_name;
		if not found then
			raise exception '''%'' bundle does not exist.', p_bundle_name;
		end if;

		select Count(*) into v_cnt
		from sdm.software_bundle sb
		where sb.bundle_id = v_id_bun and sb.software_id = v_id_sw;

		if v_cnt = 0 then
	        insert into  sdm.software_bundle (bundle_id, software_id) values (v_id_bun, v_id_sw);
        	raise notice '''%'' software was included into the ''%'' bundle (id=%/%).', p_software_name, p_bundle_name, v_id_sw, v_id_bun;
      	else
        	raise notice '''%'' software is already included into the ''%'' bundle (id=%/%).', p_software_name, p_bundle_name, v_id_sw, v_id_bun;
		end if;

	end;
$$;


--
-- Name: f_software_bundle_set_by_name(text, text); Type: PROCEDURE; Schema: data_mgmt; Owner: -
--

CREATE PROCEDURE data_mgmt.f_software_bundle_set_by_name(p_bundle_name text, p_software_name text)
    LANGUAGE plpgsql
    AS $$
    declare
		v_id_sw integer;
		v_id_bun integer;
		v_cnt int4;
	begin

		select s.id into v_id_sw from sdm.software s where s."name" = p_software_name;
		if not found then
			raise exception '''%'' SW record does not exist.', p_software_name;
		end if;

		select b.id into v_id_bun from sdm.bundle b where b."name" = p_bundle_name;
		if not found then
			raise exception '''%'' bundle does not exist.', p_bundle_name;
		end if;

		select count(*) into v_cnt
		from sdm.software_bundle sb
		where sb.bundle_id = v_id_bun and sb.software_id = v_id_sw;

		if v_cnt = 0 then
	        insert into  sdm.software_bundle (bundle_id, software_id) values (v_id_bun, v_id_sw);
        	raise notice '''%'' software was included into the ''%'' bundle (id=%/%).', p_software_name, p_bundle_name, v_id_sw, v_id_bun;
      	else
        	raise notice '''%'' software is already included into the ''%'' bundle (id=%/%).', p_software_name, p_bundle_name, v_id_sw, v_id_bun;
		end if;

	end;
$$;


--
-- Name: f_software_clean(text); Type: PROCEDURE; Schema: data_mgmt; Owner: -
--

CREATE PROCEDURE data_mgmt.f_software_clean(p_global_id text)
    LANGUAGE plpgsql
    AS $$
	declare
		v_id_software integer;
	begin

		select s.id into v_id_software from sdm.software s where s.global_id = p_global_id;
		if not found then
			raise notice 'Software record ''%'' does not exist in the database, nothing to clean.', p_global_id;
			return;
		end if;

		delete from sdm.software_source
		where software_id = v_id_software;

		delete from sdm.software_bundle
		where software_id = v_id_software;

		delete from sdm.software_version_source
		where software_version_id in
			(select sv.id
			from sdm.software_version sv
			where sv.software_id = v_id_software);

		delete from sdm.software_bundle_version
		where software_version_id in
			(select sv.id
			from sdm.software_version sv
			where sv.software_id = v_id_software);

		delete from sdm.compatibility_source
		where compatibility_id in
			(select c.id
			from sdm.compatibility c
			join sdm.software_version sv on c.parent_software_version_id = sv.id or c.child_software_version_id = sv.id
			where sv.software_id = v_id_software);

		delete from sdm.compatibility
		where parent_software_version_id in
			(select sv.id
			from sdm.software_version sv
			where sv.software_id = v_id_software)
		or child_software_version_id in
			(select sv.id
			from sdm.software_version sv
			where sv.software_id = v_id_software);

		delete from sdm.software_version
		where software_id = v_id_software;

		delete from sdm.software
		where id = v_id_software;

		raise notice 'Software record ''%'' and all dependent records have been deleted.', p_global_id;

	end;
$$;


--
-- Name: f_software_create(text, text, integer, integer); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_software_create(p_name text, p_global_id text, p_type integer, p_status integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id integer;
	begin
		select s.id into v_id from sdm.software s where s.name = p_name;
		if not found then
			insert into sdm.software (name, global_id, software_type_id, software_status_id) values (p_name, p_global_id, p_type, p_status) returning id into v_id;
			raise notice '''%'' SW record created (id=%).', p_name, v_id;
		else
			raise notice '''%'' SW record already exists (id=%).', p_name, v_id;
		end if;
		return v_id;
	end;
$$;


--
-- Name: f_software_maturity_set(text, text, integer, boolean, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_software_maturity_set(p_code_name text, p_name text, p_weight integer, p_relevant boolean, p_msa_name text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id integer;
	begin
		select sm.id into v_id from sdm.software_maturity sm where sm.code_name = p_code_name;
		if not found then
			insert into sdm.software_maturity (code_name, "name", weight, relevant, msa_name) values (p_code_name, p_name, p_weight, p_relevant, p_msa_name)
			returning id into v_id;
			raise notice '''%'' maturity record CREATED (id=%).', p_code_name, v_id;
		else
			update sdm.software_maturity set "name" = p_name, weight = p_weight, relevant = p_relevant, msa_name = p_msa_name where id = v_id;
			raise notice '''%'' maturity record UPDATED (id=%).', p_code_name, v_id;
		end if;
		return v_id;
	end;
$$;


--
-- Name: f_software_set(text, text, integer, integer); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_software_set(p_global_id text, p_name text, p_type integer, p_status integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id integer;
	begin
		select s.id into v_id from sdm.software s where s.global_id = p_global_id;
		if not found then
			insert into sdm.software (global_id, "name", software_type_id, software_status_id) values (p_global_id, p_name, p_type, p_status) returning id into v_id;
			raise notice '''%'' SW record CREATED (id=%).', p_name, v_id;
		else
			update sdm.software set "name" = p_name, software_type_id = p_type, software_status_id = p_status where id = v_id;
			raise notice '''%'' SW record UPDATED (id=%).', p_name, v_id;
		end if;
		return v_id;
	end;
$$;


--
-- Name: f_software_status_set(text, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_software_status_set(p_code_name text, p_name text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id integer;
	begin
		select ss.id into v_id from sdm.software_status ss where ss.code_name = p_code_name;
		if not found then
			insert into sdm.software_status (code_name, "name") values (p_code_name, p_name) returning id into v_id;
			raise notice '''%'' software status record CREATED (id=%).', p_code_name, v_id;
		else
			update sdm.software_status set "name" = p_name where id = v_id;
			raise notice '''%'' software status record UPDATED (id=%).', p_code_name, v_id;
		end if;
		return v_id;
	end;
$$;


--
-- Name: f_software_type_set(text, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_software_type_set(p_code_name text, p_name text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id integer;
	begin
		select st.id into v_id from sdm.software_type st where st.code_name = p_code_name;
		if not found then
			insert into sdm.software_type (code_name, "name") values (p_code_name, p_name) returning id into v_id;
			raise notice '''%'' software type record CREATED (id=%).', p_code_name, v_id;
		else
			update sdm.software_type set "name" = p_name where id = v_id;
			raise notice '''%'' software type record UPDATED (id=%).', p_code_name, v_id;
		end if;
		return v_id;
	end;
$$;


--
-- Name: f_software_version_create(text, integer, integer, integer, integer, text, integer, integer, timestamp with time zone); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_software_version_create(p_name text, p_ver1 integer, p_ver2 integer, p_ver3 integer, p_ver4 integer, p_previous_ver text, p_release_type integer, p_maturity integer, p_released_on timestamp with time zone) RETURNS integer
    LANGUAGE plpgsql
    AS $$
    declare
		v_id integer;
		v_id_sw integer;
		v_id_prev_sw integer;
		v_ver text;
	begin

		select s.id into v_id_sw from sdm.software s where s.name = p_name;
		if not found then
			raise exception '''%'' SW record does not exist.', p_name;
		end if;

		if p_previous_ver is not null then
			select sv.id into v_id_prev_sw from sdm.software_version sv
			where sv.software_id = v_id_sw and sv."version" = p_previous_ver;
			if not found then
				raise exception 'Previous version % for SW ''%'' does not exist.', p_previous_ver, p_name;
			end if;
		end if;

		select sv.id into v_id from sdm.software_version sv
		where sv.software_id = v_id_sw and sv.version_level1 = p_ver1 and sv.version_level2 = p_ver2 and sv.version_level3 = p_ver3 and sv.version_level4 = p_ver4;

		v_ver := format('%s.%s.%s.%s', p_ver1, p_ver2, p_ver3, p_ver4);
		if not found then
	        insert into sdm.software_version (software_id, previous_version_id, release_type_id, maturity_id, version_level1, version_level2, version_level3, version_level4, version_name, released_on)
			values (v_id_sw, v_id_prev_sw, p_release_type, p_maturity, p_ver1, p_ver2, p_ver3, p_ver4, p_name || ' ' || v_ver, p_released_on)
			returning id into v_id;
        	raise notice '''% %'' version record created (id=%).', p_name, v_ver, v_id;
      	else
        	raise notice '''% %'' version record already exists (id=%).', p_name, v_ver, v_id;
		end if;

	return v_id;

end;
$$;


--
-- Name: f_software_version_set_by_name(text, integer, integer, integer, integer, text, integer, integer, timestamp with time zone); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_software_version_set_by_name(p_name text, p_ver1 integer, p_ver2 integer, p_ver3 integer, p_ver4 integer, p_previous_ver text, p_release_type integer, p_maturity integer, p_released_on timestamp with time zone) RETURNS integer
    LANGUAGE plpgsql
    AS $$
    declare
		v_id integer;
		v_id_sw integer;
		v_id_prev_sw integer;
		v_ver text;
	begin

		select s.id into v_id_sw from sdm.software s where s.name = p_name;
		if not found then
			raise exception '''%'' SW record does not exist.', p_name;
		end if;

		if p_previous_ver is not null then
			select sv.id into v_id_prev_sw from sdm.software_version sv
			where sv.software_id = v_id_sw and sv."version" = p_previous_ver;
			if not found then
				raise exception 'Previous version % for SW ''%'' does not exist.', p_previous_ver, p_name;
			end if;
		end if;

		select sv.id into v_id from sdm.software_version sv
		where sv.software_id = v_id_sw and sv.version_level1 = p_ver1 and sv.version_level2 = p_ver2 and sv.version_level3 = p_ver3 and sv.version_level4 = p_ver4;

		v_ver := format('%s.%s.%s.%s', p_ver1, p_ver2, p_ver3, p_ver4);
		if not found then
	        insert into sdm.software_version (software_id, previous_version_id, release_type_id, maturity_id, version_level1, version_level2, version_level3, version_level4, version_name, released_on)
			values (v_id_sw, v_id_prev_sw, p_release_type, p_maturity, p_ver1, p_ver2, p_ver3, p_ver4, p_name || ' ' || v_ver, p_released_on)
			returning id into v_id;
        	raise notice '''% %'' version record CREATED (id=%).', p_name, v_ver, v_id;
      	else
      		update sdm.software_version set previous_version_id = v_id_prev_sw, release_type_id = p_release_type, maturity_id = p_maturity,
      				version_level1 = p_ver1, version_level2 = p_ver2, version_level3 = p_ver3, version_level4 = p_ver4, version_name = p_name || ' ' || v_ver,
      				released_on = p_released_on
      		where id = v_id;
        	raise notice '''% %'' version record UPDATED (id=%).', p_name, v_ver, v_id;
		end if;

	return v_id;

end;
$$;


--
-- Name: f_source_set(text, text, integer); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_source_set(p_code_name text, p_description text, p_source_type_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id integer;
	begin
		select s.id into v_id from sdm."source" s where s.code_name = p_code_name;
		if not found then
			insert into sdm."source" (code_name, description, source_type_id) values (p_code_name, p_description, p_source_type_id) returning id into v_id;
			raise notice '''%'' source record CREATED (id=%).', p_code_name, v_id;
		else
			update sdm."source" set description = p_description, source_type_id = p_source_type_id where id = v_id;
			raise notice '''%'' source record UPDATED (id=%).', p_code_name, v_id;
		end if;
		return v_id;
	end;
$$;


--
-- Name: f_source_type_set(text, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_source_type_set(p_code_name text, p_name text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id integer;
	begin
		select st.id into v_id from sdm.source_type st where st.code_name = p_code_name;
		if not found then
			insert into sdm.source_type (code_name, "name") values (p_code_name, p_name) returning id into v_id;
			raise notice '''%'' source type record CREATED (id=%).', p_code_name, v_id;
		else
			update sdm.source_type set "name" = p_name where id = v_id;
			raise notice '''%'' source type record UPDATED (id=%).', p_code_name, v_id;
		end if;
		return v_id;
	end;
$$;


--
-- Name: f_xform_release_type_set(text, text, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_xform_release_type_set(p_source text, p_source_release_type text, p_target_release_type text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id_source sdm."source".id%type;
		v_id_release_type sdm.release_type.id%type;
		v_id integer;
	begin

		select s.id into v_id_source from sdm."source" s where s.code_name = p_source;
		if not found then
			raise exception 'Source ''%'' record does not exist.', p_source;
		end if;

		select rt.id into v_id_release_type from sdm.release_type rt where rt.code_name = p_target_release_type;
		if not found then
			raise exception 'Release type ''%'' record does not exist.', p_target_release_type;
		end if;

		select xrt.id into v_id from sdm.xform_release_type xrt where xrt.source_id = v_id_source and xrt.source_release_type = p_source_release_type;
		if not found then
			insert into sdm.xform_release_type (source_id, source_release_type, target_release_type_id)
			values (v_id_source, p_source_release_type, v_id_release_type)
			returning id into v_id;
			raise notice '''%'' / ''%'' release type transformation rule CREATED (id=%).', p_source, p_source_release_type, v_id;
		else
			update sdm.xform_release_type
			set target_release_type_id = v_id_release_type where id = v_id;
			raise notice '''%'' / ''%'' release type transformation rule UPDATED (id=%).', p_source, p_source_release_type, v_id;
		end if;

		return v_id;

	end;
$$;


--
-- Name: f_xform_software_maturity_set(text, integer, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_xform_software_maturity_set(p_source text, p_source_maturity integer, p_target_maturity text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id_source sdm."source".id%type;
		v_id_maturity sdm.software_maturity.id%type;
		v_id integer;
	begin

		select s.id into v_id_source from sdm."source" s where s.code_name = p_source;
		if not found then
			raise exception 'Source ''%'' record does not exist.', p_source;
		end if;

		select sm.id into v_id_maturity from sdm.software_maturity sm where sm.code_name = p_target_maturity;
		if not found then
			raise exception 'Maturity ''%'' record does not exist.', p_target_maturity;
		end if;

		select xsm.id into v_id from sdm.xform_software_maturity xsm where xsm.source_id = v_id_source and xsm.source_maturity_id = p_source_maturity;
		if not found then
			insert into sdm.xform_software_maturity (source_id, source_maturity_id, target_maturity_id)
			values (v_id_source, p_source_maturity, v_id_maturity)
			returning id into v_id;
			raise notice '''%'' / ''%'' maturity transformation rule CREATED (id=%).', p_source, p_source_maturity, v_id;
		else
			update sdm.xform_software_maturity
			set target_maturity_id = v_id_maturity where id = v_id;
			raise notice '''%'' / ''%'' maturity transformation rule UPDATED (id=%).', p_source, p_source_maturity, v_id;
		end if;

		return v_id;

	end;
$$;


--
-- Name: f_xform_software_set(text, text, text, boolean, text, text, text, integer, integer, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_xform_software_set(p_source_type text, p_source text, p_input_name text, p_regular boolean, p_global_name text, p_global_id text, p_software_type text, p_category integer, p_order integer, p_apply_for text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id_source sdm."source".id%type;
		v_id_source_type sdm.source_type.id%type;
		v_id_software_type sdm.software_type.id%type;
		v_id integer := null;
	begin

		if p_source is null then
			v_id_source := null;
		else
			select s.id into v_id_source from sdm."source" s where s.code_name = p_source;
			if not found then
				raise exception 'Source ''%'' record does not exist.', p_source;
			end if;
		end if;

	if p_source_type is null then
			v_id_source_type := null;
		else
			select st.id into v_id_source_type from sdm.source_type st where st.code_name = p_source_type;
			if not found then
				raise exception 'Source type ''%'' record does not exist.', p_source_type;
			end if;
		end if;

		select st.id into v_id_software_type from sdm.software_type st where st.code_name = p_software_type;
		if not found then
			raise exception 'Software type ''%'' record does not exist.', p_software_type;
		end if;

		select xs.id into v_id from sdm.xform_software xs where xs.input_name = p_input_name and xs."order" = p_order;
		if not found then
			insert into sdm.xform_software (source_type_id, source_id, input_name, regular, global_name, global_id, software_type_id, category, "order", apply_for)
			values (v_id_source_type, v_id_source, p_input_name, p_regular, p_global_name, p_global_id, v_id_software_type, p_category, p_order, p_apply_for)
			returning id into v_id;
			raise notice '''%'' / % software transformation record CREATED (id=%).', p_input_name, p_order, v_id;
		else
			update sdm.xform_software
			set source_type_id = v_id_source_type, source_id = v_id_source, input_name = p_input_name, regular = p_regular, global_name = p_global_name,
				global_id = p_global_id, software_type_id = v_id_software_type, category = p_category, "order" = p_order, apply_for = p_apply_for
			where id = v_id;
			raise notice '''%'' / % software transformation record UPDATED (id=%).', p_input_name, p_order, v_id;
		end if;

		return v_id;

	end;
$$;


--
-- Name: f_xform_software_version_set(text, integer, text, text, character, text, character, text, text, text, text, text, text, text); Type: FUNCTION; Schema: data_mgmt; Owner: -
--

CREATE FUNCTION data_mgmt.f_xform_software_version_set(p_global_id text, p_order integer, p_source text, p_source_type text, p_extract_version_rule character, p_extract_version_pattern text, p_extract_build_rule character, p_extract_build_pattern text, p_build_version_rule1 text, p_build_version_rule2 text, p_build_version_rule3 text, p_build_version_rule4 text, p_apply_for text, p_comment text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	declare
		v_id_source sdm."source".id%type;
		v_id_source_type sdm.source_type.id%type;
		v_id integer := null;
	begin

		if p_source is null then
			v_id_source := null;
		else
			select s.id into v_id_source from sdm."source" s where s.code_name = p_source;
			if not found then
				raise exception 'Source ''%'' record does not exist.', p_source;
			end if;
		end if;

		if p_source_type is null then
			v_id_source_type := null;
		else
			select st.id into v_id_source_type from sdm.source_type st where st.code_name = p_source_type;
			if not found then
				raise exception 'Source type ''%'' record does not exist.', p_source_type;
			end if;
		end if;

		select xsv.id into v_id from sdm.xform_software_version xsv where xsv.global_id = p_global_id and xsv."order" = p_order;

		if not found then
			insert into sdm.xform_software_version(
				source_id,
				source_type_id,
				global_id,
				"order",
				extract_version_rule,
				extract_version_pattern,
				extract_build_rule,
				extract_build_pattern,
				build_version_rule1,
				build_version_rule2,
				build_version_rule3,
				build_version_rule4,
				"comment",
				apply_for)
			values (
				v_id_source,
				v_id_source_type,
				p_global_id,
				p_order,
				p_extract_version_rule,
				p_extract_version_pattern,
				p_extract_build_rule,
				p_extract_build_pattern,
				p_build_version_rule1,
				p_build_version_rule2,
				p_build_version_rule3,
				p_build_version_rule4,
				p_comment,
				p_apply_for)
			returning id into v_id;
			raise notice '''%'' / % software version transformation record CREATED (id=%).', p_global_id, p_order, v_id;
		else
			update sdm.xform_software_version
			set source_id = v_id_source,
				source_type_id = v_id_source_type,
				global_id = p_global_id,
				"order" = p_order,
				extract_version_rule = p_extract_version_rule,
				extract_version_pattern = p_extract_version_pattern,
				extract_build_rule = p_extract_build_rule,
				extract_build_pattern = p_extract_build_pattern,
				build_version_rule1 = p_build_version_rule1,
				build_version_rule2 = p_build_version_rule2,
				build_version_rule3 = p_build_version_rule3,
				build_version_rule4 = p_build_version_rule4,
				"comment" = p_comment,
				apply_for = p_apply_for
			where id = v_id;
			raise notice '''%'' / % software version transformation record UPDATED (id=%).', p_global_id, p_order, v_id;
		end if;

		return v_id;

	end;
$$;


--
-- Name: f_check_compatibility(sdm.t_check_compatibility[], boolean); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_check_compatibility(cc sdm.t_check_compatibility[], tested_only boolean DEFAULT false) RETURNS TABLE(parent_global_id text, parent_name text, parent_version text, child_global_id text, child_name text, child_version text)
    LANGUAGE plpgsql
    AS $$
declare vCount integer;
declare vGlobalIds text[];
declare vVersions text[];
begin
-- zkusim global id zda existuji
select
	count(t.global_id) ,
	array_agg(t.global_id)
from
	unnest(cc) as t
where
	not exists (
	select
		1
	from
		sdm.software s
	where
		s.global_id = t.global_id) into vCount,vGlobalIds;
if vCount > 0 then
  raise exception 'not exists global_id %',vGlobalIds;
end if;
-- zkusim zda existuje verze, pozor, je vazana i na global id
select
	count(t.global_id) ,
	array_agg(t.global_id),
	array_agg(t.version)
from
	unnest(cc) as t
where
	not exists (
	select
		1
	from
		sdm.software s
	join sdm.software_version sv on
		sv.software_id = s.id
	where
		(sv.version = t.version)
		and s.global_id = t.global_id) into vCount,vGlobalIds,vVersions;
if vCount > 0 then
  raise exception 'not exists version % for software %', vVersions , vGlobalIds;
end if;

return QUERY
select
	s.global_id parent_global_id,
	s.name as parent_name,
	sv.version as parent_version,
	s2.global_id as child_global_id,
	s2.software_name as child_name,
	s2.version as child_version
from
	sdm.software s
join sdm.software_version sv on
	sv.software_id = s.id
join lateral (
	select
		s.global_id,
		sv.id as child_software_version_id,
		sv.version,
		s.name as software_name
	from
		sdm.software s
	join sdm.software_version sv on
		sv.software_id = s.id
  ) s2 on
	s2.global_id != s.global_id
where
	(s.global_id,sv.version ) = any  (select t.global_id,  t.version from unnest(cc) as t)
	and  (s2.global_id,s2.version ) = any  (select t.global_id, t.version from unnest(cc) as t)
	-- vratim ty vetve co nejsou v compatibility
	and not exists (
	select
		c.*,
		sv2."version" ,
		sv3."version"
	from
		sdm.compatibility c
	join sdm.software_version sv2 on
		sv2.id = c.parent_software_version_id
	join sdm.software_version sv3 on
		sv3.id = c.child_software_version_id
	where
		sv.id = c.parent_software_version_id
		and s2.child_software_version_id = c.child_software_version_id
		and ((not tested_only) or c.tested )
  )
  --vyhodim vsechny ty ktery jiz maji opacny smer
	and not exists (
	select
		1
	from
		sdm.compatibility c2
	where
		c2.parent_software_version_id = s2.child_software_version_id
		and c2.child_software_version_id = sv.id)

	-- tady se chytam existujici vazby od jineho software podle global_id
	and exists (
	select 1
	from
		sdm.compatibility c
	join sdm.vw_version sv2 on
		sv2.id = c.parent_software_version_id
	join sdm.vw_version sv3 on
		sv3.id = c.child_software_version_id
	where
		sv2.global_id = s.global_id
        and sv3.global_id = s2.global_id
	)
order by s.global_id asc,s2.global_id asc
;
end;

$$;


--
-- Name: f_filtered_dependencies(boolean); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_filtered_dependencies(a_tested_only boolean DEFAULT false) RETURNS TABLE(software_version_id integer, parent_software_version_id integer, origin_software_version_id integer, version text, parent_version text, origin_version text, software_id integer, global_id text, parent_software_id integer, parent_global_id text, origin_global_id text, software_name text, parent_software_name text, version_name text, parent_version_name text, version_guid uuid, parent_version_guid uuid, tested boolean, lvl integer, version_names text[], versions text[], global_ids text[], software_names text[], compatibilities sdm.t_check_compatibility[])
    LANGUAGE plpgsql
    AS $$
begin
 return QUERY WITH RECURSIVE cte AS (
         SELECT sv.id AS software_version_id,
            sv.id AS parent_software_version_id,
            sv.id AS origin_software_version_id,
            sv.version,
            sv.version AS parent_version,
            sv.version AS origin_version,
            sv.software_id,
            sv.global_id,
            sv.software_id AS parent_software_id,
            sv.global_id AS parent_global_id,
            sv.global_id AS origin_global_id,
            sv.software_name,
            sv.software_name AS parent_software_name,
            sv.version_name,
            sv.version_name AS parent_version_name,
            sv.guid AS version_guid,
            sv.guid AS parent_version_guid,
            true AS tested,
            1 AS lvl,
            ARRAY[sv.version_name] AS version_names,
            ARRAY[sv.version] AS versions,
            ARRAY[sv.global_id] AS global_ids,
            ARRAY[sv.software_name] AS software_names,
            ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility] AS compatibilities
           FROM sdm.vw_version sv
          WHERE (EXISTS ( SELECT 1
                   FROM sdm.compatibility c2
                  WHERE sv.id = c2.parent_software_version_id and (c2.tested or not a_tested_only)))
        UNION ALL
         SELECT sv.id AS software_version_id,
            cte_1.software_version_id AS parent_software_version_id,
            cte_1.origin_software_version_id,
            sv.version,
            cte_1.version AS parent_version,
            cte_1.origin_version,
            sv.id AS software_id,
            sv.global_id,
            cte_1.software_id AS parent_software_id,
            cte_1.global_id AS parent_global_id,
            cte_1.origin_global_id,
            sv.software_name,
            cte_1.software_name AS parent_software_name,
            sv.version_name,
            cte_1.version_name AS parent_version_name,
            sv.guid AS version_guid,
            cte_1.version_guid AS parent_version_guid,
            c.tested AND cte_1.tested,
            cte_1.lvl + 1 AS lvl,
            cte_1.version_names || sv.version_name AS version_names,
            cte_1.versions || sv.version AS versions,
            cte_1.global_ids || sv.global_id AS global_ids,
            cte_1.software_names || sv.software_name AS software_names,
            cte_1.compatibilities || ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility]
           FROM cte cte_1
             JOIN sdm.compatibility c ON c.parent_software_version_id = cte_1.software_version_id and (c.tested or not a_tested_only)
             JOIN sdm.vw_version sv ON c.child_software_version_id = sv.id
         where
         not exists (SELECT 1
                           FROM unnest(cte_1.compatibilities) t(global_id, version)
                           join sdm.vw_version  vv on vv.version = t.version and vv.global_id= t.global_id
                           join sdm.compatibility c on
                             (( vv.id = c.parent_software_version_id and c.parent_software_version_id =sv.id)
                             or (vv.id = c.child_software_version_id and c.child_software_version_id = sv.id))
                            and not ( c.tested or not a_tested_only)
                         )
           and
          NOT EXISTS (
          SELECT 1
                   FROM ( SELECT t.global_id
                           FROM unnest(cte_1.compatibilities) t(global_id, version)
                          WHERE NOT EXISTS
                          (
                          SELECT sv2.global_id
                                   FROM sdm.vw_version sv2
                                     JOIN sdm.compatibility c2 ON c2.parent_software_version_id = sv2.id
                                  WHERE t.global_id = sv2.global_id
                                  AND t.version = sv2.version AND c2.child_software_version_id = sv.id)) a
                  WHERE EXISTS ( SELECT
                           FROM sdm.compatibility c2
                             JOIN sdm.vw_version sv2 ON c2.parent_software_version_id = sv2.id
                             JOIN sdm.vw_version sv3 ON c2.child_software_version_id = sv3.id
                          WHERE a.global_id = sv2.global_id AND sv.global_id = sv3.global_id))
        )
 SELECT cte.software_version_id,
    cte.parent_software_version_id,
    cte.origin_software_version_id,
    cte.version,
    cte.parent_version,
    cte.origin_version,
    cte.software_id,
    cte.global_id,
    cte.parent_software_id,
    cte.parent_global_id,
    cte.origin_global_id,
    cte.software_name,
    cte.parent_software_name,
    cte.version_name,
    cte.parent_version_name,
    cte.version_guid,
    cte.parent_version_guid,
    cte.tested,
    cte.lvl,
    cte.version_names,
    cte.versions,
    cte.global_ids,
    cte.software_names,
    cte.compatibilities
   FROM cte where (cte.tested or not a_tested_only);
end;
$$;


--
-- Name: f_get_compatible_versions(sdm.t_check_compatibility[], sdm.t_check_flag[]); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_get_compatible_versions(a_check_compatibilities sdm.t_check_compatibility[], a_check_flags sdm.t_check_flag[] DEFAULT '{check_all}'::sdm.t_check_flag[]) RETURNS SETOF sdm.t_check_compatibility[]
    LANGUAGE plpgsql
    AS $$
declare vCount integer;
declare vGlobalIds text[];
declare vGlobalIdsAll text[];
declare vVersions text[];
declare vCompatibilities sdm.t_check_compatibility[];
begin
-- zkusim global id zda existuji
select
	count(t.global_id) ,
	array_agg(t.global_id)
from
	unnest(a_check_compatibilities) as t
where
	not exists (
	select
		1
	from
		sdm.software s
	where
		s.global_id = t.global_id) into vCount,vGlobalIds;
if vCount > 0 then
  raise exception 'not exists global_id %',vGlobalIds;
end if;
-- zkusim zda existuje verze, pozor, je vazana i na global id
select
	count(t.global_id) ,
	array_agg(t.global_id),
	array_agg(t.version)
from
	unnest(a_check_compatibilities) as t
where
	not exists (
	select
		1
	from
		sdm.software s
	join sdm.software_version sv on
		sv.software_id = s.id
	where
		(sv.version = t.version or t.version='')
		and s.global_id = t.global_id) into vCount,vGlobalIds,vVersions;
if vCount > 0 then
  raise exception 'not exists version % for software %', vVersions , vGlobalIds;
end if;
select
	array_agg(t.global_id) FILTER (where t.version='') over( order by t.global_id),
	array_agg(t.global_id) over(order by t.global_id),
	array_agg(row(t.global_id,t.version)::sdm.t_check_compatibility) FILTER(where t.version!='') over( order by t.global_id) ::sdm.t_check_compatibility[]
from
	unnest(a_check_compatibilities) as t
	order by t.global_id desc
into vGlobalIds,vGlobalIdsAll,vCompatibilities;
return QUERY
   with cte as (select vd.compatibilities,vd.global_ids
                      from sdm.f_filtered_dependencies('check_tested_only' = any (a_check_flags)) vd
                      where  (vd.compatibilities @> vCompatibilities or vCompatibilities is null)
                        and  ( vd.global_ids && vGlobalIds or vGlobalIds is null)
                        and (select array(select * from unnest(vd.global_ids) order by 1)::text[]=vGlobalIdsAll or ('check_all' = any (a_check_flags)))
                        )

   select cte.compatibilities from cte where
    not exists (
         select 1 from cte as cte2
                where
                   (array_length(cte2.compatibilities,1) > array_length(cte.compatibilities,1)
                                     and (
                                      cte2.global_ids@> cte.global_ids
                                     )))

   order by cte.compatibilities::text collate sdm.en_natural;

end;

$$;


--
-- Name: f_get_compatible_versions_grouped(sdm.t_check_compatibility[], sdm.t_check_flag[]); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_get_compatible_versions_grouped(a_check_compatibilities sdm.t_check_compatibility[], a_check_flags sdm.t_check_flag[] DEFAULT '{check_all}'::sdm.t_check_flag[]) RETURNS TABLE(global_id text, version text)
    LANGUAGE plpgsql
    AS $$
begin
    RETURN QUERY
        SELECT (g.col::sdm.t_check_compatibility).global_id,(g.col::sdm.t_check_compatibility).version from (SELECT DISTINCT A.ARR::sdm.t_check_compatibility as  col FROM (SELECT unnest(array_agg(vd)::sdm.t_check_compatibility[]) AS arr
                                                                                                                                                                            FROM sdm.f_get_compatible_versions_v3(
                                                                                                                                                                                         a_check_compatibilities,
                                                                                                                                                                                         a_check_flags) vd
                                                                                                                                                                           ) A) g
        order by global_id,version;
end;

$$;


--
-- Name: f_get_compatible_versions_v3(sdm.t_check_compatibility[], sdm.t_check_flag[]); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_get_compatible_versions_v3(a_check_compatibilities sdm.t_check_compatibility[], a_check_flags sdm.t_check_flag[] DEFAULT '{check_all}'::sdm.t_check_flag[]) RETURNS SETOF sdm.t_check_compatibility[]
    LANGUAGE plpgsql
    AS $$
DECLARE
    vCount                integer;
    DECLARE vGlobalIds    text[];
    DECLARE vGlobalIdsAll text[];
    DECLARE vVersions     text[];
BEGIN
    -- zkusim global id zda existuji
    SELECT COUNT(t.global_id),
           ARRAY_AGG(t.global_id)
    FROM UNNEST(a_check_compatibilities) AS t
    WHERE NOT EXISTS(
            SELECT 1
            FROM sdm.software s
            WHERE s.global_id = t.global_id)
    INTO vCount,vGlobalIds;
    IF vCount > 0 THEN
        RAISE EXCEPTION 'not exists global_id %',vGlobalIds;
    END IF;
-- zkusim zda existuje verze, pozor, je vazana i na global DISTINCTid
    SELECT COUNT(t.global_id),
           ARRAY_AGG(t.global_id),
           ARRAY_AGG(t.version)
    FROM UNNEST(a_check_compatibilities) AS t
    WHERE NOT EXISTS(
            SELECT 1
            FROM sdm.software s
                     JOIN sdm.software_version sv ON
                    sv.software_id = s.id
            WHERE (sdm.f_semver_match(sv.version, t.version) OR t.version = '')
              AND s.global_id = t.global_id)
    INTO vCount,vGlobalIds,vVersions;
    IF vCount > 0 THEN
        RAISE EXCEPTION 'not exists version % for software %', vVersions , vGlobalIds;
    END IF;

    SELECT ARRAY_AGG(t.global_id) FILTER (WHERE t.version = '') OVER ( ORDER BY t.global_id),
           ARRAY_AGG(t.global_id) OVER (ORDER BY t.global_id)
    FROM UNNEST(a_check_compatibilities) AS t
    ORDER BY t.global_id DESC
    INTO vGlobalIds,vGlobalIdsAll;


    RETURN QUERY
        WITH RECURSIVE cte AS (SELECT vd.compatibilities,
                            vd.global_ids,
                            vd.parent_global_id,
                            vd.parent_version,
                            vd.global_id,
                            vd.version,
                            vd.origin_global_id,
                            vd.origin_version,
                            vd.tested
                     FROM sdm.vw_filtered_dependencies_v3 vd
                     WHERE (SELECT ARRAY(SELECT * FROM UNNEST(vd.global_ids) ORDER BY 1)::text[] <@ vGlobalIdsAll
                                       OR ('check_all' = ANY (a_check_flags) AND (vd.global_ids && vGlobalIdsAll)))
        ),

             cte2 AS (SELECT r.*
                      FROM (
                               SELECT DISTINCT ON (cte.compatibilities::text COLLATE sdm.en_natural) cte.compatibilities,
                                                                                                     ARRAY_AGG(t.val) OVER () AS gIds,
                                                                                                     cte.global_ids,
                                                                                                     cte.parent_global_id,
                                                                                                     cte.parent_version,
                                                                                                     cte.global_id,
                                                                                                     cte.version,
                                                                                                     cte.origin_global_id,
                                                                                                     cte.origin_version,
                                                                                                     cte.tested
                               FROM cte
                                        JOIN LATERAL (SELECT t AS val FROM UNNEST(cte.global_ids) AS t ) t ON TRUE
                               WHERE (
                                       sdm.f_semver_containt_array_array(cte.compatibilities, a_check_compatibilities)
                                       OR a_check_compatibilities IS NULL)
                                 AND NOT EXISTS(
                                       SELECT 1
                                       FROM cte AS cte2
                                       WHERE (ARRAY_LENGTH(cte2.compatibilities, 1) >
                                              ARRAY_LENGTH(cte.compatibilities, 1)
                                           AND (
                                                      cte2.global_ids @> cte.global_ids
                                                  )))
                             ) r
                      WHERE vGlobalIdsAll <@ r.gIds
                 ),
             -- recursivne dohledam, ktere k sobe mohou patrit a maji stejne verze
             cte3 AS (
                SELECT  ct2.compatibilities,
                          ct2.global_ids,
                          ct2.tested,
                          ct2.origin_global_id,
                          ct2.origin_version
                 from  cte2 ct2
                 union all
                 SELECT ct3.compatibilities || ct2.compatibilities AS compatibilities,
                     ct3.global_ids || ct2.global_ids         AS global_ids,
                            ct2.tested and ct3.tested,
                            ct2.origin_global_id,
                            ct2.origin_version
                     FROM cte3 ct3
                     JOIN cte2 ct2 ON
                       ct2.compatibilities && ct3.compatibilities
                       AND NOT  ct3.compatibilities @> ct2.compatibilities
                       AND NOT EXISTS(SELECT 1
                                            FROM UNNEST(ct2.compatibilities) cooo
                                            WHERE EXISTS(
                                                          SELECT t.global_id
                                                          FROM UNNEST(ct3.compatibilities) t
                                                          WHERE t.global_id = cooo.global_id
                                                            AND t.version != cooo.version))
                        ),
             --na zaver distinct
             cte4 as (
                 SELECT (SELECT ARRAY(SELECT DISTINCT UNNEST(ct3.compatibilities) ORDER BY 1)) AS compatibilities,
                        (SELECT ARRAY(SELECT DISTINCT UNNEST(ct3.global_ids) ORDER BY 1))           AS global_ids,
                        ct3.tested and ct3.tested as tested,
                        ct3.origin_global_id,
                        ct3.origin_version
                 FROM cte3 ct3


             )

            --    SELECT ct3.compatibilities from cte3 ct3;

        SELECT ct4.compatibilities
        FROM (SELECT ct4.compatibilities, MIN(ct4.tested::int)::boolean AS tested
              FROM cte4 ct4
              WHERE ct4.global_ids @> vGlobalIdsAll
                AND NOT EXISTS(SELECT 1
                               FROM cte4 ct44
                               WHERE ct44.compatibilities @> ct4.compatibilities
                                 AND ARRAY_LENGTH(ct44.compatibilities, 1) > ARRAY_LENGTH(ct4.compatibilities, 1))
              GROUP BY ct4.compatibilities
             ) ct4
        WHERE (ct4.tested OR NOT ('check_tested_only' = ANY (a_check_flags)))
        ORDER BY ct4.compatibilities::text COLLATE sdm.en_natural;
END

$$;


--
-- Name: f_get_compatible_versions_v4(sdm.t_check_compatibility[], sdm.t_check_flag[]); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_get_compatible_versions_v4(a_check_compatibilities sdm.t_check_compatibility[], a_check_flags sdm.t_check_flag[] DEFAULT '{check_all}'::sdm.t_check_flag[]) RETURNS SETOF sdm.t_check_compatibility[]
    LANGUAGE plpgsql
    AS $$
DECLARE
    vCount                integer;
    DECLARE vGlobalIds    text[];
    DECLARE vGlobalIdsAll text[];
    DECLARE vVersions     text[];
BEGIN
    -- zkusim global id zda existuji
    SELECT COUNT(t.global_id),
           ARRAY_AGG(t.global_id)
    FROM UNNEST(a_check_compatibilities) AS t
    WHERE NOT EXISTS(
            SELECT 1
            FROM sdm.software s
            WHERE s.global_id = t.global_id)
    INTO vCount,vGlobalIds;
    IF vCount > 0 THEN
        RAISE EXCEPTION 'not exists global_id %',vGlobalIds;
    END IF;
-- zkusim zda existuje verze, pozor, je vazana i na global id
    SELECT COUNT(t.global_id),
           ARRAY_AGG(t.global_id),
           ARRAY_AGG(t.version)
    FROM UNNEST(a_check_compatibilities) AS t
    WHERE NOT EXISTS(
            SELECT 1
            FROM sdm.software s
                     JOIN sdm.software_version sv ON
                sv.software_id = s.id
            WHERE (sdm.f_semver_match(sv.version, t.version) OR t.version = '')
              AND s.global_id = t.global_id)
    INTO vCount,vGlobalIds,vVersions;
    IF vCount > 0 THEN
        RAISE EXCEPTION 'not exists version % for software %', vVersions , vGlobalIds;
    END IF;

    SELECT ARRAY_AGG(t.global_id) FILTER (WHERE t.version = '') OVER ( ORDER BY t.global_id),
           ARRAY_AGG(t.global_id) OVER (ORDER BY t.global_id)
    FROM UNNEST(a_check_compatibilities) AS t
    ORDER BY t.global_id DESC
    INTO vGlobalIds,vGlobalIdsAll;


    RETURN QUERY
        WITH cte AS (SELECT vd.compatibilities,
                            vd.global_ids,
                            vd.origin_global_id,
                            vd.origin_version
                     FROM sdm.f_filtered_dependencies('check_tested_only' = ANY (a_check_flags)) vd
                     WHERE (SELECT ARRAY(SELECT * FROM UNNEST(vd.global_ids) ORDER BY 1)::text[] <@ vGlobalIdsAll
                                       OR ('check_all' = ANY (a_check_flags) AND (vd.global_ids && vGlobalIdsAll)))
        ),
             cte2 AS (SELECT r.compatibilities, r.global_ids, r.origin_global_id, r.origin_version
                      FROM (
                               SELECT DISTINCT ON (cte.compatibilities::text COLLATE sdm.en_natural) cte.compatibilities,
                                                                                                     cte.global_ids,
                                                                                                     cte.origin_global_id,
                                                                                                     cte.origin_version,
                                                                                                     ARRAY_AGG(t.val) OVER () AS gIds
                               FROM cte
                                        JOIN LATERAL (SELECT t AS val FROM UNNEST(cte.global_ids) AS t ) t ON TRUE
                               WHERE (
                                       sdm.f_semver_containt_array_array(cte.compatibilities, a_check_compatibilities)
                                       OR a_check_compatibilities IS NULL)
                                 AND NOT EXISTS(
                                       SELECT 1
                                       FROM cte AS cte2
                                       WHERE (ARRAY_LENGTH(cte2.compatibilities, 1) >
                                              ARRAY_LENGTH(cte.compatibilities, 1)
                                           AND (
                                                  cte2.global_ids @> cte.global_ids
                                                  )))

                               ORDER BY cte.compatibilities::text COLLATE sdm.en_natural) r
                      WHERE vGlobalIdsAll <@ r.gIds),
             cte3 AS (SELECT ct2.*, ctt.global_id AS n_global_id, ctt.version AS n_version
                      FROM cte2 ct2
                               LEFT JOIN LATERAL ( SELECT c.global_id, c.version
                                                   FROM UNNEST(ct2.compatibilities::sdm.t_check_compatibility[]) c ) ctt
                                         ON TRUE
             ),
             cte4 AS (SELECT ct3.origin_global_id,
                             ct3.origin_version,
                             ARRAY_AGG(DISTINCT
                                       ROW (ct3.n_global_id,ct3.n_version)::sdm.t_check_compatibility)::sdm.t_check_compatibility[] comp
                      FROM cte3 ct3
                      GROUP BY ct3.origin_global_id, ct3.origin_version)

        SELECT ct4.comp
        FROM cte4 ct4
        WHERE EXISTS(SELECT 1
                     FROM (SELECT ARRAY_AGG(c.global_id)::text[] AS global_ids FROM UNNEST(ct4.comp) c) c
                     WHERE c.global_Ids @> vGlobalIdsAll)
        order by ct4.comp::text collate sdm.en_natural
    ;

END

$$;


--
-- Name: f_semver_containt_array_array(sdm.t_check_compatibility[], sdm.t_check_compatibility[]); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_semver_containt_array_array(a_comps sdm.t_check_compatibility[], a_rqs sdm.t_check_compatibility[]) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
declare vreq sdm.t_check_compatibility;
    declare vres boolean;
begin
    select count(t.*)=0 from unnest(a_rqs) as t where t.version!='' and exists(select c.global_id from unnest(a_comps) as c where c.global_id=t.global_id)  into vres;
    for vreq in (select t.* from unnest(a_rqs) as t where t.version!='' and  exists (
            select c.global_id from unnest(a_comps) as c where c.global_id=t.global_id))
        loop
            vres:= true;
            if not sdm.f_semver_match_array(vreq, a_comps) then
                return false;
            end if;
        end loop;
    return vres;
END;

$$;


--
-- Name: f_semver_match(text, text); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_semver_match(version text, req text) RETURNS boolean
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
SELECT CASE
           WHEN req LIKE '~>%' THEN
                       string_to_array(version, '.')::int[] >= string_to_array(substring(req from 4), '.')::int[]
                   AND
                       string_to_array(version, '.')::int[] <
                           -- increment last item by one. (X.Y.Z => X.Y.(Z+1))
                       array_append(
                               (string_to_array(substring(req from 4), '.')::int[])[1:(array_length(string_to_array(req, '.'), 1) - 1)], -- X.Y
                               (string_to_array(substring(req from 4), '.')::int[])[array_length(string_to_array(req, '.'), 1)] + 1 -- Z + 1
                           )
           WHEN (req LIKE '>%') AND (req not like '>=%') THEN string_to_array(version, '.')::int[] > string_to_array(substring(req from 2), '.')::int[]
           WHEN (req LIKE '<%' ) AND (req not like '<=%') THEN string_to_array(version, '.')::int[] < string_to_array(substring(req from 2), '.')::int[]
           WHEN req LIKE '>=%' THEN string_to_array(version, '.')::int[] >= string_to_array(substring(req from 3), '.')::int[]
           WHEN req LIKE '<=%' THEN string_to_array(version, '.')::int[] <= string_to_array(substring(req from 3), '.')::int[]
           WHEN req LIKE '=%' THEN
                   (string_to_array(version, '.')::int[])[1:array_length(string_to_array(substring(req from 2), '.'), 1)] =
                   string_to_array(substring(req from 2), '.')::int[]
           ELSE trim(req) like trim(version)
           END
$$;


--
-- Name: f_semver_match_array(sdm.t_check_compatibility, sdm.t_check_compatibility[]); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_semver_match_array(a_rq sdm.t_check_compatibility, a_comps sdm.t_check_compatibility[]) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
declare vcomp sdm.t_check_compatibility;
begin
    for vcomp in (select * from unnest(a_comps) as t where t.global_id=a_rq.global_id and a_rq.version!='')
        loop
            return sdm.f_semver_match(vcomp.version, a_rq.version);
        end loop;
    return true;
END;

$$;


--
-- Name: f_semver_match_array_array(sdm.t_check_compatibility[], sdm.t_check_compatibility[]); Type: FUNCTION; Schema: sdm; Owner: -
--

CREATE FUNCTION sdm.f_semver_match_array_array(a_comps sdm.t_check_compatibility[], a_rqs sdm.t_check_compatibility[]) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
declare vreq sdm.t_check_compatibility;
begin
    for vreq in (select t.* from unnest(a_rqs) as t)
        loop
            if not sdm.f_semver_match_array(vreq, a_comps) then
                return false;
            end if;
        end loop;
    return true;
END;

$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: compatibility; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.compatibility (
    id integer NOT NULL,
    parent_software_version_id integer NOT NULL,
    child_software_version_id integer NOT NULL,
    recommended boolean NOT NULL,
    tested boolean NOT NULL,
    working boolean,
    mandatory boolean NOT NULL
);


--
-- Name: TABLE compatibility; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.compatibility IS 'This table defines what versions of the software are compatible with each other, as an extension of the dependency between two software items.';


--
-- Name: COLUMN compatibility.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility.id IS 'Primary key';


--
-- Name: COLUMN compatibility.parent_software_version_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility.parent_software_version_id IS 'The parent software version in the compatibility relation';


--
-- Name: COLUMN compatibility.child_software_version_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility.child_software_version_id IS 'The child software version in the compatibility relation';


--
-- Name: COLUMN compatibility.recommended; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility.recommended IS 'Flag if this combination of versions is the recommended one (within the given parent version, only one child version can be marked as recommended).';


--
-- Name: COLUMN compatibility.tested; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility.tested IS 'Flag if this combination of versions has been tested.';


--
-- Name: COLUMN compatibility.working; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility.working IS 'Flag if this combination of versions is working (NULL = unknown).';


--
-- Name: COLUMN compatibility.mandatory; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility.mandatory IS 'Flag if the child software version has to accompany mandatorily the parent software.';


--
-- Name: software; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.software (
    id integer NOT NULL,
    name text NOT NULL,
    global_id text NOT NULL,
    software_type_id integer NOT NULL,
    software_status_id integer NOT NULL
);


--
-- Name: TABLE software; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.software IS 'This table defines various software that is subject to software distribution.';


--
-- Name: COLUMN software.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software.id IS 'Primary key, an internal identifier of the software record.';


--
-- Name: COLUMN software.name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software.name IS 'Generic (global) name of the software that can be used in front-ends and reports.';


--
-- Name: COLUMN software.global_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software.global_id IS 'A system-wide unique global ID (or code name) of the software that allows to unambiguously identify the software across systems.';


--
-- Name: COLUMN software.software_type_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software.software_type_id IS 'Type of the software.';


--
-- Name: COLUMN software.software_status_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software.software_status_id IS 'Status of the software.';


--
-- Name: software_version_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.software_version_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: software_version; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.software_version (
    id integer DEFAULT nextval('sdm.software_version_id_seq'::regclass) NOT NULL,
    software_id integer NOT NULL,
    previous_version_id integer,
    release_type_id integer NOT NULL,
    maturity_id integer NOT NULL,
    version_level1 integer DEFAULT '-1'::integer NOT NULL,
    version_level2 integer DEFAULT '-1'::integer NOT NULL,
    version_level3 integer DEFAULT '-1'::integer NOT NULL,
    version_level4 integer DEFAULT '-1'::integer NOT NULL,
    version_name text NOT NULL,
    released_on timestamp with time zone NOT NULL,
    repo_link text,
    guid uuid,
    version text GENERATED ALWAYS AS (((((((
CASE
    WHEN (version_level1 = '-1'::integer) THEN '*'::text
    ELSE (version_level1)::text
END || '.'::text) ||
CASE
    WHEN (version_level2 = '-1'::integer) THEN '*'::text
    ELSE (version_level2)::text
END) || '.'::text) ||
CASE
    WHEN (version_level3 = '-1'::integer) THEN '*'::text
    ELSE (version_level3)::text
END) || '.'::text) ||
CASE
    WHEN (version_level4 = '-1'::integer) THEN '*'::text
    ELSE (version_level4)::text
END)) STORED,
    standardized_version text GENERATED ALWAYS AS (((((((lpad((version_level1)::text, 6, '0'::text) || '.'::text) || lpad((version_level2)::text, 6, '0'::text)) || '.'::text) || lpad((version_level3)::text, 6, '0'::text)) || '.'::text) || lpad((version_level4)::text, 6, '0'::text))) STORED
);


--
-- Name: TABLE software_version; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.software_version IS 'This table represents a specific version of the software.';


--
-- Name: COLUMN software_version.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.id IS 'Primary key.';


--
-- Name: COLUMN software_version.software_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.software_id IS 'Reference to the software, for which this version exists.';


--
-- Name: COLUMN software_version.previous_version_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.previous_version_id IS 'Reference to the previous version of the software.';


--
-- Name: COLUMN software_version.release_type_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.release_type_id IS 'Type of the software release.';


--
-- Name: COLUMN software_version.maturity_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.maturity_id IS 'Maturity of the software version.';


--
-- Name: COLUMN software_version.version_level1; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.version_level1 IS 'The numeric representation of the <major> part of the version number (used for "comparison" purposes).';


--
-- Name: COLUMN software_version.version_level2; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.version_level2 IS 'The numeric representation of the <minor> part of the version number (used for "comparison" purposes).';


--
-- Name: COLUMN software_version.version_level3; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.version_level3 IS 'The numeric representation of the <release> part of the version number (used for "comparison" purposes).';


--
-- Name: COLUMN software_version.version_level4; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.version_level4 IS 'The numeric representation of the <build> part of the version number (used for "comparison" purposes).';


--
-- Name: COLUMN software_version.version_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.version_name IS 'The "business name" of the software version, intended for display purposes. Normally it should be something like a concatenation of software name and its version but in fact it can be any text.';


--
-- Name: COLUMN software_version.released_on; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.released_on IS 'Date and time when the software version has been released.';


--
-- Name: COLUMN software_version.repo_link; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.repo_link IS 'Link to the software repository, which contains the installer (software package) of this software version.';


--
-- Name: COLUMN software_version.guid; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.guid IS 'Optional UUID identifier provided by the source.';


--
-- Name: COLUMN software_version.version; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.version IS 'The concatenated form of the version number (calculated field).';


--
-- Name: COLUMN software_version.standardized_version; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version.standardized_version IS 'The concatenated and sortable form of the version number (calculated field).';


--
-- Name: vw_version; Type: VIEW; Schema: sdm; Owner: -
--

CREATE VIEW sdm.vw_version AS
 SELECT sv.id,
    sv.software_id,
    sv.version_name,
    sv.guid,
    sv.released_on,
    s.global_id,
    s.name AS software_name,
    sv.version
   FROM (sdm.software_version sv
     JOIN sdm.software s ON ((s.id = sv.software_id)));


--
-- Name: vw_filtered_dependencies_v2; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_filtered_dependencies_v2 AS
 WITH RECURSIVE cte AS (
         SELECT sv.id AS software_version_id,
            sv.id AS parent_software_version_id,
            sv.id AS origin_software_version_id,
            sv.version,
            sv.version AS parent_version,
            sv.version AS origin_version,
            sv.software_id,
            sv.global_id,
            sv.software_id AS parent_software_id,
            sv.global_id AS parent_global_id,
            sv.global_id AS origin_global_id,
            sv.software_name,
            sv.software_name AS parent_software_name,
            sv.version_name,
            sv.version_name AS parent_version_name,
            sv.guid AS version_guid,
            sv.guid AS parent_version_guid,
            true AS tested,
            1 AS lvl,
            ARRAY[sv.version_name] AS version_names,
            ARRAY[sv.version] AS versions,
            ARRAY[sv.global_id] AS global_ids,
            ARRAY[sv.software_name] AS software_names,
            ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility] AS compatibilities
           FROM sdm.vw_version sv
          WHERE (EXISTS ( SELECT 1
                   FROM sdm.compatibility c2
                  WHERE (sv.id = c2.parent_software_version_id)))
        UNION ALL
         SELECT sv.id AS software_version_id,
            cte_1.software_version_id AS parent_software_version_id,
            cte_1.origin_software_version_id,
            sv.version,
            cte_1.version AS parent_version,
            cte_1.origin_version,
            sv.id AS software_id,
            sv.global_id,
            cte_1.software_id AS parent_software_id,
            cte_1.global_id AS parent_global_id,
            cte_1.origin_global_id,
            sv.software_name,
            cte_1.software_name AS parent_software_name,
            sv.version_name,
            cte_1.version_name AS parent_version_name,
            sv.guid AS version_guid,
            cte_1.version_guid AS parent_version_guid,
            (c.tested AND cte_1.tested),
            (cte_1.lvl + 1) AS lvl,
            (cte_1.version_names || sv.version_name) AS version_names,
            (cte_1.versions || sv.version) AS versions,
            (cte_1.global_ids || sv.global_id) AS global_ids,
            (cte_1.software_names || sv.software_name) AS software_names,
            (cte_1.compatibilities || ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility])
           FROM ((cte cte_1
             JOIN sdm.compatibility c ON ((c.parent_software_version_id = cte_1.software_version_id)))
             JOIN sdm.vw_version sv ON ((c.child_software_version_id = sv.id)))
          WHERE (NOT (EXISTS ( SELECT 1
                   FROM ( SELECT t.global_id
                           FROM unnest(cte_1.compatibilities) t(global_id, version)
                          WHERE (NOT (EXISTS ( SELECT sv2.global_id
                                   FROM (sdm.vw_version sv2
                                     JOIN sdm.compatibility c2 ON ((c2.parent_software_version_id = sv2.id)))
                                  WHERE ((t.global_id = sv2.global_id) AND (t.version = sv2.version) AND (c2.child_software_version_id = sv.id)))))) a
                  WHERE (EXISTS ( SELECT
                           FROM ((sdm.compatibility c2
                             JOIN sdm.vw_version sv2 ON ((c2.parent_software_version_id = sv2.id)))
                             JOIN sdm.vw_version sv3 ON ((c2.child_software_version_id = sv3.id)))
                          WHERE ((a.global_id = sv2.global_id) AND (sv.global_id = sv3.global_id)))))))
        )
 SELECT cte.software_version_id,
    cte.parent_software_version_id,
    cte.origin_software_version_id,
    cte.version,
    cte.parent_version,
    cte.origin_version,
    cte.software_id,
    cte.global_id,
    cte.parent_software_id,
    cte.parent_global_id,
    cte.origin_global_id,
    cte.software_name,
    cte.parent_software_name,
    cte.version_name,
    cte.parent_version_name,
    cte.version_guid,
    cte.parent_version_guid,
    cte.tested,
    cte.lvl,
    cte.version_names,
    cte.versions,
    cte.global_ids,
    cte.software_names,
    cte.compatibilities
   FROM cte;


--
-- Name: allow_list; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.allow_list (
    serial_number text NOT NULL,
    maturity text NOT NULL,
    updated_by text,
    updated_on timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    active boolean NOT NULL,
    eligible_to_upgrade boolean NOT NULL
);


--
-- Name: TABLE allow_list; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.allow_list IS 'This table is used to manually add serial numbers of Axia to which an update/upgrade should be distributed.';


--
-- Name: COLUMN allow_list.serial_number; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.allow_list.serial_number IS 'Serial number of Axia instrument.';


--
-- Name: COLUMN allow_list.maturity; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.allow_list.maturity IS 'The identifier of the maturity for distribution.';


--
-- Name: COLUMN allow_list.updated_by; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.allow_list.updated_by IS 'Name of logged user from MyMicroscope portal.';


--
-- Name: COLUMN allow_list.updated_on; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.allow_list.updated_on IS 'Date of record insertion.';


--
-- Name: COLUMN allow_list.active; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.allow_list.active IS 'This flag indicates if the given rule is active (true) or inactive (false).';


--
-- Name: COLUMN allow_list.eligible_to_upgrade; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.allow_list.eligible_to_upgrade IS 'Flag whether the instrument is eligible to get also upgrades not only updates.';


--
-- Name: bundle; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.bundle (
    id integer NOT NULL,
    code_name text NOT NULL,
    name text NOT NULL,
    global_id text NOT NULL
);


--
-- Name: TABLE bundle; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.bundle IS 'This table contains all bundles of software.';


--
-- Name: COLUMN bundle.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.bundle.id IS 'Primary key.';


--
-- Name: COLUMN bundle.code_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.bundle.code_name IS 'Unique code name of the bundle (used for referencing from code).';


--
-- Name: COLUMN bundle.name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.bundle.name IS 'Display name of the bundle (used for frontends).';


--
-- Name: COLUMN bundle.global_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.bundle.global_id IS 'A system-wide unique global ID of the software bundle that allows to unambiguously identify the bundle across systems.';


--
-- Name: bundle_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.bundle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bundle_id_seq; Type: SEQUENCE OWNED BY; Schema: sdm; Owner: -
--

ALTER SEQUENCE sdm.bundle_id_seq OWNED BY sdm.bundle.id;


--
-- Name: bundle_version; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.bundle_version (
    id integer NOT NULL,
    version text NOT NULL,
    version_name text NOT NULL,
    bundle_id integer NOT NULL
);


--
-- Name: TABLE bundle_version; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.bundle_version IS 'This table defines various versions of software bundles.';


--
-- Name: COLUMN bundle_version.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.bundle_version.id IS 'Primary key.';


--
-- Name: COLUMN bundle_version.version; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.bundle_version.version IS 'The version number of the bundle.';


--
-- Name: COLUMN bundle_version.version_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.bundle_version.version_name IS 'The "business name" of the software bundle version, intended for display purposes. Normally it should be something like a concatenation of bndle name and its version but in fact it can be any text.';


--
-- Name: COLUMN bundle_version.bundle_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.bundle_version.bundle_id IS 'Foreign key: relation to the bundle.';


--
-- Name: bundle_version_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.bundle_version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bundle_version_id_seq; Type: SEQUENCE OWNED BY; Schema: sdm; Owner: -
--

ALTER SEQUENCE sdm.bundle_version_id_seq OWNED BY sdm.bundle_version.id;


--
-- Name: compatibility_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.compatibility_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: compatibility_id_seq; Type: SEQUENCE OWNED BY; Schema: sdm; Owner: -
--

ALTER SEQUENCE sdm.compatibility_id_seq OWNED BY sdm.compatibility.id;


--
-- Name: compatibility_source; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.compatibility_source (
    compatibility_id integer NOT NULL,
    source_id integer NOT NULL,
    external_id text NOT NULL,
    last_checked_on timestamp with time zone DEFAULT now() NOT NULL,
    last_updated_on timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE compatibility_source; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.compatibility_source IS 'This table connects different sources with a compatibility item. In case compatibility has more sources then this table is used to merge the data and resolve duplicates and conflicts.';


--
-- Name: COLUMN compatibility_source.compatibility_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility_source.compatibility_id IS 'Reference to the compatibility relation.';


--
-- Name: COLUMN compatibility_source.source_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility_source.source_id IS 'Reference to the source of the compatibility.';


--
-- Name: COLUMN compatibility_source.external_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility_source.external_id IS 'The database identifier used by the source (should be unique within the given source).';


--
-- Name: COLUMN compatibility_source.last_checked_on; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility_source.last_checked_on IS 'The date and time when the source record has been checked for changes for the last time.';


--
-- Name: COLUMN compatibility_source.last_updated_on; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.compatibility_source.last_updated_on IS 'The date and time when the target record has been last updated based on the data in the source record.';


--
-- Name: contract_entitlement; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.contract_entitlement (
    serial_number text NOT NULL,
    contract_number integer NOT NULL,
    customer_id text NOT NULL,
    contract_type text NOT NULL,
    entitlement text NOT NULL,
    domains text NOT NULL,
    service_type text NOT NULL,
    start_date timestamp with time zone NOT NULL,
    end_date timestamp with time zone NOT NULL,
    order_date timestamp with time zone NOT NULL,
    cancel_date timestamp with time zone,
    updated_on timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: TABLE contract_entitlement; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.contract_entitlement IS 'This table contains contract entitlement information from QAD.';


--
-- Name: COLUMN contract_entitlement.serial_number; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.serial_number IS 'The serial number of instrument.';


--
-- Name: COLUMN contract_entitlement.contract_number; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.contract_number IS 'Contract number.';


--
-- Name: COLUMN contract_entitlement.customer_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.customer_id IS 'Customer number.';


--
-- Name: COLUMN contract_entitlement.contract_type; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.contract_type IS 'Quote/Contract.';


--
-- Name: COLUMN contract_entitlement.entitlement; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.entitlement IS 'The entitlement column specifies what type of services the customer is entitled to.';


--
-- Name: COLUMN contract_entitlement.domains; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.domains IS 'The specific domain where the contract/quote was created.';


--
-- Name: COLUMN contract_entitlement.service_type; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.service_type IS 'The type of service contract purchased by the customer.';


--
-- Name: COLUMN contract_entitlement.start_date; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.start_date IS 'The date the contract/quote starts.';


--
-- Name: COLUMN contract_entitlement.end_date; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.end_date IS 'The date the contract/quote expires.';


--
-- Name: COLUMN contract_entitlement.order_date; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.order_date IS 'The date the customer system was ordered.';


--
-- Name: COLUMN contract_entitlement.cancel_date; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.cancel_date IS 'The date the contract was canceled .';


--
-- Name: COLUMN contract_entitlement.updated_on; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.contract_entitlement.updated_on IS 'Timestamp of record last update.';


--
-- Name: error; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.error (
    id integer NOT NULL,
    source_id integer NOT NULL,
    reporter text NOT NULL,
    type text NOT NULL,
    operation text NOT NULL,
    entity text NOT NULL,
    record text NOT NULL,
    detail text NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    source_code_name text NOT NULL
);


--
-- Name: TABLE error; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.error IS 'Various SDM components may report errors in this table related to processing data from external sources.';


--
-- Name: COLUMN error.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error.id IS 'Primary key.';


--
-- Name: COLUMN error.source_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error.source_id IS 'Reference to the source.';


--
-- Name: COLUMN error.reporter; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error.reporter IS 'Name of the module that reported the error.';


--
-- Name: COLUMN error.type; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error.type IS 'Type of the reported error.';


--
-- Name: COLUMN error.operation; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error.operation IS 'Description of the operation within which the error occurred.';


--
-- Name: COLUMN error.entity; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error.entity IS 'Name of the entity (table) in the source system, to which the error relates.';


--
-- Name: COLUMN error.record; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error.record IS 'Identification (primary key) of the source record that caused the error.';


--
-- Name: COLUMN error.detail; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error.detail IS 'Detailed information about the error (free text or JSON).';


--
-- Name: COLUMN error."timestamp"; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error."timestamp" IS 'Date and time when the error was reported.';


--
-- Name: COLUMN error.source_code_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.error.source_code_name IS 'Code name of the source.';


--
-- Name: error_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.error_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: error_id_seq; Type: SEQUENCE OWNED BY; Schema: sdm; Owner: -
--

ALTER SEQUENCE sdm.error_id_seq OWNED BY sdm.error.id;


--
-- Name: mapping_software_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.mapping_software_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: release_type_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.release_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: release_type; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.release_type (
    id integer DEFAULT nextval('sdm.release_type_id_seq'::regclass) NOT NULL,
    code_name text NOT NULL,
    name text NOT NULL,
    weight integer NOT NULL
);


--
-- Name: TABLE release_type; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.release_type IS 'LOV with the types of software version releases.';


--
-- Name: COLUMN release_type.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.release_type.id IS 'Primary key';


--
-- Name: COLUMN release_type.code_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.release_type.code_name IS 'Unique code name of the software version release type (used for referencing in code).';


--
-- Name: COLUMN release_type.name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.release_type.name IS 'Display name of the software version release type.';


--
-- Name: COLUMN release_type.weight; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.release_type.weight IS 'The weight of the release type for purpose of "significance" comparisons.';


--
-- Name: software_bundle; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.software_bundle (
    bundle_id integer NOT NULL,
    software_id integer NOT NULL
);


--
-- Name: TABLE software_bundle; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.software_bundle IS 'This table defines what software belongs to which bundles (M:N relation between bundle and software).';


--
-- Name: COLUMN software_bundle.bundle_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_bundle.bundle_id IS 'Foreign key: Reference to bundle definition. Part of unique primary key.';


--
-- Name: COLUMN software_bundle.software_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_bundle.software_id IS 'Foreign key: Reference to the software. Part of unique primary key.';


--
-- Name: software_bundle_version; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.software_bundle_version (
    bundle_version_id integer NOT NULL,
    software_version_id integer NOT NULL
);


--
-- Name: TABLE software_bundle_version; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.software_bundle_version IS 'This table defines what software version belongs to which bundle versions (M:N relation between bundle version and software version).';


--
-- Name: COLUMN software_bundle_version.bundle_version_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_bundle_version.bundle_version_id IS 'Foreign key: Reference to the bundle version.';


--
-- Name: COLUMN software_bundle_version.software_version_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_bundle_version.software_version_id IS 'Foreign key: Reference to the software version.';


--
-- Name: software_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.software_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: software_id_seq; Type: SEQUENCE OWNED BY; Schema: sdm; Owner: -
--

ALTER SEQUENCE sdm.software_id_seq OWNED BY sdm.software.id;


--
-- Name: software_maturity_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.software_maturity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: software_maturity; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.software_maturity (
    id integer DEFAULT nextval('sdm.software_maturity_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    relevant boolean NOT NULL,
    code_name text NOT NULL,
    weight integer NOT NULL,
    msa_name character varying(15)
);


--
-- Name: TABLE software_maturity; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.software_maturity IS 'LOV with different levels of maturity of software versions.';


--
-- Name: COLUMN software_maturity.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_maturity.id IS 'Primary key';


--
-- Name: COLUMN software_maturity.name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_maturity.name IS 'Display name of the maturity.';


--
-- Name: COLUMN software_maturity.relevant; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_maturity.relevant IS 'Flag if the given maturity is relevant for the SDM (FALSE = ignore software versions with this maturity).';


--
-- Name: COLUMN software_maturity.code_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_maturity.code_name IS 'Unique code name of the maturity (used for referencing in code).';


--
-- Name: COLUMN software_maturity.weight; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_maturity.weight IS 'The weight of the maturity for purpose of "significance" comparisons.';


--
-- Name: COLUMN software_maturity.msa_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_maturity.msa_name IS 'Identification of maturity used in MSA.';


--
-- Name: software_source; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.software_source (
    software_id integer NOT NULL,
    source_id integer NOT NULL,
    external_id text NOT NULL,
    last_checked_on timestamp with time zone DEFAULT now() NOT NULL,
    last_updated_on timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE software_source; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.software_source IS 'This table connects different sources with a software item. In case a software has more sources then this table is used to merge the data and resolve duplicates and conflicts.';


--
-- Name: COLUMN software_source.software_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_source.software_id IS 'Reference to the software.';


--
-- Name: COLUMN software_source.source_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_source.source_id IS 'Reference to the source of the software';


--
-- Name: COLUMN software_source.external_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_source.external_id IS 'The database identifier used by the source (should be unique within the given source).';


--
-- Name: COLUMN software_source.last_checked_on; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_source.last_checked_on IS 'The date and time when the source record has been checked for changes for the last time.';


--
-- Name: COLUMN software_source.last_updated_on; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_source.last_updated_on IS 'The date and time when the target record has been last updated based on the data in the source record.';


--
-- Name: software_status_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.software_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: software_status; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.software_status (
    id integer DEFAULT nextval('sdm.software_status_id_seq'::regclass) NOT NULL,
    code_name text NOT NULL,
    name text NOT NULL
);


--
-- Name: TABLE software_status; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.software_status IS 'LOV with the status of the software';


--
-- Name: COLUMN software_status.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_status.id IS 'Primary key';


--
-- Name: COLUMN software_status.code_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_status.code_name IS 'Unique code name of the status of the software (used for referencing in code).';


--
-- Name: COLUMN software_status.name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_status.name IS 'Display name of the status of the software.';


--
-- Name: software_type_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.software_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: software_type; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.software_type (
    id integer DEFAULT nextval('sdm.software_type_id_seq'::regclass) NOT NULL,
    code_name text NOT NULL,
    name text NOT NULL
);


--
-- Name: TABLE software_type; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.software_type IS 'LOV with the type of software.';


--
-- Name: COLUMN software_type.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_type.id IS 'Primary key';


--
-- Name: COLUMN software_type.code_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_type.code_name IS 'Unique code name of the type of the software (used for referencing in code).';


--
-- Name: COLUMN software_type.name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_type.name IS 'Display name of the type of the software.';


--
-- Name: software_version_source; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.software_version_source (
    software_version_id integer NOT NULL,
    source_id integer NOT NULL,
    revision integer NOT NULL,
    obsolete boolean NOT NULL,
    last_checked_on timestamp with time zone DEFAULT now() NOT NULL,
    last_updated_on timestamp with time zone DEFAULT now() NOT NULL,
    external_id text NOT NULL
);


--
-- Name: TABLE software_version_source; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.software_version_source IS 'This table connects different sources with a software version item. In case a software version has more sources then this table is used to merge the data and resolve duplicates and conflicts.';


--
-- Name: COLUMN software_version_source.software_version_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version_source.software_version_id IS 'Reference to the software version.';


--
-- Name: COLUMN software_version_source.source_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version_source.source_id IS 'Reference to the source of the software version.';


--
-- Name: COLUMN software_version_source.revision; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version_source.revision IS 'Revision of the source record (used to detect updates).';


--
-- Name: COLUMN software_version_source.obsolete; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version_source.obsolete IS 'Flag if the relation source is obsolete (the source record may have been replaced with another one).';


--
-- Name: COLUMN software_version_source.last_checked_on; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version_source.last_checked_on IS 'The date and time when the source record has been checked for changes for the last time.';


--
-- Name: COLUMN software_version_source.last_updated_on; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version_source.last_updated_on IS 'The date and time when the target record has been last updated based on the data in source record.';


--
-- Name: COLUMN software_version_source.external_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.software_version_source.external_id IS 'The database identifier used by the source (should be unique within the given source).';


--
-- Name: source; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.source (
    id integer NOT NULL,
    code_name text NOT NULL,
    description text,
    source_type_id integer NOT NULL
);


--
-- Name: TABLE source; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.source IS 'This table defines various sources of the data in SDM.';


--
-- Name: COLUMN source.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.source.id IS 'Primary key';


--
-- Name: COLUMN source.code_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.source.code_name IS 'Unique code name of the source';


--
-- Name: COLUMN source.description; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.source.description IS 'Display name of the source';


--
-- Name: COLUMN source.source_type_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.source.source_type_id IS 'The type of the source.';


--
-- Name: source_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.source_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_id_seq; Type: SEQUENCE OWNED BY; Schema: sdm; Owner: -
--

ALTER SEQUENCE sdm.source_id_seq OWNED BY sdm.source.id;


--
-- Name: sourcetype_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.sourcetype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: source_type; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.source_type (
    id integer DEFAULT nextval('sdm.sourcetype_id_seq'::regclass) NOT NULL,
    code_name text NOT NULL,
    name text NOT NULL
);


--
-- Name: TABLE source_type; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.source_type IS 'This table defines the different types of data sources, while the "source" table contains their instances.';


--
-- Name: COLUMN source_type.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.source_type.id IS 'Primary key.';


--
-- Name: COLUMN source_type.code_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.source_type.code_name IS 'Unique code name of the source type, which can be used in code.';


--
-- Name: COLUMN source_type.name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.source_type.name IS 'The descriptive name of the type of the source.';


--
-- Name: vw_compatibilities; Type: VIEW; Schema: sdm; Owner: -
--

CREATE VIEW sdm.vw_compatibilities AS
 SELECT sp.id AS parent_software_id,
    sp.name AS parent_software_name,
    sp.global_id AS parent_software_global_id,
    c.parent_software_version_id,
    svp.version AS parent_software_version,
    sc.id AS child_software_id,
    sc.name AS child_software_name,
    sc.global_id AS child_software_global_id,
    c.child_software_version_id,
    svc.version AS child_software_version,
    c.tested
   FROM ((((sdm.compatibility c
     JOIN sdm.software_version svc ON ((c.child_software_version_id = svc.id)))
     JOIN sdm.software sc ON ((svc.software_id = sc.id)))
     JOIN sdm.software_version svp ON ((c.parent_software_version_id = svp.id)))
     JOIN sdm.software sp ON ((svp.software_id = sp.id)));


--
-- Name: vw_dependencies; Type: VIEW; Schema: sdm; Owner: -
--

CREATE VIEW sdm.vw_dependencies AS
 WITH RECURSIVE cte AS (
         SELECT sv.id AS software_version_id,
            sv.id AS parent_software_version_id,
            sv.id AS origin_software_version_id,
            sv.version,
            sv.version AS parent_version,
            sv.version AS origin_version,
            s.id AS software_id,
            s.global_id,
            s.id AS parent_software_id,
            s.global_id AS parent_global_id,
            s.global_id AS origin_global_id,
            s.name AS software_name,
            s.name AS parent_software_name,
            sv.version_name,
            sv.version_name AS parent_version_name,
            sv.guid AS version_guid,
            sv.guid AS parent_version_guid,
            true AS tested,
            1 AS lvl,
            ARRAY[sv.version_name] AS version_names,
            ARRAY[sv.version] AS versions,
            ARRAY[s.global_id] AS global_ids,
            ARRAY[s.name] AS software_names,
            ARRAY[ROW(s.global_id, sv.version)::sdm.t_check_compatibility] AS compatibilities
           FROM (sdm.software_version sv
             JOIN sdm.software s ON ((sv.software_id = s.id)))
          WHERE (EXISTS ( SELECT 1
                   FROM sdm.compatibility c2
                  WHERE (sv.id = c2.parent_software_version_id)))
        UNION ALL
         SELECT sv.id AS software_version_id,
            cte_1.software_version_id AS parent_software_version_id,
            cte_1.origin_software_version_id,
            sv.version,
            cte_1.version AS parent_version,
            cte_1.origin_version,
            s.id AS software_id,
            s.global_id,
            cte_1.software_id AS parent_software_id,
            cte_1.global_id AS parent_global_id,
            cte_1.origin_global_id,
            s.name AS software_name,
            cte_1.software_name AS parent_software_name,
            sv.version_name,
            cte_1.version_name AS parent_version_name,
            sv.guid AS version_guid,
            cte_1.version_guid AS parent_version_guid,
            c.tested,
            (cte_1.lvl + 1) AS lvl,
            (cte_1.version_names || sv.version_name) AS version_names,
            (cte_1.versions || sv.version) AS versions,
            (cte_1.global_ids || s.global_id) AS global_ids,
            (cte_1.software_names || s.name) AS software_names,
            (cte_1.compatibilities || ARRAY[ROW(s.global_id, sv.version)::sdm.t_check_compatibility])
           FROM (((cte cte_1
             JOIN sdm.compatibility c ON ((c.parent_software_version_id = cte_1.software_version_id)))
             JOIN sdm.software_version sv ON ((c.child_software_version_id = sv.id)))
             JOIN sdm.software s ON ((sv.software_id = s.id)))
        )
 SELECT cte.software_version_id,
    cte.parent_software_version_id,
    cte.origin_software_version_id,
    cte.version,
    cte.parent_version,
    cte.origin_version,
    cte.software_id,
    cte.global_id,
    cte.parent_software_id,
    cte.parent_global_id,
    cte.origin_global_id,
    cte.software_name,
    cte.parent_software_name,
    cte.version_name,
    cte.parent_version_name,
    cte.version_guid,
    cte.parent_version_guid,
    cte.tested,
    cte.lvl,
    cte.version_names,
    cte.versions,
    cte.global_ids,
    cte.software_names,
    cte.compatibilities
   FROM cte;


--
-- Name: vw_filtered_dependencies; Type: VIEW; Schema: sdm; Owner: -
--

CREATE VIEW sdm.vw_filtered_dependencies AS
 WITH RECURSIVE cte AS (
         SELECT sv.id AS software_version_id,
            sv.id AS parent_software_version_id,
            sv.id AS origin_software_version_id,
            sv.version,
            sv.version AS parent_version,
            sv.version AS origin_version,
            sv.software_id,
            sv.global_id,
            sv.software_id AS parent_software_id,
            sv.global_id AS parent_global_id,
            sv.global_id AS origin_global_id,
            sv.software_name,
            sv.software_name AS parent_software_name,
            sv.version_name,
            sv.version_name AS parent_version_name,
            sv.guid AS version_guid,
            sv.guid AS parent_version_guid,
            true AS tested,
            1 AS lvl,
            ARRAY[sv.version_name] AS version_names,
            ARRAY[sv.version] AS versions,
            ARRAY[sv.global_id] AS global_ids,
            ARRAY[sv.software_name] AS software_names,
            ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility] AS compatibilities
           FROM sdm.vw_version sv
          WHERE (EXISTS ( SELECT 1
                   FROM sdm.compatibility c2
                  WHERE (sv.id = c2.parent_software_version_id)))
        UNION ALL
         SELECT sv.id AS software_version_id,
            cte_1.software_version_id AS parent_software_version_id,
            cte_1.origin_software_version_id,
            sv.version,
            cte_1.version AS parent_version,
            cte_1.origin_version,
            sv.id AS software_id,
            sv.global_id,
            cte_1.software_id AS parent_software_id,
            cte_1.global_id AS parent_global_id,
            cte_1.origin_global_id,
            sv.software_name,
            cte_1.software_name AS parent_software_name,
            sv.version_name,
            cte_1.version_name AS parent_version_name,
            sv.guid AS version_guid,
            cte_1.version_guid AS parent_version_guid,
            (c.tested AND cte_1.tested),
            (cte_1.lvl + 1) AS lvl,
            (cte_1.version_names || sv.version_name) AS version_names,
            (cte_1.versions || sv.version) AS versions,
            (cte_1.global_ids || sv.global_id) AS global_ids,
            (cte_1.software_names || sv.software_name) AS software_names,
            (cte_1.compatibilities || ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility])
           FROM ((cte cte_1
             JOIN sdm.compatibility c ON ((c.parent_software_version_id = cte_1.software_version_id)))
             JOIN sdm.vw_version sv ON ((c.child_software_version_id = sv.id)))
          WHERE (NOT (EXISTS ( SELECT 1
                   FROM ( SELECT t.global_id
                           FROM unnest(cte_1.compatibilities) t(global_id, version)
                          WHERE (NOT (EXISTS ( SELECT sv2.global_id
                                   FROM (sdm.vw_version sv2
                                     JOIN sdm.compatibility c2 ON ((c2.parent_software_version_id = sv2.id)))
                                  WHERE ((t.global_id = sv2.global_id) AND (t.version = sv2.version) AND (c2.child_software_version_id = sv.id)))))) a
                  WHERE (EXISTS ( SELECT
                           FROM ((sdm.compatibility c2
                             JOIN sdm.vw_version sv2 ON ((c2.parent_software_version_id = sv2.id)))
                             JOIN sdm.vw_version sv3 ON ((c2.child_software_version_id = sv3.id)))
                          WHERE ((a.global_id = sv2.global_id) AND (sv.global_id = sv3.global_id)))))))
        )
 SELECT cte.software_version_id,
    cte.parent_software_version_id,
    cte.origin_software_version_id,
    cte.version,
    cte.parent_version,
    cte.origin_version,
    cte.software_id,
    cte.global_id,
    cte.parent_software_id,
    cte.parent_global_id,
    cte.origin_global_id,
    cte.software_name,
    cte.parent_software_name,
    cte.version_name,
    cte.parent_version_name,
    cte.version_guid,
    cte.parent_version_guid,
    cte.tested,
    cte.lvl,
    cte.version_names,
    cte.versions,
    cte.global_ids,
    cte.software_names,
    cte.compatibilities
   FROM cte;


--
-- Name: vw_filtered_dependencies_v2; Type: VIEW; Schema: sdm; Owner: -
--

CREATE VIEW sdm.vw_filtered_dependencies_v2 AS
 WITH RECURSIVE cte AS (
         SELECT sv.id AS software_version_id,
            sv.id AS parent_software_version_id,
            sv.id AS origin_software_version_id,
            sv.version,
            sv.version AS parent_version,
            sv.version AS origin_version,
            sv.software_id,
            sv.global_id,
            sv.software_id AS parent_software_id,
            sv.global_id AS parent_global_id,
            sv.global_id AS origin_global_id,
            sv.software_name,
            sv.software_name AS parent_software_name,
            sv.version_name,
            sv.version_name AS parent_version_name,
            sv.guid AS version_guid,
            sv.guid AS parent_version_guid,
            true AS tested,
            1 AS lvl,
            ARRAY[sv.version_name] AS version_names,
            ARRAY[sv.version] AS versions,
            ARRAY[sv.global_id] AS global_ids,
            ARRAY[sv.software_name] AS software_names,
            ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility] AS compatibilities
           FROM sdm.vw_version sv
          WHERE (EXISTS ( SELECT 1
                   FROM sdm.compatibility c2
                  WHERE (sv.id = c2.parent_software_version_id)))
        UNION ALL
         SELECT sv.id AS software_version_id,
            cte_1.software_version_id AS parent_software_version_id,
            cte_1.origin_software_version_id,
            sv.version,
            cte_1.version AS parent_version,
            cte_1.origin_version,
            sv.id AS software_id,
            sv.global_id,
            cte_1.software_id AS parent_software_id,
            cte_1.global_id AS parent_global_id,
            cte_1.origin_global_id,
            sv.software_name,
            cte_1.software_name AS parent_software_name,
            sv.version_name,
            cte_1.version_name AS parent_version_name,
            sv.guid AS version_guid,
            cte_1.version_guid AS parent_version_guid,
            (c.tested AND cte_1.tested),
            (cte_1.lvl + 1) AS lvl,
            (cte_1.version_names || sv.version_name) AS version_names,
            (cte_1.versions || sv.version) AS versions,
            (cte_1.global_ids || sv.global_id) AS global_ids,
            (cte_1.software_names || sv.software_name) AS software_names,
            (cte_1.compatibilities || ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility])
           FROM ((cte cte_1
             JOIN sdm.compatibility c ON ((c.parent_software_version_id = cte_1.software_version_id)))
             JOIN sdm.vw_version sv ON ((c.child_software_version_id = sv.id)))
        )
 SELECT cte.software_version_id,
    cte.parent_software_version_id,
    cte.origin_software_version_id,
    cte.version,
    cte.parent_version,
    cte.origin_version,
    cte.software_id,
    cte.global_id,
    cte.parent_software_id,
    cte.parent_global_id,
    cte.origin_global_id,
    cte.software_name,
    cte.parent_software_name,
    cte.version_name,
    cte.parent_version_name,
    cte.version_guid,
    cte.parent_version_guid,
    cte.tested,
    cte.lvl,
    cte.version_names,
    cte.versions,
    cte.global_ids,
    cte.software_names,
    cte.compatibilities
   FROM cte;


--
-- Name: vw_filtered_dependencies_v3; Type: VIEW; Schema: sdm; Owner: -
--

CREATE VIEW sdm.vw_filtered_dependencies_v3 AS
 WITH RECURSIVE cte AS (
         SELECT sv.id AS software_version_id,
            sv.id AS parent_software_version_id,
            sv.id AS origin_software_version_id,
            sv.version,
            sv.version AS parent_version,
            sv.version AS origin_version,
            sv.software_id,
            sv.global_id,
            sv.software_id AS parent_software_id,
            sv.global_id AS parent_global_id,
            sv.global_id AS origin_global_id,
            sv.software_name,
            sv.software_name AS parent_software_name,
            sv.version_name,
            sv.version_name AS parent_version_name,
            sv.guid AS version_guid,
            sv.guid AS parent_version_guid,
            true AS tested,
            1 AS lvl,
            ARRAY[sv.version_name] AS version_names,
            ARRAY[sv.version] AS versions,
            ARRAY[sv.global_id] AS global_ids,
            ARRAY[sv.software_name] AS software_names,
            ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility] AS compatibilities
           FROM sdm.vw_version sv
          WHERE (EXISTS ( SELECT 1
                   FROM sdm.compatibility c2
                  WHERE (sv.id = c2.parent_software_version_id)))
        UNION ALL
         SELECT sv.id AS software_version_id,
            cte_1.software_version_id AS parent_software_version_id,
            cte_1.origin_software_version_id,
            sv.version,
            cte_1.version AS parent_version,
            cte_1.origin_version,
            sv.id AS software_id,
            sv.global_id,
            cte_1.software_id AS parent_software_id,
            cte_1.global_id AS parent_global_id,
            cte_1.origin_global_id,
            sv.software_name,
            cte_1.software_name AS parent_software_name,
            sv.version_name,
            cte_1.version_name AS parent_version_name,
            sv.guid AS version_guid,
            cte_1.version_guid AS parent_version_guid,
            (c.tested AND cte_1.tested AND COALESCE(s.tested, true)),
            (cte_1.lvl + 1) AS lvl,
            (cte_1.version_names || sv.version_name) AS version_names,
            (cte_1.versions || sv.version) AS versions,
            (cte_1.global_ids || sv.global_id) AS global_ids,
            (cte_1.software_names || sv.software_name) AS software_names,
            (cte_1.compatibilities || ARRAY[ROW(sv.global_id, sv.version)::sdm.t_check_compatibility])
           FROM (((cte cte_1
             JOIN sdm.compatibility c ON ((c.parent_software_version_id = cte_1.software_version_id)))
             JOIN sdm.vw_version sv ON ((c.child_software_version_id = sv.id)))
             LEFT JOIN LATERAL ( SELECT (min((cc.tested)::integer))::boolean AS tested
                   FROM ( SELECT c2.tested,
                            c2.child_software_version_id
                           FROM (sdm.vw_version sv2
                             JOIN sdm.compatibility c2 ON ((c2.parent_software_version_id = sv2.id)))
                          WHERE ((c2.child_software_version_id = sv.id) AND ((sv2.global_id, sv2.version) IN ( SELECT t.global_id,
                                    t.version
                                   FROM unnest(cte_1.compatibilities) t(global_id, version))))) cc
                  GROUP BY cc.child_software_version_id) s ON (true))
          WHERE (NOT (EXISTS ( SELECT 1
                   FROM ( SELECT t.global_id
                           FROM unnest(cte_1.compatibilities) t(global_id, version)
                          WHERE (NOT (EXISTS ( SELECT sv2.global_id
                                   FROM (sdm.vw_version sv2
                                     JOIN sdm.compatibility c2 ON ((c2.parent_software_version_id = sv2.id)))
                                  WHERE ((t.global_id = sv2.global_id) AND (t.version = sv2.version) AND (c2.child_software_version_id = sv.id)))))) a
                  WHERE (EXISTS ( SELECT
                           FROM ((sdm.compatibility c2
                             JOIN sdm.vw_version sv2 ON ((c2.parent_software_version_id = sv2.id)))
                             JOIN sdm.vw_version sv3 ON ((c2.child_software_version_id = sv3.id)))
                          WHERE ((a.global_id = sv2.global_id) AND (sv.global_id = sv3.global_id)))))))
        )
 SELECT cte.software_version_id,
    cte.parent_software_version_id,
    cte.origin_software_version_id,
    cte.version,
    cte.parent_version,
    cte.origin_version,
    cte.software_id,
    cte.global_id,
    cte.parent_software_id,
    cte.parent_global_id,
    cte.origin_global_id,
    cte.software_name,
    cte.parent_software_name,
    cte.version_name,
    cte.parent_version_name,
    cte.version_guid,
    cte.parent_version_guid,
    cte.tested,
    cte.lvl,
    cte.version_names,
    cte.versions,
    cte.global_ids,
    cte.software_names,
    cte.compatibilities
   FROM cte;


--
-- Name: xformreleasetype_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.xformreleasetype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: xform_release_type; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.xform_release_type (
    id integer DEFAULT nextval('sdm.xformreleasetype_id_seq'::regclass) NOT NULL,
    source_id integer NOT NULL,
    source_release_type text NOT NULL,
    target_release_type_id integer NOT NULL
);


--
-- Name: TABLE xform_release_type; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.xform_release_type IS 'This table is used to transform the software release types used in data sources to the release types used in SDM.';


--
-- Name: COLUMN xform_release_type.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_release_type.id IS 'Primary key.';


--
-- Name: COLUMN xform_release_type.source_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_release_type.source_id IS 'Reference to source.';


--
-- Name: COLUMN xform_release_type.source_release_type; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_release_type.source_release_type IS 'Source''s identifier (name) of the release type.';


--
-- Name: COLUMN xform_release_type.target_release_type_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_release_type.target_release_type_id IS 'Corresponding release type in the SDM.';


--
-- Name: xform_software; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.xform_software (
    id integer DEFAULT nextval('sdm.mapping_software_id_seq'::regclass) NOT NULL,
    source_id integer,
    input_name text NOT NULL,
    global_name text NOT NULL,
    global_id text NOT NULL,
    software_type_id integer NOT NULL,
    regular boolean NOT NULL,
    source_type_id integer,
    category integer,
    "order" integer NOT NULL,
    apply_for sdm.apply_for DEFAULT 'none'::text NOT NULL
);


--
-- Name: TABLE xform_software; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.xform_software IS 'This table is used to transform loosely defined names of software to their normalized names and also to unique global identifiers.';


--
-- Name: COLUMN xform_software.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.id IS 'Primary key.';


--
-- Name: COLUMN xform_software.source_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.source_id IS 'Relation to source instance, to which the mapping record is relevat. NULL value means that the record is valid for any source instance';


--
-- Name: COLUMN xform_software.input_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.input_name IS 'The name of the software as it is used in the given source.';


--
-- Name: COLUMN xform_software.global_name; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.global_name IS 'The name of the software in the SDM (it should be a globally used name).';


--
-- Name: COLUMN xform_software.global_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.global_id IS 'Unique and global identifier of the software (for the SDM as well as outer systems).';


--
-- Name: COLUMN xform_software.software_type_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.software_type_id IS 'The type of the software.';


--
-- Name: COLUMN xform_software.regular; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.regular IS 'Determines, if the input_name is to be evaluated as regular expression (1) or as string with potential wildcards (0).';


--
-- Name: COLUMN xform_software.source_type_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.source_type_id IS 'Relation to source type, to which the mapping record is relevat. NULL value means that the record is valid for any source type';


--
-- Name: COLUMN xform_software.category; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.category IS 'Optional value of the software category in the data source. NULL value means that this criteria is ignored.';


--
-- Name: COLUMN xform_software."order"; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software."order" IS 'The order, in which the rule is evaluated if there exists more rules for the same software (or source).';


--
-- Name: COLUMN xform_software.apply_for; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software.apply_for IS 'This column indicates in what conditions the rule can apply: ''none'' (never), ''all'' (always), ''batch_only'' (only in batch mode), ''selective_only'' (only in selective mode).';


--
-- Name: xformsoftwarematurity_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.xformsoftwarematurity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- Name: xform_software_maturity; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.xform_software_maturity (
    id integer DEFAULT nextval('sdm.xformsoftwarematurity_id_seq'::regclass) NOT NULL,
    source_id integer NOT NULL,
    source_maturity_id integer NOT NULL,
    target_maturity_id integer NOT NULL
);


--
-- Name: TABLE xform_software_maturity; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.xform_software_maturity IS 'This table is used to transform software maturity used in data sources to the maturity used in SDM.';


--
-- Name: COLUMN xform_software_maturity.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_maturity.id IS 'Primary key.';


--
-- Name: COLUMN xform_software_maturity.source_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_maturity.source_id IS 'Reference to source.';


--
-- Name: COLUMN xform_software_maturity.source_maturity_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_maturity.source_maturity_id IS 'Source''s identifier of the maturity.';


--
-- Name: COLUMN xform_software_maturity.target_maturity_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_maturity.target_maturity_id IS 'Corresponding maturity in the SDM.';


--
-- Name: xform_software_version; Type: TABLE; Schema: sdm; Owner: -
--

CREATE TABLE sdm.xform_software_version (
    id integer NOT NULL,
    source_id integer,
    source_type_id integer,
    global_id text NOT NULL,
    "order" integer NOT NULL,
    extract_version_rule character(1) NOT NULL,
    extract_version_pattern text,
    extract_build_rule character(1) NOT NULL,
    extract_build_pattern text,
    build_version_rule1 text NOT NULL,
    build_version_rule2 text NOT NULL,
    build_version_rule3 text NOT NULL,
    build_version_rule4 text NOT NULL,
    comment text,
    apply_for sdm.apply_for DEFAULT 'none'::text NOT NULL
);


--
-- Name: TABLE xform_software_version; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON TABLE sdm.xform_software_version IS 'This table is used to transform loosely defined versions and builds of software versions to their normalized form.';


--
-- Name: COLUMN xform_software_version.id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.id IS 'Primary key.';


--
-- Name: COLUMN xform_software_version.source_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.source_id IS 'Relation to source instance, to which the mapping record is relevat. NULL value means that the record is valid for any source instance.';


--
-- Name: COLUMN xform_software_version.source_type_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.source_type_id IS 'Relation to source type, to which the mapping record is relevat. NULL value means that the record is valid for any source type.';


--
-- Name: COLUMN xform_software_version.global_id; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.global_id IS 'Unique and global identifier of the software (for the SDM as well as outer systems).';


--
-- Name: COLUMN xform_software_version."order"; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version."order" IS 'The order, in which the rule is evaluated if there exists more rules for the same software (or source).';


--
-- Name: COLUMN xform_software_version.extract_version_rule; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.extract_version_rule IS 'The rule used to extract tokens from "version" (''s''=static, ''r''=regular expression, ''i''=ignore).';


--
-- Name: COLUMN xform_software_version.extract_version_pattern; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.extract_version_pattern IS 'The pattern for the version rule evaluation based on the rule type: ''r''=regular expression, otherwise not used.';


--
-- Name: COLUMN xform_software_version.extract_build_rule; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.extract_build_rule IS 'The rule used to extract tokens from "build" (''s''=static, ''r''=regular expression, ''i''=ignore).';


--
-- Name: COLUMN xform_software_version.extract_build_pattern; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.extract_build_pattern IS 'The pattern for the build rule evaluation based on the rule type:  ''r''=regular expression, otherwise not used';


--
-- Name: COLUMN xform_software_version.build_version_rule1; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.build_version_rule1 IS 'Defines the rule how to build the first part of the normalized version. Allowed values: ''V1'', ''V2'' to ''Vn'', ''B1'', ''B2'' to ''Bn'', ''*'' and ''0''.';


--
-- Name: COLUMN xform_software_version.build_version_rule2; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.build_version_rule2 IS 'Defines the rule how to build the second part of the normalized version. Allowed values: ''V1'', ''V2'' to ''Vn'', ''B1'', ''B2'' to ''Bn'', ''*'' and ''0''.';


--
-- Name: COLUMN xform_software_version.build_version_rule3; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.build_version_rule3 IS 'Defines the rule how to build the third part of the normalized version. Allowed values: ''V1'', ''V2'' to ''Vn'', ''B1'', ''B2'' to ''Bn'', ''*'' and ''0''.';


--
-- Name: COLUMN xform_software_version.build_version_rule4; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.build_version_rule4 IS 'Defines the rule how to build the fourth part of the normalized version. Allowed values: ''V1'', ''V2'' to ''Vn'', ''B1'', ''B2'' to ''Bn'', ''*'' and ''0''.';


--
-- Name: COLUMN xform_software_version.comment; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.comment IS 'Optional comment, so humans can understand the rule too :).';


--
-- Name: COLUMN xform_software_version.apply_for; Type: COMMENT; Schema: sdm; Owner: -
--

COMMENT ON COLUMN sdm.xform_software_version.apply_for IS 'This column indicates in what conditions the rule can apply: ''none'' (never), ''all'' (always), ''batch_only'' (only in batch mode), ''selective_only'' (only in selective mode).';


--
-- Name: xform_software_version_id_seq; Type: SEQUENCE; Schema: sdm; Owner: -
--

CREATE SEQUENCE sdm.xform_software_version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: xform_software_version_id_seq; Type: SEQUENCE OWNED BY; Schema: sdm; Owner: -
--

ALTER SEQUENCE sdm.xform_software_version_id_seq OWNED BY sdm.xform_software_version.id;


--
-- Name: bundle id; Type: DEFAULT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.bundle ALTER COLUMN id SET DEFAULT nextval('sdm.bundle_id_seq'::regclass);


--
-- Name: bundle_version id; Type: DEFAULT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.bundle_version ALTER COLUMN id SET DEFAULT nextval('sdm.bundle_version_id_seq'::regclass);


--
-- Name: compatibility id; Type: DEFAULT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.compatibility ALTER COLUMN id SET DEFAULT nextval('sdm.compatibility_id_seq'::regclass);


--
-- Name: error id; Type: DEFAULT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.error ALTER COLUMN id SET DEFAULT nextval('sdm.error_id_seq'::regclass);


--
-- Name: software id; Type: DEFAULT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software ALTER COLUMN id SET DEFAULT nextval('sdm.software_id_seq'::regclass);


--
-- Name: source id; Type: DEFAULT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.source ALTER COLUMN id SET DEFAULT nextval('sdm.source_id_seq'::regclass);


--
-- Name: xform_software_version id; Type: DEFAULT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software_version ALTER COLUMN id SET DEFAULT nextval('sdm.xform_software_version_id_seq'::regclass);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    DROP CONSTRAINT IF EXISTS schema_migrations_pkey,ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: bundle bundle_code_name_key; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.bundle
    ADD CONSTRAINT bundle_code_name_key UNIQUE (code_name);


--
-- Name: bundle bundle_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.bundle
    ADD CONSTRAINT bundle_pk PRIMARY KEY (id);


--
-- Name: bundle_version bundleversion_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.bundle_version
    ADD CONSTRAINT bundleversion_pk PRIMARY KEY (id);


--
-- Name: compatibility compatibility_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.compatibility
    ADD CONSTRAINT compatibility_pk PRIMARY KEY (id);


--
-- Name: compatibility compatibility_software_uk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.compatibility
    ADD CONSTRAINT compatibility_software_uk UNIQUE (parent_software_version_id, child_software_version_id);


--
-- Name: compatibility_source compatibility_source_pkey; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.compatibility_source
    ADD CONSTRAINT compatibility_source_pkey PRIMARY KEY (compatibility_id, source_id);


--
-- Name: contract_entitlement contract_entitlement_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.contract_entitlement
    ADD CONSTRAINT contract_entitlement_pk PRIMARY KEY (serial_number);


--
-- Name: error error_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.error
    ADD CONSTRAINT error_pk PRIMARY KEY (id);


--
-- Name: xform_software mappingsoftware_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software
    ADD CONSTRAINT mappingsoftware_pk PRIMARY KEY (id);


--
-- Name: release_type release_type_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.release_type
    ADD CONSTRAINT release_type_pk PRIMARY KEY (id);


--
-- Name: allow_list serial_number_un; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.allow_list
    ADD CONSTRAINT serial_number_un UNIQUE (serial_number);


--
-- Name: software_bundle software_bundle_pkey; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_bundle
    ADD CONSTRAINT software_bundle_pkey PRIMARY KEY (bundle_id, software_id);


--
-- Name: software_bundle_version software_bundle_version_pkey; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_bundle_version
    ADD CONSTRAINT software_bundle_version_pkey PRIMARY KEY (bundle_version_id, software_version_id);


--
-- Name: software software_global_id_key; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software
    ADD CONSTRAINT software_global_id_key UNIQUE (global_id);


--
-- Name: software_maturity software_maturity_code_name_key; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_maturity
    ADD CONSTRAINT software_maturity_code_name_key UNIQUE (code_name);


--
-- Name: software_maturity software_maturity_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_maturity
    ADD CONSTRAINT software_maturity_pk PRIMARY KEY (id);


--
-- Name: software software_pkey; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software
    ADD CONSTRAINT software_pkey PRIMARY KEY (id);


--
-- Name: software_source software_source_pkey; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_source
    ADD CONSTRAINT software_source_pkey PRIMARY KEY (software_id, source_id);


--
-- Name: software_source software_source_un; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_source
    ADD CONSTRAINT software_source_un UNIQUE (source_id, external_id);


--
-- Name: software_status software_status_code_name_key; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_status
    ADD CONSTRAINT software_status_code_name_key UNIQUE (code_name);


--
-- Name: software_status software_status_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_status
    ADD CONSTRAINT software_status_pk PRIMARY KEY (id);


--
-- Name: software_type software_type_code_name_key; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_type
    ADD CONSTRAINT software_type_code_name_key UNIQUE (code_name);


--
-- Name: software_type software_type_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_type
    ADD CONSTRAINT software_type_pk PRIMARY KEY (id);


--
-- Name: software_version software_version_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_version
    ADD CONSTRAINT software_version_pk PRIMARY KEY (id);


--
-- Name: software_version_source software_version_source_pkey; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_version_source
    ADD CONSTRAINT software_version_source_pkey PRIMARY KEY (source_id, external_id, revision);


--
-- Name: source source_pkey; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.source
    ADD CONSTRAINT source_pkey PRIMARY KEY (id);


--
-- Name: source_type source_type_code_name_key; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.source_type
    ADD CONSTRAINT source_type_code_name_key UNIQUE (code_name);


--
-- Name: source_type sourcetype_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.source_type
    ADD CONSTRAINT sourcetype_pk PRIMARY KEY (id);


--
-- Name: xform_release_type xformreleasetype_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_release_type
    ADD CONSTRAINT xformreleasetype_pk PRIMARY KEY (id);


--
-- Name: xform_software xformsoftware_un; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software
    ADD CONSTRAINT xformsoftware_un UNIQUE (input_name, "order");


--
-- Name: xform_software_maturity xformsoftwarematurity_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software_maturity
    ADD CONSTRAINT xformsoftwarematurity_pk PRIMARY KEY (id);


--
-- Name: xform_software_version xformsoftwareversion_pk; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software_version
    ADD CONSTRAINT xformsoftwareversion_pk PRIMARY KEY (id);


--
-- Name: xform_software_version xformsoftwareversion_un; Type: CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software_version
    ADD CONSTRAINT xformsoftwareversion_un UNIQUE (global_id, "order");


--
-- Name: compatibility_childsoftwareversionid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX compatibility_childsoftwareversionid_idx ON sdm.compatibility USING btree (child_software_version_id);


--
-- Name: compatibility_parentsoftwareversionid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX compatibility_parentsoftwareversionid_idx ON sdm.compatibility USING btree (parent_software_version_id);


--
-- Name: compatibilitysource_compatibilityid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX compatibilitysource_compatibilityid_idx ON sdm.compatibility_source USING btree (compatibility_id);


--
-- Name: compatibilitysource_externalid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX compatibilitysource_externalid_idx ON sdm.compatibility_source USING btree (external_id);


--
-- Name: compatibilitysource_sourceid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX compatibilitysource_sourceid_idx ON sdm.compatibility_source USING btree (source_id);


--
-- Name: releasetype_codename_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX releasetype_codename_idx ON sdm.release_type USING btree (code_name);


--
-- Name: software_global_id_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE UNIQUE INDEX software_global_id_idx ON sdm.software USING btree (global_id);


--
-- Name: software_softwarestatusid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX software_softwarestatusid_idx ON sdm.software USING btree (software_status_id);


--
-- Name: software_softwaretypeid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX software_softwaretypeid_idx ON sdm.software USING btree (software_type_id);


--
-- Name: softwarebundle_bundleid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwarebundle_bundleid_idx ON sdm.software_bundle USING btree (bundle_id);


--
-- Name: softwarebundleversion_bundleversionid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwarebundleversion_bundleversionid_idx ON sdm.software_bundle_version USING btree (bundle_version_id);


--
-- Name: softwaresource_externalid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwaresource_externalid_idx ON sdm.software_source USING btree (external_id);


--
-- Name: softwaresource_softwareid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwaresource_softwareid_idx ON sdm.software_source USING btree (software_id);


--
-- Name: softwaresource_sourceid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwaresource_sourceid_idx ON sdm.software_source USING btree (source_id);


--
-- Name: softwareversion_maturityid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversion_maturityid_idx ON sdm.software_version USING btree (maturity_id);


--
-- Name: softwareversion_previousversionid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversion_previousversionid_idx ON sdm.software_version USING btree (previous_version_id);


--
-- Name: softwareversion_releasetypeid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversion_releasetypeid_idx ON sdm.software_version USING btree (release_type_id);


--
-- Name: softwareversion_softwareid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversion_softwareid_idx ON sdm.software_version USING btree (software_id);


--
-- Name: softwareversion_versionlevel1_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversion_versionlevel1_idx ON sdm.software_version USING btree (version_level1);


--
-- Name: softwareversion_versionlevel2_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversion_versionlevel2_idx ON sdm.software_version USING btree (version_level2);


--
-- Name: softwareversion_versionlevel3_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversion_versionlevel3_idx ON sdm.software_version USING btree (version_level3);


--
-- Name: softwareversion_versionlevel4_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversion_versionlevel4_idx ON sdm.software_version USING btree (version_level4);


--
-- Name: softwareversionsource_softwareversionid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversionsource_softwareversionid_idx ON sdm.software_version_source USING btree (software_version_id);


--
-- Name: softwareversionsource_sourceid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX softwareversionsource_sourceid_idx ON sdm.software_version_source USING btree (source_id);


--
-- Name: source_name_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE UNIQUE INDEX source_name_idx ON sdm.source USING btree (code_name);


--
-- Name: source_sourcetypeid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX source_sourcetypeid_idx ON sdm.source USING btree (source_type_id);


--
-- Name: xformreleasetype_sourceid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX xformreleasetype_sourceid_idx ON sdm.xform_release_type USING btree (source_id, source_release_type);


--
-- Name: xformsoftwarematurity_sourceid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE UNIQUE INDEX xformsoftwarematurity_sourceid_idx ON sdm.xform_software_maturity USING btree (source_id, source_maturity_id);


--
-- Name: xformsoftwareversion_global_id_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX xformsoftwareversion_global_id_idx ON sdm.xform_software_version USING btree (global_id);


--
-- Name: xformsoftwareversion_sourceid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX xformsoftwareversion_sourceid_idx ON sdm.xform_software_version USING btree (source_id);


--
-- Name: xformsoftwareversion_sourcetypeid_idx; Type: INDEX; Schema: sdm; Owner: -
--

CREATE INDEX xformsoftwareversion_sourcetypeid_idx ON sdm.xform_software_version USING btree (source_type_id);


--
-- Name: bundle_version bundleversion_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.bundle_version
    ADD CONSTRAINT bundleversion_fk FOREIGN KEY (bundle_id) REFERENCES sdm.bundle(id);


--
-- Name: software_bundle_version bundleversion_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_bundle_version
    ADD CONSTRAINT bundleversion_fk FOREIGN KEY (bundle_version_id) REFERENCES sdm.bundle_version(id);


--
-- Name: compatibility child_software_version_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.compatibility
    ADD CONSTRAINT child_software_version_fk FOREIGN KEY (child_software_version_id) REFERENCES sdm.software_version(id);


--
-- Name: compatibility_source compatibility_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.compatibility_source
    ADD CONSTRAINT compatibility_fk FOREIGN KEY (compatibility_id) REFERENCES sdm.compatibility(id);


--
-- Name: error error_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.error
    ADD CONSTRAINT error_fk FOREIGN KEY (source_id) REFERENCES sdm.source(id);


--
-- Name: software_version maturity_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_version
    ADD CONSTRAINT maturity_fk FOREIGN KEY (maturity_id) REFERENCES sdm.software_maturity(id);


--
-- Name: xform_software_maturity maturity_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software_maturity
    ADD CONSTRAINT maturity_fk FOREIGN KEY (target_maturity_id) REFERENCES sdm.software_maturity(id);


--
-- Name: compatibility parent_software_version_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.compatibility
    ADD CONSTRAINT parent_software_version_fk FOREIGN KEY (parent_software_version_id) REFERENCES sdm.software_version(id);


--
-- Name: software_version release_type_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_version
    ADD CONSTRAINT release_type_fk FOREIGN KEY (release_type_id) REFERENCES sdm.release_type(id);


--
-- Name: xform_release_type releasetype_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_release_type
    ADD CONSTRAINT releasetype_fk FOREIGN KEY (target_release_type_id) REFERENCES sdm.release_type(id);


--
-- Name: software_bundle software_bundle_bundle_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_bundle
    ADD CONSTRAINT software_bundle_bundle_fk FOREIGN KEY (bundle_id) REFERENCES sdm.bundle(id);


--
-- Name: software_bundle software_bundle_software_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_bundle
    ADD CONSTRAINT software_bundle_software_fk FOREIGN KEY (software_id) REFERENCES sdm.software(id);


--
-- Name: software_version software_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_version
    ADD CONSTRAINT software_fk FOREIGN KEY (software_id) REFERENCES sdm.software(id);


--
-- Name: software_source software_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_source
    ADD CONSTRAINT software_fk FOREIGN KEY (software_id) REFERENCES sdm.software(id);


--
-- Name: software software_status_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software
    ADD CONSTRAINT software_status_fk FOREIGN KEY (software_status_id) REFERENCES sdm.software_status(id);


--
-- Name: software software_type_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software
    ADD CONSTRAINT software_type_fk FOREIGN KEY (software_type_id) REFERENCES sdm.software_type(id);


--
-- Name: software_version software_version_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_version
    ADD CONSTRAINT software_version_fk FOREIGN KEY (previous_version_id) REFERENCES sdm.software_version(id);


--
-- Name: software_version_source software_version_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_version_source
    ADD CONSTRAINT software_version_fk FOREIGN KEY (software_version_id) REFERENCES sdm.software_version(id);


--
-- Name: software_version_source software_version_source_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_version_source
    ADD CONSTRAINT software_version_source_fk FOREIGN KEY (source_id) REFERENCES sdm.source(id);


--
-- Name: xform_software softwaretype_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software
    ADD CONSTRAINT softwaretype_fk FOREIGN KEY (software_type_id) REFERENCES sdm.software_type(id);


--
-- Name: software_bundle_version softwareversion_fk_1; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_bundle_version
    ADD CONSTRAINT softwareversion_fk_1 FOREIGN KEY (software_version_id) REFERENCES sdm.software_version(id);


--
-- Name: source source_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.source
    ADD CONSTRAINT source_fk FOREIGN KEY (source_type_id) REFERENCES sdm.source_type(id);


--
-- Name: xform_release_type source_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_release_type
    ADD CONSTRAINT source_fk FOREIGN KEY (source_id) REFERENCES sdm.source(id);


--
-- Name: xform_software source_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software
    ADD CONSTRAINT source_fk FOREIGN KEY (source_id) REFERENCES sdm.source(id);


--
-- Name: xform_software_maturity source_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software_maturity
    ADD CONSTRAINT source_fk FOREIGN KEY (source_id) REFERENCES sdm.source(id);


--
-- Name: xform_software_version source_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software_version
    ADD CONSTRAINT source_fk FOREIGN KEY (source_id) REFERENCES sdm.source(id);


--
-- Name: software_source source_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.software_source
    ADD CONSTRAINT source_fk FOREIGN KEY (source_id) REFERENCES sdm.source(id);


--
-- Name: compatibility_source source_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.compatibility_source
    ADD CONSTRAINT source_fk FOREIGN KEY (source_id) REFERENCES sdm.source(id);


--
-- Name: xform_software source_type_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software
    ADD CONSTRAINT source_type_fk FOREIGN KEY (source_type_id) REFERENCES sdm.source_type(id);


--
-- Name: xform_software_version sourcetype_fk; Type: FK CONSTRAINT; Schema: sdm; Owner: -
--

ALTER TABLE ONLY sdm.xform_software_version
    ADD CONSTRAINT sourcetype_fk FOREIGN KEY (source_type_id) REFERENCES sdm.source_type(id);


--
-- PostgreSQL database dump complete
--


-- migrate:down
