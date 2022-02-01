%:      # thanks to chakrit
	@:    # thanks to William Pursell
.PHONY: info
info:
	@echo \
"make init - init postgres\n"\
"make new [file_name] - create new migration file yyyymmddhhmm[file_name]\n"\
"make up - send all migration files  into db\n"\
"make dump-remote - create dump remote db\n"\
"make dump-local - create dump local db\n"\
"make tests - call all tests pgTaps\n"\
"make restapi - run restful server localhost:3000\n"\
"make swagger - run swagger server localhost:8080\n"\
"make destroy - remove all containers\n"

.PHONY: init
init:
	docker compose up -d postgres
.PHONY: new args
new: $(args)
	 docker compose run --rm dbmate new $(filter-out $@,$(MAKECMDGOALS))
.PHONY: up
up: init
	docker compose run --rm dbmate up
.PHONY: dump-remote
dump-remote:
	docker compose run --rm dbmate_orig dump
	sed \
-e 's/CREATE TABLE public.schema_migrations/CREATE TABLE IF NOT EXISTS public.schema_migrations/g' \
-e 's/ADD CONSTRAINT schema_migrations_pkey/DROP CONSTRAINT IF EXISTS schema_migrations_pkey,ADD CONSTRAINT schema_migrations_pkey/g' \
-e '1s/^/-- migrate:up\n/' \
-e '$$a\-- migrate:down\' \
 ./db/migrations/schema.sql > ./db/migrations/20211231044714_import.sql
	rm ./db/migrations/schema.sql
.PHONY: dump-local
dump-local:
	docker compose run --rm dbmate dump
	sed \
-e 's/CREATE TABLE public.schema_migrations/CREATE TABLE IF NOT EXISTS public.schema_migrations/g' \
-e 's/ADD CONSTRAINT schema_migrations_pkey/DROP CONSTRAINT IF EXISTS schema_migrations_pkey,ADD CONSTRAINT schema_migrations_pkey/g' \
-e '1s/^/-- migrate:up\n/' \
 ./db/schema.sql > ./db/migrations/20211231044714_import.sql
	sed  -i \
-e ':a;$$!N;1,9ba;P;$$d;D'  ./db/migrations/20211231044714_import.sql
	sed -i \
-e '$$a\-- migrate:down\' ./db/migrations/20211231044714_import.sql
.PHONY: tests
tests: up
	docker compose run pgtap
.PHONY: up
restapi:
	docker compose up -d restapi
.PHONY: swagger
swagger: restapi
	docker compose up -d swagger
.PHONY: destroy
destroy:
	docker compose down
