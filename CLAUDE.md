# CLAUDE.md

Maintainer guide for **`sakiladb/mysql`** — a MySQL Docker image preloaded with the
[Sakila](https://dev.mysql.com/doc/sakila/en/) sample database, published to
[Docker Hub](https://hub.docker.com/r/sakiladb/mysql) and
[GitHub Container Registry](https://github.com/sakiladb/mysql/pkgs/container/mysql).

> One of the [`sakiladb`](https://github.com/sakiladb) image family (`postgres`, `mysql`,
> `sqlserver`, `oracle`, `clickhouse`, `rqlite`). The release machinery in
> [How releases work](#how-releases-work) is **shared across the family** (the reference template
> lives in [`sakiladb/postgres`](https://github.com/sakiladb/postgres)); the build details in
> [How the image is built](#how-the-image-is-built) are **MySQL-specific**. The org-level landing
> page ([github.com/sakiladb](https://github.com/sakiladb)) is rendered from the
> [`sakiladb/.github`](https://github.com/sakiladb/.github) repo (`profile/README.md`); edit it there
> to change the family overview.

## Purpose

These images exist primarily as **test fixtures for the [`sq`](https://github.com/neilotoole/sq) CLI**.
`sq`'s suite runs against every variant and asserts a uniform Sakila schema, so each image must
expose the **same object set: 16 tables + 7 views** (see [The dataset](#the-dataset)). Treat that as
a hard consistency contract.

Because the schema is coupled to `sq`'s tests, **a schema change here is a cross-repo change**:
`sq`'s expectations must be updated in lockstep or its suite breaks against the new image. The
relevant `sq` files are `testh/sakila/sakila.go` (the canonical `AllTbls`/`AllTblsViews` sets and
per-table column/count constants), `libsq/driver/driver_test.go` (per-image table/view counts), and
`cli/cmd_inspect_test.go`.

## The dataset

The standard Sakila database, preloaded and owned by the `sakila` user: **16 tables + 7 views**.
MySQL Sakila is the **origin** of the whole family — the other variants are ported from it (via
[jOOQ](https://www.jooq.org/sakila)) — so this image is the reference, not a port. One trim keeps it
consistent with engines that can't easily represent spatial types:

- **`address` has no `location` column.** Upstream MySQL Sakila ships a spatial `GEOMETRY` column
  (`location`, with a `SPATIAL KEY`), gated to MySQL 5.7.5+. We removed it — the column from
  `1-sakila-schema.sql` and the gated `/*!50705 0x…,*/` literal from all 603 `address` rows in
  `2-sakila-data.sql` — so `address` is 8 columns everywhere in the family. (See the cross-repo
  rationale in [sakiladb/mysql#4](https://github.com/sakiladb/mysql/issues/4).)

`film_text` is a real, **trigger-populated** table here (the `INSERT`/`UPDATE`/`DELETE` triggers in
`1-sakila-schema.sql` keep it in sync with `film`). The other variants reproduce it structurally;
this is where they get it from.

## How the image is built

*(MySQL-specific.)* `Dockerfile` is a two-stage build that bakes the data into the image so there is
no initialization cost at container start. The base-image version is parameterized by an
`ARG MYSQL_VERSION` (default = newest), which the release workflow sets per build:

1. **`builder` stage** — `FROM mysql:${MYSQL_VERSION}`, copies the three SQL files into
   `/docker-entrypoint-initdb.d/`, neuters the entrypoint's `exec "$@"` (so the server doesn't stay
   running), then runs the entrypoint once to initialize the database into `/var/lib/mysql`.
2. **final stage** — `FROM mysql:${MYSQL_VERSION}` again, copies the populated `/var/lib/mysql` from
   the builder stage. The published image ships with Sakila already loaded.

The three init SQL files run in order (the stock MySQL entrypoint runs `/docker-entrypoint-initdb.d/`
as root, then creates the `sakila` user/db from the `MYSQL_*` env):

| File | Role |
|------|------|
| `1-sakila-schema.sql` | Schema: tables (incl. `film_text` + its triggers), views, indexes. |
| `2-sakila-data.sql` | Data (multi-row `INSERT` statements). |
| `3-sakila-complete.sql` | Grant `ALL PRIVILEGES` to `sakila`; log the completion message. |

> **Entrypoint quirk:** the final stage overrides the entrypoint with `signal-listener.sh`, a wrapper
> that traps `SIGINT`/`SIGTERM` and forwards them to `mysqld` (so `Ctrl+C` / `docker stop` shut down
> cleanly). It still launches the stock `docker-entrypoint.sh mysqld`, so MySQL starts normally
> against the pre-baked data dir. This is MySQL-specific and has no Postgres analogue.

### Readiness (HEALTHCHECK)

The final stage declares a Docker `HEALTHCHECK` (`mysqladmin ping … --silent`), so the container
reports `healthy` once MySQL accepts TCP connections — consumers wait on that rather than grepping
logs. It connects over TCP (`-h 127.0.0.1`) as the `sakila` user; `mysqladmin` can emit a
password-on-CLI warning to stderr, which the check discards, normalizing any failure to exit `1`.

> **Family convention:** every `sakiladb` image declares a `HEALTHCHECK` using its engine's native
> readiness probe (`pg_isready`, `mysqladmin ping`, `sqlcmd … SELECT 1`, …). The probe command
> differs per engine; the readiness *contract* (`healthy` = ready to serve) is uniform.

## How releases work

*(Shared across the `sakiladb` family.)*

Releases are **tag-driven**. There is a single long-lived branch, `master`, and **pushing a semver
tag `vN.x.y` publishes that MySQL version**. The version is read from the tag name, so the tag is the
sole source of truth for what gets built — there are **no per-version branches**.

- `.github/workflows/docker-publish.yml` builds on every push / PR / tag, but **only pushes to a
  registry on `v*.*.*` tags**. Branch pushes, PRs, and manual `workflow_dispatch` runs are build-only
  smoke tests.
- The **"Determine MySQL version" step** computes a *version label* that is both the published Docker
  tag and the `mysql:<label>` base image. MySQL's own versioning is irregular, so the mapping is too:

  | Git tag | Label | Base image | Resolves to | Why |
  |---------|-------|-----------|-------------|-----|
  | `v5.6.x` | `5.6` | `mysql:5.6` | 5.6.x | legacy scheme — the minor was the de-facto major |
  | `v5.7.x` | `5.7` | `mysql:5.7` | 5.7.x | legacy scheme |
  | `v8.0.x` | `8`   | `mysql:8`   | **8.4.x** | modern semver — `8` tracks the newest 8-series LTS |
  | `v9.0.x` | `9`   | `mysql:9`   | 9.x | modern semver |

  For `5.6`/`5.7` the label keeps `major.minor`; for `8`+ it is the major only (and `mysql:8` tracks
  the newest minor of that series — currently 8.4, the terminal 8-series LTS). The label drives the
  build-arg, the published tag, and the **platform set** (see below). The step validates the label is
  digits with at most one dot.
- The tag produces the Docker tag **`{{label}}`** (`v8.0.1` → `8`), pushed to **both Docker Hub and
  GHCR**, and **cosign-signed**.

### Architectures (per version)

Unlike Postgres, MySQL's base images are **not uniformly multi-arch**: `mysql:5.6` and `mysql:5.7`
are **amd64-only**, while `mysql:8`/`mysql:9` are `amd64`+`arm64`. The "Determine MySQL version" step
emits a `platforms` output accordingly (`linux/amd64` for 5.6/5.7, `linux/amd64,linux/arm64`
otherwise), which the build step consumes. Don't hard-code multi-arch.

### The `latest` tag

`latest` must always point at the **newest** version. The workflow never auto-assigns it
(`flavor: latest=false`); it emits `latest` **only when the tag's label equals the `LATEST_VERSION`
env var** in the workflow. That env var is the one piece of state that cannot be derived from a tag
("which version is currently newest"). Because `latest` is gated on a fixed value rather than push
order, **tag-push order is irrelevant** and republishing an old version can never steal `latest`.

### Recipe: release a new major version (e.g. MySQL 10)

```bash
git switch master && git pull
# 1. In .github/workflows/docker-publish.yml, bump:  LATEST_VERSION: "10"
# 2. (Optional) bump the Dockerfile's `ARG MYSQL_VERSION=10` default, for local builds.
git commit -am "mysql 10 is now the newest"
git push origin master                       # build-only smoke test (builds mysql:10 via the new default)

# 3. Tag to publish `10` + `latest` (Docker Hub + GHCR):
git tag v10.0.0 && git push origin v10.0.0
```

That's it — no new branch, and nothing to "demote": the previous newest stops getting `latest`
automatically, because `latest` now keys off `LATEST_VERSION`.

### Recipe: republish or build any version (e.g. rebuild MySQL 5.7)

No branch needed — just tag `master`. `vX.Y.0` already exists, so bump to the next **unused** patch
(`git tag -l 'v5.7.*'` first).

```bash
git switch master && git pull
git tag v5.7.1 && git push origin v5.7.1     # builds & publishes `5.7`; `latest` untouched (5.7 ≠ LATEST_VERSION)
```

To preview an arbitrary version's build **without** publishing, run the workflow manually
(GitHub ▸ Actions ▸ Docker ▸ Run workflow ▸ `mysql_version = 5.7`), or build locally:
`docker build --build-arg MYSQL_VERSION=5.7 .`.

After any release:

1. **Verify the published artifact** — pull the image, confirm the schema (`16 tables + 7 views`,
   `address` = 8 columns) and the MySQL version, and confirm `latest` still points at the newest.
2. **Update the README "Available versions" table** — it is maintained by hand. Set the row's
   **sakiladb Release** cell to the new tag; for a brand-new version, add the row with its Docker Hub
   and GHCR cells. When the newest version changes, move the `:latest` annotation. Add a dated
   **Changelog** entry if the change is user-visible.

## Conventions

- **Credentials:** database / user / password = `sakila` / `sakila` / `p_ssW0rd`.
- **Tags:** Docker tag is the version label (`5.6`, `5.7`, `8`); `latest` on the newest. Git tags are
  `vX.Y.Z`: for `8`+ the **major** is the MySQL major and `.Y.Z` is sakiladb's revision (so `v8.0.1`,
  like Postgres); for the legacy `5.6`/`5.7` line the first two digits are the MySQL version and the
  third is the sakiladb revision (`v5.7.1`).
- **No AI attribution** in commits, tags, PRs, or any other content.
