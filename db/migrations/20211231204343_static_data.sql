-- migrate:up

do $$

    declare

        v_dummy integer;
        v_id_swa sdm.source_type.id%type;
        v_id_ds sdm.source_type.id%type;

        /* ### SWITCHES ### */
        v_env_prod bool := true;
        v_env_nonprod bool := true;

    begin

        /* ### RELEASE TYPE ### */
        --											code_name		name				weight
        v_dummy := data_mgmt.f_release_type_set(	'MAJOR',		'Major release',	1);
        v_dummy := data_mgmt.f_release_type_set(	'MINOR',		'Minor release',	2);
        v_dummy := data_mgmt.f_release_type_set(	'BUGFIX',		'Bugfix release',	3);
        v_dummy := data_mgmt.f_release_type_set(	'HOTFIX',		'Hotfix release',	4);

        /* ### MATURITY ### */
        --												code_name		name												weight	relevant	msa_name
        v_dummy := data_mgmt.f_software_maturity_set(	'UNKNOWN',		'Unspecified',										0,		false,		null);
        v_dummy := data_mgmt.f_software_maturity_set(	'DEPRECATED',	'Deprecated (do not use)',							0,		false,		'Obsolete');
        v_dummy := data_mgmt.f_software_maturity_set(	'PLAN',			'Planned',											1,		false,		'Immature');
        v_dummy := data_mgmt.f_software_maturity_set(	'PLAN_DATE',	'Planned (date confirmed)',							2,		false,		'Immature');
        v_dummy := data_mgmt.f_software_maturity_set(	'RC',			'Release Candidate',								3,		true,		'DevLab');
        v_dummy := data_mgmt.f_software_maturity_set(	'REL',			'Released',											4,		true,		'Customer');
        v_dummy := data_mgmt.f_software_maturity_set(	'REL_FAC',		'Released (factory only)',							5,		true,		'DevLab');
        v_dummy := data_mgmt.f_software_maturity_set(	'REL_SVC',		'Released (factory + service)',						6,		true,		'DevLab');
        v_dummy := data_mgmt.f_software_maturity_set(	'REL_FLD',		'Released (factory + service + field upgrade)',		7,		true,		'DevLab');
        v_dummy := data_mgmt.f_software_maturity_set(	'REL_NSR',		'Released (NSR, selected customers only)',			8,		true,		'Nanoport');

        /* ### SOFTWARE STATUS ### */
        --											code_name	name
        v_dummy := data_mgmt.f_software_status_set(	'A',		'Active');
        v_dummy := data_mgmt.f_software_status_set(	'I',		'Inactive');

        /* ### SOFTWARE TYPE ### */
        --											code_name	name
        v_dummy := data_mgmt.f_software_type_set(	'APP',		'Application');
        v_dummy := data_mgmt.f_software_type_set(	'PLATFORM',	'Platform Software');
        v_dummy := data_mgmt.f_software_type_set(	'OS',		'Operating System');
        v_dummy := data_mgmt.f_software_type_set(	'MICROSVC',	'Microservice');

        /* ### SOURCE TYPE ### */
        --										code_name	name
        v_id_swa := data_mgmt.f_source_type_set(	'SWA',		'SW Archive');
        v_id_ds :=  data_mgmt.f_source_type_set(	'DS',		'Data Services');

        /* ### SOURCE ### */
        if v_env_prod then
            --									code_name		description					source_type_id
            v_dummy := data_mgmt.f_source_set(	'swArchive',	'XDB SW Archive',			v_id_swa);
            v_dummy := data_mgmt.f_source_set(	'TEMswArchive',	'TEM SW Archive',			v_id_swa);
            v_dummy := data_mgmt.f_source_set(	'CDS',			'Central Data Services',	v_id_ds);
        end if;

        if v_env_nonprod then
            --									code_name			description			source_type_id
            v_dummy := data_mgmt.f_source_set(	'swArchiveDemo',	'DEMO SW Archive',	v_id_swa);
        end if;

    end $$
-- migrate:down

