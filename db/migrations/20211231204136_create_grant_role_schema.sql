-- migrate:up

create role web_anon nologin;
grant usage on schema sdm to web_anon;
grant select on all tables IN SCHEMA sdm to web_anon;
-- migrate:down

