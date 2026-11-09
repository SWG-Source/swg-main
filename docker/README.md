# SWG Source 64-bit server in Docker

The quickest way to get a 64-bit SWG Source server running. Two containers:

- **oracle**: Oracle Database Free 23, with the data kept in a Docker volume.
- **swg**: the whole 64-bit server cluster (login, game, chat), compiled from this repository's `master`.

You don't need to install Oracle, Java, CMake or a compiler yourself. Everything is built inside the image.

## What you need

- A 64-bit Linux machine (or WSL2 / Docker Desktop) with **Docker** and **Docker Compose**.
- About **25 GB** of free disk space and **8 GB** of RAM. More cores make the build faster.
- The SWG game client on the PC you play from.

## Start it

1. Get this folder:

   ```
   git clone https://github.com/SWG-Source/swg-main.git
   cd swg-main/docker
   ```

2. Tell it which address your game client will connect to. This is the IP of the machine running Docker as your PC sees it, for example `192.168.1.50` on a home network:

   ```
   cp .env.example .env
   nano .env          # set SWG_PUBLIC_IP
   ```

3. Build and start:

   ```
   docker compose up -d --build
   ```

   The first build compiles the whole server and takes a while (roughly 20 to 60 minutes, depending on the machine). Later starts take seconds.

4. Watch it start:

   ```
   docker compose logs -f swg
   ```

   The first start creates the database, which takes a few more minutes. The server is ready once the game servers have started; with every planet loaded that takes several minutes.

5. In the game client's `login.cfg`, set the login server to your `SWG_PUBLIC_IP`, port `44453`, and log in.

## Everyday use

| To... | Run |
| --- | --- |
| Stop the server (saves first, about a minute) | `docker compose stop` |
| Start it again | `docker compose start` |
| Follow the logs | `docker compose logs -f swg` |
| Rebuild with the latest code | `docker compose build --no-cache swg && docker compose up -d` |
| Delete everything, **including the database** | `docker compose down -v` |

The database lives in the `oradata` volume, so stopping, starting and rebuilding keep your accounts and characters. Only `down -v` deletes them.

## Settings

Put these in `.env`:

| Setting | Meaning | Default |
| --- | --- | --- |
| `SWG_PUBLIC_IP` | Address game clients connect to. The game ports are only published on this address. | (required) |
| `MAKE_JOBS` | Parallel compile jobs. Set it to your number of CPU cores. | `8` |
| `SWG_MAIN_REF` | swg-main branch, tag or commit to build. | `master` |
| `SWG_STOP_TIMEOUT` | Seconds a stop may take to save before the remaining servers are killed. Keep it under `stop_grace_period` (5 minutes) in `docker-compose.yml`. | `240` |

The build settings themselves (64-bit, compiler, library paths, database connection) are in `swg.properties`.

## What happens on each start

- The server config is pointed at the container's own address, and clients are told to use `SWG_PUBLIC_IP`.
- **Empty database:** the schema, the cluster entry and the object templates are created. New databases are labelled with the `gcc32` station id scheme automatically.
- **Every start:** `ant update_database` applies any database updates the code needs. Updates that are already applied are skipped.
- The chat server, login server and the rest of the cluster start.

## What happens on stop

`docker compose stop` shuts the cluster down the normal way, so the world is saved: players get the shutdown warnings, the database runs a final save, and the servers stop. It takes about a minute, and the log ends with `Cluster saved and stopped`. If it takes longer than `SWG_STOP_TIMEOUT`, the remaining servers are killed.

## Using an existing database

This setup creates a new database. To move an existing server's data in, import it into the `oracle` container and make sure its station id scheme is recorded before the first start. See `src/game/server/database/tools/station_id_scheme/README.md` and the [Building The 64-bit Server](https://github.com/SWG-Source/swg-main/wiki/Building-The-64-bit-Server) wiki page.

## Toolchain

Ubuntu 18.04, GCC 7.5, CMake 3.17, OpenJDK 11 (64-bit), Oracle Instant Client 21 (64-bit), Oracle Database Free 23. The exact revisions built are written to `/swg-main/BUILD-REVISIONS.txt` inside the image.

Oracle Instant Client and Oracle Database Free are downloaded from Oracle under Oracle's own license terms.

Based on [tekaohswg/swg-docker](https://github.com/tekaohswg/swg-docker), which builds the 32-bit server.
