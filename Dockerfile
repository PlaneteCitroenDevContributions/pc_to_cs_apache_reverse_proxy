# $Id: Dockerfile,v 1.2 2021/03/01 13:08:19 orba6563 Exp $

FROM httpd:2.4

RUN apt-get update \
    && \
    apt-get -y install \
       curl \
       gridsite-clients \
    && \
    apt-get clean