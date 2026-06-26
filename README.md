# sakiladb/mysql

A MySQL Docker image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) sample
database. One of the [`sakiladb`](https://github.com/sakiladb) image family.

These images exist primarily as test fixtures for [`sq`](https://github.com/neilotoole/sq), a
command-line tool for querying SQL databases and structured data — but they are free for anyone to
use. See sq's [MySQL driver guide](https://sq.io/docs/drivers/mysql).

Available on [Docker Hub](https://hub.docker.com/r/sakiladb/mysql) and
[GitHub Container Registry](https://github.com/sakiladb/mysql/pkgs/container/mysql).

## Quick start

```shell
docker run -p 3306:3306 -d sakiladb/mysql:latest
```

The Sakila data is baked into the image, so there is no initialization step at startup — the
container is ready in a few seconds.

The image declares a Docker
[`HEALTHCHECK`](https://docs.docker.com/reference/dockerfile/#healthcheck), so you can wait for
readiness rather than guessing. Its status becomes `healthy` once MySQL is accepting connections:

```shell
docker run -p 3306:3306 -d --name sakila sakiladb/mysql:latest
until [ "$(docker inspect -f '{{.State.Health.Status}}' sakila)" = healthy ]; do sleep 1; done
```

In Docker Compose, gate dependents with `depends_on: { condition: service_healthy }`. (MySQL also
logs its native `ready for connections` line.)

## Connection

| Setting    | Value       |
|------------|-------------|
| host       | `localhost` |
| port       | `3306`      |
| database   | `sakila`    |
| user       | `sakila`    |
| password   | `p_ssW0rd`  |

Any MySQL client works with the settings above. For example, with
[`sq`](https://github.com/neilotoole/sq) ([install](https://sq.io/docs/install)):

```shell
$ sq add 'mysql://sakila:p_ssW0rd@localhost:3306/sakila' --handle @sakila_my
@sakila_my  mysql  sakila@localhost:3306/sakila

$ sq '@sakila_my.actor | .[0:5]'
actor_id  first_name  last_name     last_update
1         PENELOPE    GUINESS       2006-02-15T04:34:33Z
2         NICK        WAHLBERG      2006-02-15T04:34:33Z
3         ED          CHASE         2006-02-15T04:34:33Z
4         JENNIFER    DAVIS         2006-02-15T04:34:33Z
5         JOHNNY      LOLLOBRIGIDA  2006-02-15T04:34:33Z
```

## What's inside

The standard Sakila sample database — **16 tables and 7 views**, all owned by the `sakila` user.

[`sq inspect`](https://sq.io/docs/inspect) shows the whole schema — tables, views, row counts, and
columns — at a glance:

```shell
$ sq inspect @sakila_my
SOURCE      DRIVER  NAME    FQ NAME     SIZE   TABLES  VIEWS  LOCATION
@sakila_my  mysql   sakila  def.sakila  1.8MB  16      7      mysql://sakila:xxxxx@localhost:3306/sakila

NAME                        TYPE   ROWS   COLS
actor                       table  200    actor_id, first_name, last_name, last_update
address                     table  603    address_id, address, address2, district, city_id, postal_code, phone, last_update
category                    table  16     category_id, name, last_update
city                        table  600    city_id, city, country_id, last_update
country                     table  109    country_id, country, last_update
customer                    table  599    customer_id, store_id, first_name, last_name, email, address_id, active, create_date, last_update
film                        table  1000   film_id, title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, length, replacement_cost, rating, special_features, last_update
film_actor                  table  5462   actor_id, film_id, last_update
film_category               table  1000   film_id, category_id, last_update
film_text                   table  1000   film_id, title, description
inventory                   table  4581   inventory_id, film_id, store_id, last_update
language                    table  6      language_id, name, last_update
payment                     table  16049  payment_id, customer_id, staff_id, rental_id, amount, payment_date, last_update
rental                      table  16044  rental_id, rental_date, inventory_id, customer_id, return_date, staff_id, last_update
staff                       table  2      staff_id, first_name, last_name, address_id, picture, email, store_id, active, username, password, last_update
store                       table  2      store_id, manager_staff_id, address_id, last_update
actor_info                  view   200    actor_id, first_name, last_name, film_info
customer_list               view   599    ID, name, address, zip code, phone, city, country, notes, SID
film_list                   view   997    FID, title, description, category, price, length, rating, actors
nicer_but_slower_film_list  view   997    FID, title, description, category, price, length, rating, actors
sales_by_film_category      view   16     category, total_sales
sales_by_store              view   2      store, manager, total_sales
staff_list                  view   2      ID, name, address, zip code, phone, city, country, SID
```

## Differences from other sakila variants

`sakiladb/mysql` is the **reference** variant — the original MySQL Sakila that every other sakiladb
image is ported from (via [jOOQ](https://www.jooq.org/sakila)). It defines the family's 16-table /
7-view shape, so there is little to "differ": the other variants are adapted to match this one, not
the reverse. Two things are worth noting:

- **Identifiers preserve the original case.** MySQL keeps Sakila's mixed-case view columns — e.g.
  `customer_list.ID` / `.SID`, `film_list.FID` — which case-folding engines such as Postgres render
  lower-case.
- **`address` has no `location` column.** Upstream MySQL Sakila ships a spatial `GEOMETRY` column
  there (gated to MySQL 5.7.5+); this image removes it so `address` is the same 8 columns across the
  whole family, with no spatial-type dependency that engines like ClickHouse or rqlite can't
  represent. (See [#4](https://github.com/sakiladb/mysql/issues/4).)

`film_text` here is a real, **trigger-populated** table (kept in sync with `film`) — the other
variants reproduce it structurally.

## Available versions

Each MySQL version is published as its own image tag. `latest` tracks the newest version
(currently 9).

| MySQL     | sakiladb Release | Architecture     | Docker Hub                    | GitHub Container Registry             |
|-----------|------------------|------------------|-------------------------------|---------------------------------------|
| 9 (9.7.x) | `v9.0.2`         | `amd64`, `arm64` | `sakiladb/mysql:9`, `:latest` | `ghcr.io/sakiladb/mysql:9`, `:latest` |
| 8 (8.4.x) | `v8.0.5`         | `amd64`, `arm64` | `sakiladb/mysql:8`            | `ghcr.io/sakiladb/mysql:8`            |
| 5.7       | `v5.7.5`         | `amd64`          | `sakiladb/mysql:5.7`          | `ghcr.io/sakiladb/mysql:5.7`          |
| 5.6       | `v5.6.5`         | `amd64`          | `sakiladb/mysql:5.6`          | `ghcr.io/sakiladb/mysql:5.6`          |

The tags `9` and `8` follow MySQL's modern major-version scheme: `9` tracks the **9.7 LTS** (the newest
LTS, which supersedes 8.4) and `8` tracks the **8.4 LTS**; `5.6` and `5.7` keep MySQL's legacy
`major.minor` naming (where the minor was the de-facto major).

**sakiladb Release** is the git tag the current image was built from (see
[releases](https://github.com/sakiladb/mysql/releases)). For the modern series the version is
`v{MYSQL_MAJOR}.{MINOR}.{PATCH}` with the **major** tracking MySQL and the **minor**/**patch**
tracking sakiladb's own revisions (e.g. `v8.0.0` → `v8.0.1`); for the legacy series the first two
digits are the MySQL version and the third is the sakiladb revision (`v5.7.0` → `v5.7.1`).

Every version is published to both [Docker Hub](https://hub.docker.com/r/sakiladb/mysql) and
[GitHub Container Registry](https://github.com/sakiladb/mysql/pkgs/container/mysql), and is signed
with [cosign](https://github.com/sigstore/cosign). `5.6` and `5.7` are `amd64`-only because MySQL
published no arm64 base images for those versions.

## Releasing a new version

Maintainers: releases are tag-driven. Pushing a semver tag `vN.x.y` builds and publishes that MySQL
version — the version is derived from the tag, so there are no per-version branches. See
[CLAUDE.md](./CLAUDE.md) for the full, repeatable procedure.

## Changelog

### 2026-06-26

- **Restored faithful original data** (`v5.6.5`, `v5.7.5`, `v8.0.5`, `v9.0.2`) — the Sakila data is now
  byte-identical to the original MySQL Sakila: the Unicode accents the lineage had stripped from
  international place names (e.g. `Réunion`, `Coruña`, `Huánuco`) are restored. The object set is
  unchanged (16 tables + 7 views). Republished all versions.

### 2026-06-25

- **Deterministic view output** (`v5.6.4`, `v5.7.4`, `v8.0.4`, `v9.0.1`) — `film_list` and
  `nicer_but_slower_film_list` now sort their `GROUP_CONCAT` cast lists by actor name (`actor_info`
  was already ordered), so the views render byte-identically across the sakiladb family. Republished
  all versions.
- **MySQL `9` published** (`v9.0.0`) — `sakiladb/mysql:9` tracks the **9.7 LTS** (the
  newest LTS, GA May 2026, superseding 8.4; MySQL 8.0 reached EOL April 2026). `latest` now points at
  `9`. Multi-arch, full fixture intact (16 tables + 7 views, working `FULLTEXT` on `film_text`).
- **`customer_list` / `staff_list` zip column kept as canonical `zip code`** (`v5.6.3`, `v5.7.3`,
  `v8.0.3`). An interim `v*.2` renamed it to `zip_code`; that was reverted — `zip code` (with the
  space) is the form in upstream MySQL Sakila **and** pagila (a deliberate spaced-identifier feature),
  so it's preserved.
- **Modernized as a consistent sakiladb test fixture.** Removed the spatial `address.location`
  column (and its data) so `address` is 8 columns across the family — the one trim from upstream
  MySQL Sakila. Republished `5.6`, `5.7`, and `8`.
- The `8` tag now tracks the **8-series LTS (8.4)** via `mysql:8` (previously 8.0).
- Every version now declares a Docker `HEALTHCHECK` (`mysqladmin ping`), is mirrored to GitHub
  Container Registry, and is cosign-signed.
- Switched to the tag-driven release workflow (single `master` branch; no per-version branches).

### 2023-08-26

- Initial release: MySQL `5.6`, `5.7`, `8`.

## License

[BSD 2-Clause](./LICENSE).
