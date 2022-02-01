SELECT plan(34);

prepare tcm1_query as
    select * from sdm.f_check_compatibility(
            array[
                row('A'::text,'5.1.0.0'::text),
                row('B'::text,'1.1.0.0'::text),
                row('C'::text,'2.2.0.0'::text)
                ]::sdm.t_check_compatibility[],
            true);
select is_empty('tcm1_query', 'test TCM1: Check compatibility among three components - positive case');

prepare tcm2_query as
    select * from sdm.f_check_compatibility(
            array[
                row('A'::text,'5.1.0.0'::text),
                row('B'::text,'1.2.0.0'::text),
                row('C'::text,'2.2.0.0'::text)
                ]::sdm.t_check_compatibility[],
            true);
prepare tcm2_result as values('B','Child','1.2.0.0','C','Grandchild','2.2.0.0');
select results_eq('tcm2_query', 'tcm2_result', 'test TCM2: Check compatibility among three components - negative case');

prepare tct1_query as
    select * from sdm.f_check_compatibility(
            array[
                row('SW0008'::text,'1.4.0.0'::text),
                row('SW0009'::text,'2.8.0.0'::text),
                row('SW0002'::text,'2.14.0.0'::text),
                row('PL0003'::text,'7.11.0.0'::text),
                row('SW0003'::text,'2.130.4.0'::text),
                row('SW0010'::text,'1.6.0.0'::text)
                ]::sdm.t_check_compatibility[],
            false);
select is_empty('tct1_query', 'test TCT1: Check compatibility of Tundra setup - positive case (tested only = FALSE)');

prepare tct2_query as
    select * from sdm.f_check_compatibility(
            array[
                row('SW0008'::text,'1.4.0.0'::text),
                row('SW0009'::text,'2.8.0.0'::text),
                row('SW0002'::text,'2.14.0.0'::text),
                row('PL0003'::text,'7.11.0.0'::text),
                row('SW0003'::text,'2.130.4.0'::text),
                row('SW0010'::text,'1.6.0.0'::text)
                ]::sdm.t_check_compatibility[],
            true);
prepare tct2_result as values('PL0003','Talos','7.11.0.0','SW0002','EPU','2.14.0.0'),
                             ('PL0003','Talos','7.11.0.0','SW0003','Tool Readiness','2.130.4.0'),
                             ('PL0003','Talos','7.11.0.0','SW0008','Apollo','1.4.0.0');
select set_eq('tct2_query', 'tct2_result', 'test TCT2: Check compatibility of Tundra setup - negative case (tested only = TRUE)');

prepare tct3_query as
    select * from sdm.f_check_compatibility(
            array[
                row('SW0008'::text,'1.4.0.0'::text),
                row('SW0009'::text,'2.8.0.0'::text),
                row('SW0002'::text,'2.14.0.0'::text),
                row('PL0003'::text,'7.10.0.0'::text),
                row('SW0003'::text,'2.130.4.0'::text),
                row('SW0010'::text,'1.6.0.0'::text)
                ]::sdm.t_check_compatibility[],
            false);
prepare tct3_result as values('PL0003','Talos','7.10.0.0','SW0008','Apollo','1.4.0.0'),
                             ('PL0003','Talos','7.10.0.0','SW0009','Autostar','2.8.0.0'),
                             ('PL0003','Talos','7.10.0.0','SW0010','Traffic Lights','1.6.0.0');
select set_eq('tct3_query', 'tct3_result', 'test TCT3: Check compatibility of Tundra setup - negative case');

prepare tct4_query as
    select * from sdm.f_check_compatibility(
            array[
                row('SW0002'::text,'2.15.0.0'::text),
                row('PL0003'::text,'7.11.0.0'::text),
                row('SW0010'::text,'1.7.0.0'::text)
                ]::sdm.t_check_compatibility[]);
prepare tct4_result as values('PL0003','Talos','7.11.0.0','SW0002','EPU','2.15.0.0');
select set_eq('tct4_query', 'tct4_result', 'test TCT4: Check compatibility of Tundra setup - EPU 2.15 is indirectly compatible with Talos 7.11 via Traffic Lights 1.7, but there is no direct compatibility between EPU 2.15 and Talso 7.11');

prepare tdm1_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('A'::text,'5.1.0.0'::text),
                row('B'::text,''::text),
                row('C'::text,''::text)
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tdm1_result as
    values ('{"(A,5.1.0.0)","(B,1.1.0.0)","(C,2.2.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdm1_query', 'tdm1_result', 'test TDM1: Get versions of B and C compatible with A 5.1');

prepare tdm2_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('A'::text,''::text),
                row('B'::text,''::text),
                row('C'::text,'2.3.0.0'::text)
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tdm2_result as
    values ('{"(A,5.2.0.0)","(B,1.2.0.0)","(C,2.3.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdm2_query', 'tdm2_result', 'test TDM2: Get version of A and B compatible with C 2.3');

prepare tdm3_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('A'::text,''::text),
                row('B'::text,'1.1.0.0'::text),
                row('C'::text,''::text)
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tdm3_result as
    values ('{"(A,5.0.0.0)","(B,1.1.0.0)","(C,2.2.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(A,5.1.0.0)","(B,1.1.0.0)","(C,2.2.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdm3_query', 'tdm3_result', 'test TDM3: Get versions of A and C compatible with B 1.1');

prepare tdm4_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('A'::text,'5.0.0.0'::text),
                row('B'::text,''::text)
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tdm4_result as
    values ('{"(A,5.0.0.0)","(B,1.0.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(A,5.0.0.0)","(B,1.1.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdm4_query', 'tdm4_result', 'test TDM4: Get versions of B compatible with A 5.0');

prepare tdm5_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('A'::text,'5.3.0.0'::text),
                row('B'::text,''::text),
                row('C'::text,''::text)
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
select throws_ok('tdm5_query', 'not exists version {5.3.0.0} for software {A}', 'test TDM5: Get versions of B and C compatible with A 5.3 - negative scenario');

prepare tdt1_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.9.0.0'::text), -- TEM Server
                row('SW0010'::text,''::text), -- Traffic Lights
                row('SW0002'::text,''::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tdt1_result as
    values ('{"(PL0003,7.9.0.0)","(SW0002,2.12.0.0)","(SW0010,1.4.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdt1_query', 'tdt1_result', 'test TDT1: Get all versions of EPU [SW0002] and Traffic Lights [SW0010] compatible with TEM Server 7.9 [PL0003] (tested only=FALSE)');

prepare tdt2_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.10.0.0'::text), -- TEM Server
                row('SW0010'::text,''::text), -- Traffic Lights
                row('SW0002'::text,''::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tdt2_result as
    values ('{"(PL0003,7.10.0.0)","(SW0002,2.13.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.10.0.0)","(SW0002,2.14.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdt2_query', 'tdt2_result', 'test TDT2: Get all versions of EPU [SW0002] and Traffic Lights [SW0010] compatible with TEM Server 7.10 [PL0003] (tested only=FALSE)');

prepare tdt3_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.10.0.0'::text), -- TEM Server
                row('SW0010'::text,''::text), -- Traffic Lights
                row('SW0002'::text,''::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tdt3_result as
    values ('{"(PL0003,7.10.0.0)","(SW0002,2.13.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdt3_query', 'tdt3_result', 'test TDT3: Get all versions of EPU [SW0002] and Traffic Lights [SW0010] compatible with TEM Server 7.10 [PL0003] (tested only=TRUE)');

prepare tdt4_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.11.0.0'::text), -- TEM Server
                row('SW0010'::text,''::text), -- Traffic Lights
                row('SW0002'::text,''::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tdt4_result as
    values ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0010,1.6.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0010,1.7.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdt4_query', 'tdt4_result', 'test TDT4: Get all versions of EPU [SW0002] and Traffic Lights [SW0010] compatible with TEM Server 7.11 [PL0003] (tested only=FALSE)');

prepare tdt5_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.11.0.0'::text), -- TEM Server
                row('SW0010'::text,''::text), -- Traffic Lights
                row('SW0002'::text,''::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
select is_empty('tdt5_query', 'test TDT1: Get all versions of EPU [SW0002] and Traffic Lights [SW0010] compatible with TEM Server 7.11 (tested only=TRUE)');

prepare tdt6_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.9.0.0'::text), -- TEM Server
                row('SW0010'::text,''::text), -- Traffic Lights
                row('SW0009'::text,''::text), -- Autostar
                row('SW0002'::text,''::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tdt6_result as
    values ('{"(PL0003,7.9.0.0)","(SW0002,2.12.0.0)","(SW0009,2.6.0.0)","(SW0010,1.4.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdt6_query', 'tdt6_result', 'test TDT6: Get all versions of EPU [SW0002], Autostar [SW0009] and Traffic Lights [SW0010] compatible with TEM Server 7.9 [PL0003] (tested only=FALSE) - there is not compatibility relation between Autostar and Traffic Lights!');

prepare tdt7_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.9.0.0'::text), -- TEM Server
                row('SW0009'::text,''::text), -- Autostar
                row('SW0002'::text,''::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tdt7_result as
    values ('{"(PL0003,7.9.0.0)","(SW0002,2.12.0.0)","(SW0009,2.6.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdt7_query', 'tdt7_result', 'test TDT7: Get all versions of EPU [SW0002] and Autostar [SW0009] compatible with TEM Server 7.9 [PL0003] (tested only=FALSE)');

prepare tdt8_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.9.0.0'::text), -- TEM Server
                row('SW0008'::text,''::text), -- Apollo
                row('SW0009'::text,''::text) -- Autostar
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tdt8_result as
    values ('{"(PL0003,7.9.0.0)","(SW0008,1.2.0.0)","(SW0009,2.6.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdt8_query', 'tdt8_result', 'test TDT8: Get all versions of Apollo [SW0008] and Autostar [SW0009] compatible with TEM Server 7.9 [PL0003] (tested only=FALSE)');

prepare tdt9_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.9.0.0'::text), -- TEM Server
                row('SW0002'::text,''::text), -- EPU
                row('SW0008'::text,''::text), -- Apollo
                row('SW0009'::text,''::text) -- Autostar
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tdt9_result as
    values ('{"(PL0003,7.9.0.0)","(SW0002,2.12.0.0)","(SW0008,1.2.0.0)","(SW0009,2.6.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdt9_query', 'tdt9_result', 'test TDT9: Get all versions of Apollo [SW0008], EPU [SW0002] and Autostar [SW0009] compatible with TEM Server 7.9 [PL0003] (tested only=FALSE)');

prepare tdt10_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'7.11.0.0'::text), -- TEM Server
                row('SW0009'::text,''::text), -- Autostar
                row('SW0008'::text,''::text), -- Apollo
                row('SW0010'::text,''::text), -- Traffic Lights
                row('SW0002'::text,''::text), -- EPU
                row('SW0003'::text,''::text) -- Tool Readiness
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tdt10_result as
    values ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.6.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.7.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tdt10_query', 'tdt10_result', 'test TDT10: Get versions of all Tundra components compatible with TEM Server 7.11 [PL0003] (tested only=FALSE)');

prepare tdt11_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('SW0008'::text,''::text), -- Apollo
                row('SW0009'::text,''::text), -- Autostar
                row('SW0002'::text,''::text), -- EPU
                row('PL0003'::text,'7.11.0.0'::text), -- TEM Server
                row('SW0003'::text,''::text), -- Tool Readiness
                row('SW0010'::text,''::text) -- Traffic Lights
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
select is_empty('tdt11_query', 'test TDT11: Get versions of all Tundra components compatible with TEM Server 7.11 [PL0003] (tested only=TRUE)');

prepare tdt12_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('SW0008'::text,''::text), -- Apollo
                row('SW0009'::text,''::text), -- Autostar
                row('SW0002'::text,'2.15.0.0'::text), -- EPU
                row('PL0003'::text,''::text), -- TEM Server
                row('SW0003'::text,''::text), -- Tool Readiness
                row('SW0010'::text,''::text) -- Traffic Lights
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
select is_empty('tdt12_query', 'test TDT12: Get versions of all Tundra components compatible with EPU 2.15 [SW0002] - negative case');

prepare tst1_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('SW0002'::text,''::text), -- EPU
                row('PL0003'::text,''::text) -- TEM Server
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tst1_result as
    values ('{"(PL0003,7.9.0.0)","(SW0002,2.12.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.10.0.0)","(SW0002,2.13.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tst1_query', 'tst1_result', 'test TST1: Get all versions of TEM Server [PL0003] and EPU [SW0002] compatible with each other (test only=TRUE)');

prepare tst2_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('SW0008'::text,''::text), -- Apollo
                row('SW0009'::text,''::text), -- Autostar
                row('SW0002'::text,''::text), -- EPU
                row('PL0003'::text,''::text), -- TEM Server
                row('SW0003'::text,''::text), -- Tool Readiness
                row('SW0010'::text,''::text) -- Traffic Lights
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tst2_result as
    values ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.6.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.7.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tst2_query', 'tst2_result', 'test TST2: Get all compatible configurations (test only=FALSE)');

prepare tst3_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('SW0008'::text,''::text), -- Apollo
                row('SW0009'::text,''::text), -- Autostar
                row('SW0002'::text,''::text), -- EPU
                row('PL0003'::text,''::text), -- TEM Server
                row('SW0003'::text,''::text), -- Tool Readiness
                row('SW0010'::text,''::text) -- Traffic Lights
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
select is_empty('tst3_query', 'test TDT11: Get all compatible configurations (test only=TRUE)');

prepare tum1_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('A'::text,'>=5.0.0.0'::text),
                row('B'::text,'>=1.0.0.0'::text),
                row('C'::text,'>=2.1.0.0'::text)
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tum1_result as
    values ('{"(A,5.0.0.0)","(B,1.0.0.0)","(C,2.1.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(A,5.0.0.0)","(B,1.1.0.0)","(C,2.2.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(A,5.1.0.0)","(B,1.1.0.0)","(C,2.2.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(A,5.2.0.0)","(B,1.2.0.0)","(C,2.3.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tum1_query', 'tum1_result', 'test TUM1: Check for updates among three components - oldest possible setup');

prepare tum2_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('A'::text,'>=5.1.0.0'::text),
                row('B'::text,'>=1.1.0.0'::text),
                row('C'::text,'>=2.2.0.0'::text)
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tum2_result as
    values ('{"(A,5.1.0.0)","(B,1.1.0.0)","(C,2.2.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(A,5.2.0.0)","(B,1.2.0.0)","(C,2.3.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tum2_query', 'tum2_result', 'test TUM2: Check for updates among three components - intermediate setup');

prepare tum3_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('A'::text,'>=5.2.0.0'::text),
                row('B'::text,'>=1.2.0.0'::text),
                row('C'::text,'>=2.3.0.0'::text)
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tum3_result as
    values ('{"(A,5.2.0.0)","(B,1.2.0.0)","(C,2.3.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tum3_query', 'tum3_result', 'test TUM3: Check for updates among three components - up-to-date setup');

prepare tut1_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'>=7.9.0.0'::text), -- TEM Server
                row('SW0010'::text,'>=1.4.0.0'::text), -- Traffic Lights
                row('SW0002'::text,'>=2.12.0.0'::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tut1_result as
    values ('{"(PL0003,7.9.0.0)","(SW0002,2.12.0.0)","(SW0010,1.4.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.10.0.0)","(SW0002,2.13.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tut1_query', 'tut1_result', 'test TUT1: Get updates for a setup of EPU [SW0002], Traffic Lights [SW0010] and TEM Server 7.9 [PL0003] (tested only=TRUE) (no indirect dependencies)');

prepare tut2_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'>=7.9.0.0'::text), -- TEM Server
                row('SW0010'::text,'>=1.4.0.0'::text), -- Traffic Lights
                row('SW0009'::text,'>=2.6.0.0'::text), -- Autostar
                row('SW0002'::text,'>=2.12.0.0'::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tut2_result as
    values ('{"(PL0003,7.9.0.0)","(SW0002,2.12.0.0)","(SW0009,2.6.0.0)","(SW0010,1.4.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.10.0.0)","(SW0002,2.13.0.0)","(SW0009,2.7.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tut2_query', 'tut2_result', 'test TUT2: Get updates for a setup of EPU [SW0002], Traffic Lights [SW0010], Autostar [SW0009] and TEM Server 7.9 [PL0003] (tested only=TRUE) (no indirect dependencies)');

prepare tut3_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'>=7.9.0.0'::text), -- TEM Server
                row('SW0010'::text,''::text), -- Traffic Lights
                row('SW0009'::text,''::text), -- Autostar
                row('SW0002'::text,'>=2.12.0.0'::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tut3_result as
    values ('{"(PL0003,7.9.0.0)","(SW0002,2.12.0.0)","(SW0009,2.6.0.0)","(SW0010,1.4.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.10.0.0)","(SW0002,2.13.0.0)","(SW0009,2.7.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tut3_query', 'tut3_result', 'test TUT3: Get updates for a setup of EPU [SW0002], Traffic Lights [SW0010], Autostar [SW0009] and TEM Server 7.9 [PL0003] (tested only=TRUE) (without specifying versions for Traffic Lights and Autostar components)');

prepare tut4_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('PL0003'::text,'>=7.9.0.0'::text), -- TEM Server
                row('SW0010'::text,'>=1.4.0.0'::text), -- Traffic Lights
                row('SW0009'::text,''::text), -- Autostar
                row('SW0002'::text,'>=2.12.0.0'::text) -- EPU
                ]::sdm.t_check_compatibility[],
            '{check_tested_only}'::sdm.t_check_flag[]);
prepare tut4_result as
    values ('{"(PL0003,7.9.0.0)","(SW0002,2.12.0.0)","(SW0009,2.6.0.0)","(SW0010,1.4.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.10.0.0)","(SW0002,2.13.0.0)","(SW0009,2.7.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tut4_query', 'tut4_result', 'test TUT4: Get updates for a setup of EPU [SW0002], Traffic Lights [SW0010], Autostar [SW0009] and TEM Server 7.9 [PL0003] (tested only=TRUE) (without specifying versions for Autostar component - in the past it had issues with inexistent dependency on Traffic Lights)');

prepare tut5_query as
    select * from sdm.f_get_compatible_versions_v3(
            array[
                row('SW0008'::text,'>=1.4.0.0'::text), -- Apollo
                row('SW0009'::text,'>=2.8.0.0'::text), -- Autostar
                row('SW0002'::text,'>=2.14.0.0'::text), -- EPU
                row('PL0003'::text,'>=7.11.0.0'::text), -- TEM Server
                row('SW0003'::text,'>=2.130.4.0'::text), -- Tool Readiness
                row('SW0010'::text,'>=1.5.0.0'::text) -- Traffic Lights
                ]::sdm.t_check_compatibility[],
            '{}'::sdm.t_check_flag[]);
prepare tut5_result as
    values ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.6.0.0)"}'::sdm.t_check_compatibility[]),
           ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.7.0.0)"}'::sdm.t_check_compatibility[]);
select set_eq('tut5_query', 'tut5_result', 'test TUT5: Get updates for a complete Tundra setup with TEM Server 7.11 (tested only = FALSE)');

rollback;
