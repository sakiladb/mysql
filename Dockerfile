FROM mysql:8 as builder

COPY ./1-sakila-schema.sql /docker-entrypoint-initdb.d/step_1.sql
COPY ./2-sakila-data.sql /docker-entrypoint-initdb.d/step_2.sql
COPY ./3-sakila-complete.sql /docker-entrypoint-initdb.d/step_3.sql

RUN mkdir -p /outer
RUN chmod -R 777 /outer

# https://serverfault.com/questions/930141/creating-a-mysql-image-with-the-db-preloaded
# https://serverfault.com/questions/796762/creating-a-docker-mysql-container-with-a-prepared-database-scheme
RUN ["sed", "-i", "s/exec \"$@\"/echo \"skipping...\"/", "/usr/local/bin/docker-entrypoint.sh"]

RUN ["cat", "/usr/local/bin/docker-entrypoint.sh"]

USER mysql

ENV MYSQL_ROOT_PASSWORD=p_ssW0rd
ENV MYSQL_DATABASE=sakila
ENV MYSQL_USER=sakila
ENV MYSQL_PASSWORD=p_ssW0rd

# Need to change the datadir to something else that /var/lib/mysql because the parent docker file defines it as a volume.
# https://docs.docker.com/engine/reference/builder/#volume :
#       Changing the volume from within the Dockerfile: If any build steps change the data within the volume after
#       it has been declared, those changes will be discarded.

RUN echo "We are before the thingy"
# "/usr/local/bin/docker-entrypoint.sh mysqld --datadir /outer/wubble"
RUN ["/usr/local/bin/docker-entrypoint.sh", "mysqld"]
RUN echo "We are after the thingy"

#CMD ["echo", "huzzah"]
ENTRYPOINT ["/bin/bash", "-c", "echo Welcome, huzzah!"]


FROM mysql:8

ENV MYSQL_ROOT_PASSWORD=p_ssW0rd
ENV MYSQL_DATABASE=sakila
ENV MYSQL_USER=sakila
ENV MYSQL_PASSWORD=p_ssW0rd
COPY --from=builder /var/lib/mysql /data
RUN chmod -R 777 /data
USER mysql

CMD ["--datadir", "/data"]
