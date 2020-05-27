FROM debian:stretch-slim

LABEL based_on_maintainer="Christian Luginbühl <dinkel@pimprecords.com>"
LABEL based_on="https://github.com/dinkel/docker-openldap"
LABEL maintainer="Ravindra Bhadti <rbhadti@gmail.com>"

ARG OPENLDAP_VERSION=2.4.44

# When not limiting the open file descritors limit, the memory consumption of
# slapd is high. See https://github.com/docker/docker/issues/8231
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    slapd=${OPENLDAP_VERSION}* gettext-base && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo '#!/bin/bash' > /bin/ldap && \ 
    echo 'ulimit -n 32768' >> /bin/ldap && \ 
    echo 'exec slapd "$@"' >> /bin/ldap && \
    chmod 755 /bin/ldap && \
    useradd -u 1001 ldap && \
    chown -R ldap /var/lib/ldap && \
    chown -R ldap /etc/ldap && \
    chown -R ldap /var/run/slapd && \
    mv /etc/ldap /etc/ldap.dist

USER ldap

WORKDIR /etc/ldap

# Non-root users cannot bind to ports below 1024
EXPOSE 8389 8636

VOLUME ["/etc/ldap", "/var/lib/ldap"]

ENTRYPOINT ["ldap"]

CMD ["-d", "32768", "-u", "ldap", "-h", "ldap://0.0.0.0:8389"]