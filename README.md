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

### Zscaler

The dev container is designed to work with Zscaler. You will need to copy the required certs into the **.devcontainer/certs** folder.

### Custom Certificates

For details on how to add root CA certificates (including Zscaler and any development CAs), see the [Custom Certs Docs](.devcontainer/certs/README.md).

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

## Moodle configuration

Moodle will be configured using files located in `scripts/` and `resources/moodle/`.
When starting for the first time, Moodle will make a copy of some core files that will
be copied into mounts on the dev container's file system so that they are accessible for
debugging with xdebug. These files will be mounted alongside our repos under the folder
`/mnt/data/crucible/moodle/moodle-core/`. The xAPI logstore plugin will also be configured
automatically as will one default Moodle course with no activities within it.

### OAUTH

Moodle will be configured for oauth automatically. The oauth admin user has an email
address set and the Moodle client has a hard-coded secret.

After Moodle starts for the first time, login using the oauth admin user account and
it will than have an account on Moodle. Make the oauth admin account a site admin by
either logging in as local admin and using the Site Administration menu, or, simply
restart the Moodle container via the Aspire dashboard and when the container restarts,
the oauth admin user will be added to the list of site admins. Please note that every
time the container restarts the list of site admins will be reset to the local admin
and the oauth admin account. When the oauth admin account has been made a site admin,
login with it and navigate to the oauth server settings under Site Administration,
Server, and connect the system account. This will enable our plugins to communicate with
the various Crucible applications.

### Crucible Plugin

To configure Moodle to work with Crucible, oauth must be configured on Moodle, the service
account must be connected, and the user must be logged an with oauth.

### TopoMojo Plugin

To configure Moodle to work with TopoMojo, login to TopoMojo, generate an API key, and
add that API key to the Moodle crucible plugin's configuration in the Moodle UI or in the
script `post_configure.sh`.

### Developing New Moodle Plugins

To add new Moodle plugin repositories, add them to `scripts/repos.json`, `launch.json`,
`AppHost.cs`, and the `xdebug_filter.sh` files.

### Adding Additional Official Plugins for Moodle

To add additional plugins, add them to the `PLUGINS` environment variable in `AppHost.cs`.

### Moodle PHP Debugging with xdebug

If you do not wish to debug Moodle, simply run Moodle via the `Moodle` task. Id you do wish
to debug Mooodle, run Moodle via the `Moodle Debug` composite task. This task will start
both the Moodle and Xdebug tasks. The specific setting to control the xdebug mode is set
inside the `moodle.env` file or the `moodle-xdebug.env` file. Update the `XdebugMode` to
the type of xdebug feature(s) you wish to use.

The xdebug configuration is set to `off` in its configuration file, `xdebug.ini`, however
the `AppHost.cs` file sets the `XDEBUG_MODE` environment variable to enable it.

**PHP on the Moodle container will pause execution after the line `Upgrading config.php...`
if xdebug is enabled and the remote debugger in the devcontainer is not running.** To prevent
this from happening, ensure that the Xdebug task is running in vscode when `XDEBUG_MODE` is
enabled via the `AppHost.cs` file. An additional configuration for xdebug is enabled when the
mode includes `coverage`: `xdebug_filter.php`. This script is meant to limit the scope of the
code being analyzed by xdebug.

To make additional paths available for debugging, add the paths to `Dockerfile.MoodleCustom`,
`add-moodle-mounts.sh`, `AppHost.cs`, `pre_configure.sh` and `launch.json`.

### Moodle UI Debug Display

The standard Moodle debugging level and display via the UI can be set under the normal Site
Administration, Development, menu. The install process for this container installs the plugin
`tool_userdebug` which allows site admins to easily toggle debug display via an icon added
to the header just to the left of the user avatar in the upper right corner of the screen.
This is the preferred method to enable display of debug messages inside of the browser.
