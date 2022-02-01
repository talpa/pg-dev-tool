BEGIN;
SELECT plan(10);
SELECT ok(sdm.f_semver_match('1.0.0.5','1.0.0.5'),'porovnani stejnych verzi 1.0.0.5');
SELECT ok(sdm.f_semver_match('1.0.0.5','= 1.0') ,'porovnani verze 1.0.0.5 a 1.0.*.*');
SELECT ok(sdm.f_semver_match('1.0.1.5','= 1.0.1'),'porovnani verze 1.0.1.5 a 1.0.1.*');
SELECT ok(sdm.f_semver_match('1.0.0.5','=1.0.0'),'porovnani verze 1.0.0.5 a verze 1.0.0.*');
SELECT ok(sdm.f_semver_match('1.0.0.5','>=1.0'),'porovnani verze 1.0.0.5 a verze  1.0.*.* nebo vyssi');
SELECT ok(sdm.f_semver_match('1.0.0.5','< 2.0'), 'porovnani verze 1.0.0.5 a mensi nez 2.0.*.*');

SELECT ok(not sdm.f_semver_match('1.0.0.5','<=1.0'),'porovnani verze 1.0.0.5 a verze stejne 1.0.0.0');--tady nutno proverit, zrejme zlobi, podle mne by mela projit
SELECT ok(not sdm.f_semver_match('1.0.0.5','>2.0'),'porovnani verze 1.0.0.5 a verze vyssi nez 2.0.*.*');
SELECT ok(not sdm.f_semver_match('1.0.0.5','>1.0.0.5'),'porovnani verze 1.0.0.5 a verze vyssi nez 1.0.0.5');
SELECT ok(not sdm.f_semver_match('1.0.0.5','1.0.0.6'),'porovnani verze 1.0.0.5 a verze vyssi nez 1.0.0.6');
ROLLBACK;