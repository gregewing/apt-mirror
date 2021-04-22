FROM ubuntu:latest

MAINTAINER Greg Ewing (https://github.com/gregewing)

ENV LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/London


COPY scripts /var/spool/apt-mirror/

###  Set local repository  ###
RUN echo \
# && cp /etc/apt/sources.list /etc/apt/sources.list.default \
# && mv /var/spool/apt-mirror/sources.list.localrepo /etc/apt/sources.list \
 && apt-get -q -y update \
 && apt-get -q -y full-upgrade \
 && apt-get -q -y install apt-mirror \
                          wget \
                          nginx \
                          cron \
                          nano \
                          iproute2 \
 && apt-get -q -y clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
# && mv /etc/apt/sources.list.default /etc/apt/sources.list \
# && echo Reverted sources.list to default \
 && mv /etc/apt/mirror.list /etc/apt/mirror.list.default \
 && mv /var/spool/apt-mirror/mirror.list /etc/apt/mirror.list \
 && mv /var/spool/apt-mirror/sites-enabled_default /etc/nginx/sites-enabled/default \
 && echo Finished.


EXPOSE 80 

VOLUME ["/var/spool/apt-mirror"]

ENTRYPOINT ["/var/spool/apt-mirror/entrypoint.sh"]
