FROM mysql:8
ENV MYSQL_ROOT_PASSWORD=p_ssW0rd
ENV MYSQL_DATABASE=sakila
ENV MYSQL_USER=sakila
ENV MYSQL_PASSWORD=p_ssW0rd

COPY ./1-sakila-schema.sql /docker-entrypoint-initdb.d/step_1.sql
COPY ./2-sakila-data.sql /docker-entrypoint-initdb.d/step_2.sql
COPY ./3-sakila-complete.sql /docker-entrypoint-initdb.d/step_3.sql
