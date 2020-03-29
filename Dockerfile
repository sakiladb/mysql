FROM mysql:8
ENV MYSQL_ROOT_PASSWORD=p_ssW0rd
ENV MYSQL_DATABASE=sakila
ENV MYSQL_USER=sakila
ENV MYSQL_PASSWORD=p_ssW0rd

COPY ./sakila-schema.sql /docker-entrypoint-initdb.d/step_1.sql
COPY ./sakila-data.sql /docker-entrypoint-initdb.d/step_2.sql
