# crucible-development

Development Environment for Crucible

# Getting Started

`crucible-development` is a [Development-Containers](https://containers.dev/)-based solution that uses .NET Aspire to orchestrate the various components of Crucible, along with supporting resources like an identity provider (Keycloak), a Postgres database server, and PGAdmin.

## Setting up Docker

To use any dev container, you'll need to run Docker on your machine. [Docker Desktop](https://www.docker.com/) is a great way to get started if you're not confident administering Docker from the command line.

### Setting memory and storage limits

If you're on a Windows machine, Docker's consumption of your host machine's memory and storage is managed by [WSL2](https://learn.microsoft.com/en-us/windows/wsl/about). These will automatically scale to a percentage of your system's available resources, so you typically don't need to do any additional configuration.

**If you're on Mac/Linux using Docker Desktop**, you'll need to manually adjust these limits. In Docker Desktop, go to Settings -> Resources. We recommend the following minimums:

- Memory Limit: 16GB
- Disk Usage Limit: 120GB

## Troubleshooting

This repo is still under construction, so you may run into the occasional challenge or oddity. From our lessons learned:

- **Aspire resources appearing to have exited with no crash log:** Use Docker Desktop or otherwise exec into the container and run `docker ps -a` to see all containers, regardless of their status. Stopped containers typically show an error code that might give you a hint.
- **`npm i` issues:** Even though the devcontainer allows us to work in a container based on the same image, the image has independent builds for various architectures. This means that when you `npm i` in a `x86_64` container, some dependnecies may require precompiled binaries there that are unavailable on the ARM version. An ARM environment needs to compile these locally, which may require additional APT packages. This is why our `postcreate.sh` installs `python3-dev` currently. TL;DR - if you're having problems related to `npm install` in your container, shell in and execute it yourself to see the error log. It may be related to an OS package dependency that isn't present by default in the image.

## Known issues

- Some extensions (e.g. C#) very rarely seem to fail to install in the container's VS Code environment. If you see weird intellisense behavior or have compilation/debugging problems, ensure all extensions in the `devcontainers.json` file are installed in your container.


# Database seeding and backup
## setup
... using blueprint as the example
create a db-dumps folder under crucible-dev
copy your blueprint.dump file into the db-dumps folder

## seed/restore a database
navigate to the db-dumps folder in the integrated terminal
drop the blueprint database using pgadmin
create a new blueprint database using pgadmin
assuming crucible-postgres is the postgres container name,
docker cp blueprint.dump crucible-postgres:/tmp/blueprint.dump
docker exec -it crucible-postgres /bin/bash
/usr/lib/postgresql/17/bin/psql --username=postgres blueprint < /tmp/blueprint.dump
exit

## backup/dump a database
docker exec -it crucible-postgres /bin/bash
pg_dump -U postgres blueprint > /tmp/blueprint.dump
exit
docker cp crucible-postgres:/tmp/blueprint.dump blueprint.dump
