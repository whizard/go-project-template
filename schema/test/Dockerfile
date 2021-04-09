FROM mysql:5.7

ARG ROOT_PASS=0mad1
ARG DATABASE=platform
ARG PASSWORD=platform

ENV MYSQL_ROOT_PASSWORD=${ROOT_PASS}
ENV MYSQL_DATABASE=${DATABASE}
ENV MYSQL_PASSWORD=${PASSWORD}

# Add database initialization file
COPY ./platform.sql /docker-entrypoint-initdb.d/

# Entrypoint overload to catch the ctrl+c and stop signals
COPY run.sh /run.sh
ENTRYPOINT ["/bin/bash", "/run.sh"]
CMD ["mysqld"]
