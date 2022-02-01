-- migrate:up
do $$

    declare

        v_id_sw_type_app sdm.software_type.id%type;
        v_id_sw_type_platform sdm.software_type.id%type;
        v_id_status_active sdm.software_status.id%type;
        v_id_rel_type_minor sdm.release_type.id%type;
        v_id_maturity_released sdm.software_maturity.id%type;
        v_id_dummy integer;

        v_flag_sample_metadata bool := true;
        v_flag_tundra_metadata bool := true;

    begin

        /* ### LOAD THE 'ENUM' IDs ### */

        select st.id into v_id_sw_type_app from sdm.software_type st where st.code_name = 'APP';
        if not found then
            raise exception 'Software type ''Application'' not found.';
        end if;

        select st.id into v_id_sw_type_platform from sdm.software_type st where st.code_name = 'PLATFORM';
        if not found then
            raise exception 'Software type ''Platform'' not found.';
        end if;

        select ss.id into v_id_status_active from sdm.software_status ss where ss.code_name = 'A';
        if not found then
            raise exception 'Software status ''Active'' not found.';
        end if;

        select rt.id into v_id_rel_type_minor from sdm.release_type rt where rt.code_name = 'MINOR';
        if not found then
            raise exception 'Release type ''Minor'' not found.';
        end if;

        select sm.id into v_id_maturity_released from sdm.software_maturity sm where sm.code_name = 'REL';
        if not found then
            raise exception 'Maturity ''Released'' not found.';
        end if;

        /* #########################################################################################################################################
         * ### SAMPLE METADATA (MINIMALISTIC SET OF ARTIFICAL METADATA INTENDED FOR BASIC UNIT TESTING)
         * #########################################################################################################################################
         */

        if v_flag_sample_metadata then

            /* ### CLEAN EXISTING DATA ### */

            call data_mgmt.f_software_clean('A');
            call data_mgmt.f_software_clean('B');
            call data_mgmt.f_software_clean('C');
            call data_mgmt.f_bundle_clean('BU0000');

            /* ### INITIALIZE SOFTWARE RECORDS ### */

            v_id_dummy := data_mgmt.f_software_set('A', 'Parent', v_id_sw_type_app, v_id_status_active);
            v_id_dummy := data_mgmt.f_software_set('B', 'Child', v_id_sw_type_app, v_id_status_active);
            v_id_dummy := data_mgmt.f_software_set('C', 'Grandchild', v_id_sw_type_app, v_id_status_active);

            /* ### INITIALIZE BUNDLE ### */

            v_id_dummy := data_mgmt.f_bundle_set('BU0000', 'SAMPLE', 'Sample');
            call data_mgmt.f_software_bundle_set_by_name('Sample', 'Parent');
            call data_mgmt.f_software_bundle_set_by_name('Sample', 'Child');
            call data_mgmt.f_software_bundle_set_by_name('Sample', 'Grandchild');

            /* ### INITIALIZE SOFTWARE VERSION RECORDS ### */

            v_id_dummy := data_mgmt.f_software_version_set_by_name('Parent', 5, 0, 0, 0, null, v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Parent', 5, 1, 0, 0, '5.0.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Parent', 5, 2, 0, 0, '5.1.0.0', v_id_rel_type_minor, v_id_maturity_released, now());

            v_id_dummy := data_mgmt.f_software_version_set_by_name('Child', 1, 0, 0, 0, null, v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Child', 1, 1, 0, 0, '1.0.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Child', 1, 2, 0, 0, '1.1.0.0', v_id_rel_type_minor, v_id_maturity_released, now());

            v_id_dummy := data_mgmt.f_software_version_set_by_name('Grandchild', 2, 1, 0, 0, null, v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Grandchild', 2, 2, 0, 0, '2.1.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Grandchild', 2, 3, 0, 0, '2.2.0.0', v_id_rel_type_minor, v_id_maturity_released, now());

            /* ### INITIALIZE SOFTWARE VERSION COMPATIBILITIES ### */

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.0.0.0', 'Child', '1.0.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.0.0.0', 'Child', '1.1.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.1.0.0', 'Child', '1.1.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.1.0.0', 'Child', '1.2.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.2.0.0', 'Child', '1.2.0.0', null, true, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.0.0.0', 'Grandchild', '2.1.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.0.0.0', 'Grandchild', '2.2.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.1.0.0', 'Grandchild', '2.1.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.1.0.0', 'Grandchild', '2.2.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.2.0.0', 'Grandchild', '2.2.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Parent', '5.2.0.0', 'Grandchild', '2.3.0.0', null, true, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Child', '1.0.0.0', 'Grandchild', '2.1.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Child', '1.1.0.0', 'Grandchild', '2.2.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Child', '1.2.0.0', 'Grandchild', '2.3.0.0', null, true, null, null);

        end if;

        /* #########################################################################################################################################
         * ### TUNDRA METADATA (REALISTIC DATA SET BASED ON INPUT FROM TUNDRA TEAM)
         * #########################################################################################################################################
         */

        if v_flag_tundra_metadata then

            /* ### CLEAN EXISTING DATA ### */

            call data_mgmt.f_software_clean('SW0008');
            call data_mgmt.f_software_clean('SW0009');
            call data_mgmt.f_software_clean('SW0002');
            call data_mgmt.f_software_clean('PL0003');
            call data_mgmt.f_software_clean('SW0010');
            call data_mgmt.f_software_clean('SW0003');
            call data_mgmt.f_bundle_clean('BU0001');

            /* ### INITIALIZE SOFTWARE RECORDS ### */

            v_id_dummy := data_mgmt.f_software_set('SW0008', 'Apollo', v_id_sw_type_app, v_id_status_active);
            v_id_dummy := data_mgmt.f_software_set('SW0009', 'Autostar', v_id_sw_type_app, v_id_status_active);
            v_id_dummy := data_mgmt.f_software_set('SW0002', 'EPU', v_id_sw_type_app, v_id_status_active);
            v_id_dummy := data_mgmt.f_software_set('PL0003', 'Talos', v_id_sw_type_platform, v_id_status_active);
            v_id_dummy := data_mgmt.f_software_set('SW0010', 'Traffic Lights', v_id_sw_type_app, v_id_status_active);
            v_id_dummy := data_mgmt.f_software_set('SW0003', 'Tool Readiness', v_id_sw_type_app, v_id_status_active);

            /* ### INITIALIZE BUNDLE ### */

            v_id_dummy := data_mgmt.f_bundle_set('BU0001', 'TUNDRA', 'Tundra');
            call data_mgmt.f_software_bundle_set_by_name('Tundra', 'Apollo');
            call data_mgmt.f_software_bundle_set_by_name('Tundra', 'Autostar');
            call data_mgmt.f_software_bundle_set_by_name('Tundra', 'EPU');
            call data_mgmt.f_software_bundle_set_by_name('Tundra', 'Talos');
            call data_mgmt.f_software_bundle_set_by_name('Tundra', 'Traffic Lights');
            call data_mgmt.f_software_bundle_set_by_name('Tundra', 'Tool Readiness');

            /* ### INITIALIZE SOFTWARE VERSION RECORDS ### */

            v_id_dummy := data_mgmt.f_software_version_set_by_name('Apollo', 1, 2, 0, 0, null, v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Apollo', 1, 3, 0, 0, '1.2.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Apollo', 1, 4, 0, 0, '1.3.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Apollo', 1, 5, 0, 0, '1.4.0.0', v_id_rel_type_minor, v_id_maturity_released, now());

            v_id_dummy := data_mgmt.f_software_version_set_by_name('Autostar', 2, 6, 0, 0, null, v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Autostar', 2, 7, 0, 0, '2.6.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Autostar', 2, 8, 0, 0, '2.7.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Autostar', 2, 9, 0, 0, '2.8.0.0', v_id_rel_type_minor, v_id_maturity_released, now());

            v_id_dummy := data_mgmt.f_software_version_set_by_name('EPU', 2, 12, 0, 0, null, v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('EPU', 2, 13, 0, 0, '2.12.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('EPU', 2, 14, 0, 0, '2.13.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('EPU', 2, 15, 0, 0, '2.14.0.0', v_id_rel_type_minor, v_id_maturity_released, now());

            v_id_dummy := data_mgmt.f_software_version_set_by_name('Talos', 7, 9, 0, 0, null, v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Talos', 7, 10, 0, 0, '7.9.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Talos', 7, 11, 0, 0, '7.10.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Talos', 7, 12, 0, 0, '7.11.0.0', v_id_rel_type_minor, v_id_maturity_released, now());

            v_id_dummy := data_mgmt.f_software_version_set_by_name('Tool Readiness', 2, 69, 14, 0, null, v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Tool Readiness', 2, 95, 6, 0, '2.69.14.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Tool Readiness', 2, 130, 4, 0, '2.95.6.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Tool Readiness', 2, 150, 4, 0, '2.130.4.0', v_id_rel_type_minor, v_id_maturity_released, now());

            v_id_dummy := data_mgmt.f_software_version_set_by_name('Traffic Lights', 1, 4, 0, 0, null, v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Traffic Lights', 1, 5, 0, 0, '1.4.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Traffic Lights', 1, 6, 0, 0, '1.5.0.0', v_id_rel_type_minor, v_id_maturity_released, now());
            v_id_dummy := data_mgmt.f_software_version_set_by_name('Traffic Lights', 1, 7, 0, 0, '1.6.0.0', v_id_rel_type_minor, v_id_maturity_released, now());

            /* ### INITIALIZE SOFTWARE VERSION COMPATIBILITIES ### */

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.9.0.0', 'EPU', '2.12.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.9.0.0', 'EPU', '2.13.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.9.0.0', 'EPU', '2.14.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.10.0.0', 'EPU', '2.13.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.10.0.0', 'EPU', '2.14.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'EPU', '2.14.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.12.0.0', 'EPU', '2.15.0.0', null, false, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.9.0.0', 'Traffic Lights', '1.4.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.10.0.0', 'Traffic Lights', '1.5.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'Traffic Lights', '1.7.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'Traffic Lights', '1.6.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'Traffic Lights', '1.5.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.12.0.0', 'Traffic Lights', '1.7.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.12.0.0', 'Traffic Lights', '1.6.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.12.0.0', 'Traffic Lights', '1.5.0.0', null, false, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.9.0.0', 'Autostar', '2.6.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.10.0.0', 'Autostar', '2.7.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'Autostar', '2.8.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'Autostar', '2.7.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.12.0.0', 'Autostar', '2.9.0.0', null, true, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.9.0.0', 'Tool Readiness', '2.95.6.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.10.0.0', 'Tool Readiness', '2.130.4.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'Tool Readiness', '2.150.4.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'Tool Readiness', '2.130.4.0', null, false, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.9.0.0', 'Apollo', '1.2.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.10.0.0', 'Apollo', '1.3.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'Apollo', '1.4.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Talos', '7.11.0.0', 'Apollo', '1.3.0.0', null, true, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.6.0.0', 'Apollo', '1.2.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.7.0.0', 'Apollo', '1.3.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.8.0.0', 'Apollo', '1.5.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.8.0.0', 'Apollo', '1.4.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.8.0.0', 'Apollo', '1.3.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.9.0.0', 'Apollo', '1.5.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.9.0.0', 'Apollo', '1.4.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.9.0.0', 'Apollo', '1.3.0.0', null, false, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.6.0.0', 'Tool Readiness', '2.69.14.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.7.0.0', 'Tool Readiness', '2.95.6.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.8.0.0', 'Tool Readiness', '2.130.4.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.9.0.0', 'Tool Readiness', '2.150.4.0', null, true, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.6.0.0', 'EPU', '2.12.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.7.0.0', 'EPU', '2.13.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.8.0.0', 'EPU', '2.14.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Autostar', '2.9.0.0', 'EPU', '2.15.0.0', null, true, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.69.14.0', 'Apollo', '1.2.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.95.6.0', 'Apollo', '1.3.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.130.4.0', 'Apollo', '1.4.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.150.4.0', 'Apollo', '1.5.0.0', null, true, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.69.14.0', 'EPU', '2.12.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.95.6.0', 'EPU', '2.13.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.95.6.0', 'EPU', '2.14.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.95.6.0', 'EPU', '2.15.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.130.4.0', 'EPU', '2.12.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.130.4.0', 'EPU', '2.13.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.130.4.0', 'EPU', '2.14.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.130.4.0', 'EPU', '2.15.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.150.4.0', 'EPU', '2.12.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.150.4.0', 'EPU', '2.13.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.150.4.0', 'EPU', '2.14.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Tool Readiness', '2.150.4.0', 'EPU', '2.15.0.0', null, true, null, null);

            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.4.0.0', 'EPU', '2.12.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.5.0.0', 'EPU', '2.13.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.5.0.0', 'EPU', '2.14.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.5.0.0', 'EPU', '2.15.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.6.0.0', 'EPU', '2.12.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.6.0.0', 'EPU', '2.13.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.6.0.0', 'EPU', '2.14.0.0', null, true, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.6.0.0', 'EPU', '2.15.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.7.0.0', 'EPU', '2.12.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.7.0.0', 'EPU', '2.13.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.7.0.0', 'EPU', '2.14.0.0', null, false, null, null);
            v_id_dummy := data_mgmt.f_compatibility_set_by_name('Traffic Lights', '1.7.0.0', 'EPU', '2.15.0.0', null, true, null, null);

        end if;

    end $$

-- migrate:down

