BEGIN;
select plan(2);
select has_schema('sdm');
select tables_are('sdm',
    ARRAY[
         'allow_list',
         'bundle',
         'bundle_version',
         'compatibility',
         'compatibility_source',
         'contract_entitlement',
         'error',
         'release_type',
         'software',
         'software_bundle',
         'software_bundle_version',
         'software_maturity',
         'software_source',
         'software_status',
         'software_type',
         'software_version',
         'software_version_source',
         'source',
         'source_type',
         'xform_release_type',
         'xform_software',
         'xform_software_maturity',
         'xform_software_version'
    ]);
ROLLBACK;
