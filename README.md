# Docker - OpenLDAP
This Dockerfile is for the OpenLDAP service. The original point of reference is the Dinkel OpenLDAP image - https://github.com/dinkel/docker-openldap. Please see the ```README.md``` inside that repository for configuration info.

This creates an **empty** LDAP instance without any configuration and simply starts the ```slapd``` service. This was built to be used with a Kubernetes cluster.

## Supported Tags
- [`2.4.44`, `2.4.44` (*2.4.44/Dockerfile*)](https://github.com/rbhadti94/docker-openldap/blob/2.4.44/Dockerfile)

## Usage
This image can be run with the ```docker run``` command.

```sh
docker volume create ldap_config_volume
docker volume create ldap_data
docker run -d \
-v ldap_config_volume:/etc/ldap \
-v ldap_data:/var/lib/ldap \
-p 8389:8389 \
-p 8636:8636 \
rbhadti/openldap:2.4.44
```

Or with ```docker-compose```.

```sh
version: '3.7'
services:
  ldap:
    image: "rbhadti/openldap:2.4.44"
    ports:
      - "8389:8389"
      - "8636:8636"
    volumes:
      - "ldap_config_volume:/etc/ldap"
      - "ldap_data:/var/lib/ldap"

volumes:
  ldap_config_volume
  ldap_data
```

The LDAP utlities and deb-conf packages can then be used to configure the SLAPD instance.