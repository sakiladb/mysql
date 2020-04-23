# sakiladb/mysql

MySQL docker image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/)
example database.
See on [Docker Hub](https://hub.docker.com/r/sakiladb/sqlserver).

By default these are created:
- database: `sakila`
- username / password: `sakila` / `p_ssW0rd`


```shell script
docker run -p 3306:3306 -d sakiladb/mysql:latest
```

Or use a specific version of MySQL (see all available image tags
on [Docker Hub](https://hub.docker.com/r/sakiladb/mysql/tags).)

```shell script
docker run -p 3306:3306 -d sakiladb/mysql:8
```

Note that it may take some time for the container to boot up. Eventually the container's
docker logs will show:

```
sakiladb/sqlserver has successfully initialized.
```

Note that even after this message is logged, it may take another few moments for
it to become available (due to a final server restart etc).

Verify that all is well (using the `mysql` command line tool):

```shell script
$ mysql --host=127.0.0.1 --port=3306 --user=sakila  --password=p_ssW0rd sakila -e 'SELECT * FROM actor LIMIT 5'
mysql: [Warning] Using a password on the command line interface can be insecure.
+----------+------------+--------------+---------------------+
| actor_id | first_name | last_name    | last_update         |
+----------+------------+--------------+---------------------+
|        1 | PENELOPE   | GUINESS      | 2006-02-15 04:34:33 |
|        2 | NICK       | WAHLBERG     | 2006-02-15 04:34:33 |
|        3 | ED         | CHASE        | 2006-02-15 04:34:33 |
|        4 | JENNIFER   | DAVIS        | 2006-02-15 04:34:33 |
|        5 | JOHNNY     | LOLLOBRIGIDA | 2006-02-15 04:34:33 |
+----------+------------+--------------+---------------------+
```
