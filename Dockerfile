FROM httpd:2.4

RUN apt-get update \
    && \
    apt-get -y install \
       curl \
       gridsite-clients \
    && \
    apt-get clean

RUN apt-get update \
    && \
    apt-get -y install \
       ldap-utils \
    && \
    apt-get clean
