<img src="settings.png" width="100"/><br/>
# sdm_db_migration 
the Swiss Army Knife of Test DB Migrations and DB Integration Tests

**Technologies:**
- Docker compose 3.4 - container engine 
- Make - build tool
- Postgres 13.3 - db server 
- PgTap - unit tests for postgres
- DBMate - migration tool 

Special thanks Martin Tengler for init data scripts.

# Installation / configuration
Please install Docker compose and maketools
For OS win used to [cygwin](https://www.cygwin.com/) or [wsl](https://docs.microsoft.com/en-us/windows/wsl/install) please.

**WSL**
- Install WSL with Ubuntu: https://docs.microsoft.com/en-us/windows/wsl/install	
- Make sure that make, sed and git are already installed	
- Install docker engine: https://docs.docker.com/engine/install/ubuntu/	
- Install docker compose command: https://docs.docker.com/compose/cli-command/#install-on-linux	
- Connect to GIT: https://www.geeksforgeeks.org/how-to-install-configure-and-use-git-on-ubuntu	
- Synchronize cdm_dbmigration project to your Ubuntu	
- Upload remote.env file to cdm_db_migration project	
- Add you Ubuntu user to "docker" group: sudo usermod -a -G docker martin	
- Start docker daemon: sudo service  docker start

# Tutorial for test dev environment

1. run command  `make tests` for run all integration tests
  this command 
    - starts database 
    - run all migration scripts 
    - run all tests


# Tutorial for migration script

1. run command  `make init` this create db postgres in docker
2. run command  `make new your_file_name_without_sql_postfix` for create file for your change in directory db/migration
3. change this created file.
4. please write test in tests directory for your changes in previous step.
5. run command  `make up`  for integrate all for local db, this command created schema.sql file (with all changes) too. 
6. run command  `make tests` for run all integration tests (now it is possible run step 6 without previous step 5 )
7. that's all when you are finished, than you can run `make destroy` but it is not required.

Enjoy

# Tutorial for first new initial script from db
1. add remote.env file with one environment into root project  
`DATABASE_URL="postgres://{user}:{password}@postgres-kolman.cwt2igihcx97.eu-central-1.rds.amazonaws.com:5432//{any_remote_sandbox_db}?sslmode=disable"` Please  write me for remote.env and password.
2. run command  `make dump-remote` for create dump schema.sql in db/migrations from remote db
3. run command  `make dump-local` for create dump schema.sql in db/migrations from local docker db (you must remove insert into migrations handly, my sed regex knowledge are limited:) ) 
3. run command  `make destroy` for destroy old local postgres docker image
4. run command  `make up` for test migration, (2 more files may need to be changed)
5. run command  `make tests` for run all unit tess (now it is possible run step 5 without previous step 4 )
6. that's all 

# Tutorial for dump local  docker db
1. run command  `make dump-local` for create dump schema.sql in db/migrations from local docker db (you must remove insert into migrations handly, my sed regex knowledge are limited:) ) 
3. run command  `make destroy` for destroy old local postgres docker image, (only for migration test, create the same local db from local dump)
4. run command  `make up` for test migration, (create the same local db from local migration dump)
5. run command  `make tests` for run all unit tess (now it is possible run step 5 without previous step 4 )
6. that's all

# Tutorial postgREST 
1. run command  `make restapi` 
2. try get via curl  `curl -X GET  "http://localhost:3000/software"`


# Tutorial swagger 
1. run command  `make swagger` (start make restapi container if not exists)
2. open url via browser  `http://localhost:8080/`

Enjoy
Ales 
