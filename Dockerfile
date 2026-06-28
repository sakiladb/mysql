# check=skip=SecretsUsedInArgOrEnv
# ^ The *_PASSWORD values below are the public, documented Sakila fixture
#   credential (p_ssW0rd) — these are throwaway test-fixture images with a
#   fixed, published password, not a secret. This lint rule is skipped.

# MySQL version to build. The CI release workflow overrides this per release,
# deriving it from the git tag (e.g. v9.0.0 -> 9, v8.0.1 -> 8, v5.7.1 -> 5.7).
# The default is the newest version, for convenient local `docker build`.
ARG MYSQL_VERSION=9

FROM mysql:${MYSQL_VERSION} AS builder
ENV MYSQL_ROOT_PASSWORD=p_ssW0rd
ENV MYSQL_DATABASE=sakila
ENV MYSQL_USER=sakila
ENV MYSQL_PASSWORD=p_ssW0rd

COPY ./1-sakila-schema.sql /docker-entrypoint-initdb.d/step_1.sql
COPY ./2-sakila-data.sql /docker-entrypoint-initdb.d/step_2.sql
COPY ./3-sakila-complete.sql /docker-entrypoint-initdb.d/step_3.sql

# Neuter the entrypoint's `exec "$@"` so it initializes the database into
# /var/lib/mysql and then exits, instead of staying up as a server.
# https://serverfault.com/questions/930141/creating-a-mysql-image-with-the-db-preloaded
# https://serverfault.com/questions/796762/creating-a-docker-mysql-container-with-a-prepared-database-scheme
RUN ["sed", "-i", "s/exec \"$@\"/echo \"skipping...\"/", "/usr/local/bin/docker-entrypoint.sh"]

USER mysql
RUN ["/usr/local/bin/docker-entrypoint.sh", "mysqld"]

FROM mysql:${MYSQL_VERSION}
ENV MYSQL_ROOT_PASSWORD=p_ssW0rd
ENV MYSQL_DATABASE=sakila
ENV MYSQL_USER=sakila
ENV MYSQL_PASSWORD=p_ssW0rd

# Copy the populated data dir from the builder stage; the published image ships
# with Sakila already loaded, so there is no init cost at container start.
COPY --from=builder /var/lib/mysql /data
RUN rm -rf /var/lib/mysql/*
RUN mv /data/* /var/lib/mysql/

USER mysql

# Readiness probe: the container reports `healthy` once MySQL is accepting TCP
# connections. mysqladmin can emit a password-on-CLI warning to stderr
# (harmless); discard it and normalize any failure to exit 1.
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=5 \
  CMD mysqladmin ping -h 127.0.0.1 -u sakila -pp_ssW0rd --silent 2>/dev/null || exit 1

# See: https://dev.to/mdemblani/docker-container-uncaught-kill-signal-10l6
COPY ./signal-listener.sh /sakila/run.sh
# Entrypoint overload to catch the ctrl+c and stop signals
ENTRYPOINT ["/bin/bash", "/sakila/run.sh"]
