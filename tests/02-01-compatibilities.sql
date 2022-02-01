BEGIN;
SELECT plan(13);
--dohledani vsech zavislosti na PL0003 a SW0009 prislusne verzi
PREPARE pl03sw03resV1AllArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0009,2.8.0.0)","(SW0003,2.130.4.0)","(SW0002,2.14.0.0)"}'::sdm.t_check_compatibility[]),
                                        ('{"(PL0003,7.11.0.0)","(SW0009,2.8.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)"}'::sdm.t_check_compatibility[])
;
PREPARE pl03sw03resV2AllArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]),
                                        ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.6.0.0)"}'::sdm.t_check_compatibility[]),
                                        ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.7.0.0)"}'::sdm.t_check_compatibility[])
;

PREPARE pl03sw03resAllSelect AS SELECT *
                                FROM sdm.f_get_compatible_versions(
                                        ARRAY [ROW ('SW0009'::text,'2.8.0.0'::text), ROW ('PL0003'::text,'7.11.0.0'::text)]::sdm.t_check_compatibility[],
                                        '{check_all}'::sdm.t_check_flag[]);
PREPARE pl03sw03resAllV2Select AS SELECT *
                                  FROM sdm.f_get_compatible_versions_v3(
                                          ARRAY [ROW ('SW0009'::text,'2.8.0.0'::text), ROW ('PL0003'::text,'7.11.0.0'::text)]::sdm.t_check_compatibility[],
                                          '{check_all}'::sdm.t_check_flag[]);

SELECT results_eq('pl03sw03resV1AllArray', 'pl03sw03resAllSelect', 'test SW0009,PL0003 - check_all');
SELECT results_eq('pl03sw03resV2AllArray', 'pl03sw03resAllV2Select', 'test SW0009,PL0003 (v3) - check_all');
--dohledani striktni zavislosti na PL0003 a SW0009 prislusne verzi
PREPARE pl03sw09restrictArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0009,2.8.0.0)"}'::sdm.t_check_compatibility[]);
PREPARE pl03sw09restrictSelect AS SELECT *
                                  FROM sdm.f_get_compatible_versions(
                                          ARRAY [ROW ('PL0003'::text,'7.11.0.0'::text), ROW ('SW0009'::text,'2.8.0.0'::text)]::sdm.t_check_compatibility[],
                                          '{}'::sdm.t_check_flag[]);
PREPARE pl03sw09restrictV2Select AS SELECT *
                                    FROM sdm.f_get_compatible_versions_v3(
                                            ARRAY [ROW ('PL0003'::text,'7.11.0.0'::text), ROW ('SW0009'::text,'2.8.0.0'::text)]::sdm.t_check_compatibility[],
                                            '{}'::sdm.t_check_flag[]);
SELECT results_eq('pl03sw09restrictArray', 'pl03sw09restrictSelect', 'test SW0009,PL0003 - bez check_all');
SELECT results_eq('pl03sw09restrictArray', 'pl03sw09restrictV2Select', 'test SW0009,PL0003 (v2)- bez check_all');
-- vezmi  prislusnou verzi SW0009, SW0003 defaultne je check_all, zobrazim chybejici vazby
PREPARE sw09sw03allArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0009,2.8.0.0)","(SW0003,2.130.4.0)","(SW0002,2.14.0.0)"}'::sdm.t_check_compatibility[]),
                                   ('{"(PL0003,7.11.0.0)","(SW0009,2.8.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)"}'::sdm.t_check_compatibility[])
;
PREPARE sw09sw03V2allArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)"}'::sdm.t_check_compatibility[])
;

PREPARE sw09sw03allSelect AS SELECT *
                             FROM sdm.f_get_compatible_versions(ARRAY [
                                                                    ROW ('SW0009'::text,'2.8.0.0'::text),
                                                                    ROW ('SW0003'::text,'2.130.4.0'::text)
                                                                    ]::sdm.t_check_compatibility[],
                                                                '{check_all}'::sdm.t_check_flag[]);
PREPARE sw09sw03allV2Select AS SELECT *
                               FROM sdm.f_get_compatible_versions_v3(ARRAY [
                                                                         ROW ('SW0009'::text,'2.8.0.0'::text),
                                                                         ROW ('SW0003'::text,'2.130.4.0'::text)
                                                                         ]::sdm.t_check_compatibility[],
                                                                     '{check_all}'::sdm.t_check_flag[]);
SELECT results_eq('sw09sw03allArray', 'sw09sw03allSelect', 'test SW0009,SW0003 - s default check_all');
SELECT results_eq('sw09sw03V2allArray', 'sw09sw03allV2Select', 'test SW0009,SW0003 (v2)- s default check_all');


-- vezmi PL0003 a prislusnou verzi SW0009 nic vic mne nezajima, vyhazuji check_all,
-- nemaji vazbu tak nezobrazim, pozor zalezi i na poradi prvku v pripade, ze nehledam dalsi vazby
-- je otazka zda to brat jako funkcionalitu nebo chybu.
PREPARE pl03sw08Array AS VALUES ('{"(PL0003,7.11.0.0)","(SW0008,1.4.0.0)"}'::sdm.t_check_compatibility[]);
PREPARE pl03sw08Select AS SELECT *
                          FROM sdm.f_get_compatible_versions(ARRAY [
                                                                 ROW ('PL0003'::text,'7.11.0.0'::text),
                                                                 ROW ('SW0008'::text,'1.4.0.0'::text)
                                                                 ]::sdm.t_check_compatibility[],
                                                             '{}'::sdm.t_check_flag[]);
PREPARE pl03sw08V2Select AS SELECT *
                            FROM sdm.f_get_compatible_versions_v3(ARRAY [
                                                                      ROW ('PL0003'::text,'7.11.0.0'::text),
                                                                      ROW ('SW0008'::text,'1.4.0.0'::text)
                                                                      ]::sdm.t_check_compatibility[],
                                                                  '{}'::sdm.t_check_flag[]);
SELECT results_eq('pl03sw08Array', 'pl03sw08Select', 'test PL0003,SW0008 - s default check_all');
SELECT results_eq('pl03sw08Array', 'pl03sw08V2Select', 'test PL0003,SW0008 (v3) - s default check_all');

-- neexistuje zavislost

PREPARE pl03sw09sw02Array AS VALUES ('{"(PL0003,7.11.0.0)","(SW0009,2.8.0.0)","(SW0002,2.14.0.0)"}'::sdm.t_check_compatibility[]);
PREPARE pl03sw09sw02V2Array AS VALUES ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0009,2.8.0.0)"}'::sdm.t_check_compatibility[]);

PREPARE pl03sw09sw02Select AS SELECT *
                              FROM sdm.f_get_compatible_versions(ARRAY [
                                                                     ROW ('SW0009'::text,'2.8.0.0'::text),
                                                                     ROW ('SW0002'::text,'2.14.0.0'::text),
                                                                     ROW ('PL0003'::text,'7.11.0.0'::text)
                                                                     ]::sdm.t_check_compatibility[],
                                                                 '{}'::sdm.t_check_flag[]);
PREPARE pl03sw09sw02V2Select AS SELECT *
                                FROM sdm.f_get_compatible_versions_v3(ARRAY [
                                                                          ROW ('SW0009'::text,'2.8.0.0'::text),
                                                                          ROW ('SW0002'::text,'2.14.0.0'::text),
                                                                          ROW ('PL0003'::text,'7.11.0.0'::text)
                                                                          ]::sdm.t_check_compatibility[],
                                                                      '{}'::sdm.t_check_flag[]);
SELECT results_eq('pl03sw09sw02Array', 'pl03sw09sw02Select',
                  'test PL0003,SW0009,SW0002 - striktni vazba a poradi  neni vyzadovano');
SELECT results_eq('pl03sw09sw02V2Array', 'pl03sw09sw02V2Select',
                  'test PL0003,SW0009,SW0002 (v3) - striktni vazba a poradi  neni vyzadovano');
-- zavislost nebyla tak zkusim zobrazit vse pro PL003 7.11
PREPARE pl03AllArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]),
                               ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.6.0.0)"}'::sdm.t_check_compatibility[]),
                               ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.7.0.0)"}'::sdm.t_check_compatibility[])

;



PREPARE pl03AllV2Select AS SELECT *
                           FROM sdm.f_get_compatible_versions_v3(ARRAY [
                                                                     ROW ('PL0003'::text,'7.11.0.0'::text)
                                                                     ]:: sdm.t_check_compatibility[],
                                                                 '{check_all}'::sdm.t_check_flag[]);
SELECT results_eq('pl03AllArray', 'pl03AllV2Select', 'test PL0003 (v3) - vsechny vazby s check_all');


-- zavislost pro PL003 7.11 jsem nasel, zajima mne co muzu pouzit za verze SW0009
-- a jake dalsi komponenty  budu potrebovat
PREPARE pl03sw09V1allArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0009,2.8.0.0)","(SW0003,2.130.4.0)","(SW0002,2.14.0.0)"}'::sdm.t_check_compatibility[]),
                                     ('{"(PL0003,7.11.0.0)","(SW0009,2.8.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)"}'::sdm.t_check_compatibility[])
;
PREPARE pl03sw09V2allArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.5.0.0)"}'::sdm.t_check_compatibility[]),
                                     ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.6.0.0)"}'::sdm.t_check_compatibility[]),
                                     ('{"(PL0003,7.11.0.0)","(SW0002,2.14.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)","(SW0009,2.8.0.0)","(SW0010,1.7.0.0)"}'::sdm.t_check_compatibility[])

;
PREPARE pl03sw09allSelect AS SELECT *
                             FROM sdm.f_get_compatible_versions(ARRAY [
                                                                    ROW ('PL0003'::text,'7.11.0.0'::text),
                                                                    ROW ('SW0009'::text,''::text)
                                                                    ]::sdm.t_check_compatibility[],
                                                                '{check_all}'::sdm.t_check_flag[]);
PREPARE pl03sw09allV2Select AS SELECT *
                               FROM sdm.f_get_compatible_versions_v3(ARRAY [
                                                                         ROW ('PL0003'::text,'7.11.0.0'::text),
                                                                         ROW ('SW0009'::text,''::text)
                                                                         ]::sdm.t_check_compatibility[],
                                                                     '{check_all}'::sdm.t_check_flag[]);
SELECT results_eq('pl03sw09V1allArray', 'pl03sw09allSelect',
                  'test PL0003 - vsechny vazeb na mozne SW0009 tj. s check_all');
SELECT results_eq('pl03sw09V2allArray', 'pl03sw09allV2Select',
                  'test PL0003 (v3) - vsechny vazeb na mozne SW0009 tj. s check_all');

-- ted uz vim ze cestan nejmensiho odporu je  SW0009 ve verzi 2.7, nepotrebuje dalsi komponenty mimo SW0008, tak overim
-- a je to tak, mam jeden radek, idealni stav nainstaluji si jeste SW0008,1.3.0.0
PREPARE pl03sw0927V1allArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0009,2.7.0.0)","(SW0008,1.3.0.0)"}'::sdm.t_check_compatibility[]);
PREPARE pl03sw0927V2allArray AS VALUES ('{"(PL0003,7.11.0.0)","(SW0003,2.130.4.0)","(SW0002,2.14.0.0)"}'::sdm.t_check_compatibility[]),
                                       ('{"(PL0003,7.11.0.0)","(SW0003,2.130.4.0)","(SW0008,1.4.0.0)"}'::sdm.t_check_compatibility[]),
                                       ('{"(PL0003,7.11.0.0)","(SW0009,2.7.0.0)","(SW0008,1.3.0.0)"}'::sdm.t_check_compatibility[]),
                                       ('{"(PL0003,7.11.0.0)","(SW0010,1.6.0.0)","(SW0002,2.14.0.0)"}'::sdm.t_check_compatibility[])
;


PREPARE pl03sw09sw10sw002Array AS VALUES ('{"(PL0003,7.9.0.0)","(SW0003,2.95.6.0)","(SW0002,2.13.0.0)"}'::sdm.t_check_compatibility[]),
                                         ('{"(PL0003,7.9.0.0)","(SW0003,2.95.6.0)","(SW0002,2.14.0.0)"}'::sdm.t_check_compatibility[]),
                                         ('{"(PL0003,7.9.0.0)","(SW0009,2.6.0.0)","(SW0002,2.12.0.0)"}'::sdm.t_check_compatibility[]),
                                         ('{"(PL0003,7.9.0.0)","(SW0009,2.6.0.0)","(SW0008,1.2.0.0)"}'::sdm.t_check_compatibility[]),
                                         ('{"(PL0003,7.9.0.0)","(SW0010,1.4.0.0)","(SW0002,2.12.0.0)"}'::sdm.t_check_compatibility[])
;

/* Get all versions of EPU [SW0002] and Autostar [SW0009] compatible with TEM Server 7.9 [PL0003] (tested only=FALSE)
 *
 * Expected result:
 * {'("PL0003","7.9.0.0")','("SW0002","2.12.0.0")','("SW0009","2.6.0.0")'}
 *
 * Status: OK
 */
SELECT *
FROM sdm.f_get_compatible_versions_v3(ARRAY [
                                          ROW ('PL0003'::text,'7.9.0.0'::text), -- TEM Server
                                          ROW ('SW0009'::text,''::text), -- Autostar
                                          ROW ('SW0002'::text,''::text) -- EPU
                                          ]::sdm.t_check_compatibility[], '{}'::sdm.t_check_flag[]);
/* Get all versions of Apollo [SW0008] and Autostar [SW0009] compatible with TEM Server 7.9 [PL0003] (tested only=FALSE)
 *
 * Expected result:
 * {'("PL0003","7.9.0.0")','("SW0008","1.2.0.0")','("SW0009","2.6.0.0")'}
 *
 * Status: OK
 */
SELECT *
FROM sdm.f_get_compatible_versions_v3(ARRAY [
                                          ROW ('PL0003'::text,'7.9.0.0'::text), -- TEM Server
                                          ROW ('SW0008'::text,''::text), -- Apollo
                                          ROW ('SW0009'::text,''::text) -- Autostar
                                          ]::sdm.t_check_compatibility[], '{}'::sdm.t_check_flag[]);
/* Get all versions of Apollo [SW0008], EPU [SW0002] and Autostar [SW0009] compatible with TEM Server 7.9 [PL0003] (tested only=FALSE)
 * - there is no relation between Apollo and EPU, these are independent applicastions
 *
 * Expected result:
 * {'("PL0003","7.9.0.0")','("SW0002","2.12.0.0")','("SW0008","1.2.0.0")','("SW0009","2.6.0.0")'}
 *
 * Status: NOT OK
 */
-- select * from sdm.f_get_compatible_versions_v3(array[
--                                                    row('PL0003'::text,'7.9.0.0'::text), -- TEM Server
--                                                    row('SW0002'::text,''::text), -- EPU
--                                                    row('SW0008'::text,''::text), -- Apollo
--                                                    row('SW0009'::text,''::text) -- Autostar
--                                                    ]::sdm.t_check_compatibility[],'{}'::sdm.t_check_flag[]);
ROLLBACK;