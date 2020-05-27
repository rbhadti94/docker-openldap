#!/bin/bash

# When not limiting the open file descritors limit, the memory consumption of
# slapd is absurdly high. See https://github.com/docker/docker/issues/8231
ulimit -n 8192

echo "Starting Container"

set -e

SLAPD_FORCE_RECONFIGURE="${SLAPD_FORCE_RECONFIGURE:-false}"

SLAPD_FULL_DOMAIN="${SLAPD_FULL_DOMAIN}"

first_run=true

# if [[ -f "/var/lib/ldap/DB_CONFIG" ]]; then 
#     first_run=false
# fi

if [[ ! -d /etc/ldap/slapd.d || "$SLAPD_FORCE_RECONFIGURE" == "true" ]]; then

    if [[ -z "$SLAPD_PASSWORD" ]]; then
        echo -n >&2 "Error: Container not configured and SLAPD_PASSWORD not set. "
        echo >&2 "Did you forget to add -e SLAPD_PASSWORD=... ?"
        exit 1
    fi

    if [[ -z "$SLAPD_DOMAIN" ]]; then
        echo -n >&2 "Error: Container not configured and SLAPD_DOMAIN not set. "
        echo >&2 "Did you forget to add -e SLAPD_DOMAIN=... ?"
        exit 1
    fi

    SLAPD_ORGANIZATION="${SLAPD_ORGANIZATION:-${SLAPD_DOMAIN}}"

    cp -r /etc/ldap.dist/* /etc/ldap

    cat <<-EOF | debconf-set-selections
        slapd slapd/no_configuration boolean false
        slapd slapd/password1 password $SLAPD_PASSWORD
        slapd slapd/password2 password $SLAPD_PASSWORD
        slapd shared/organization string $SLAPD_ORGANIZATION
        slapd slapd/domain string $SLAPD_DOMAIN
        slapd slapd/backend select HDB
        slapd slapd/allow_ldap_v2 boolean false
        slapd slapd/purge_database boolean false
        slapd slapd/move_old_database boolean true
EOF

    dpkg-reconfigure -f noninteractive slapd >/dev/null 2>&1

    dc_string=""

    IFS="."; declare -a dc_parts=($SLAPD_DOMAIN); unset IFS

    for dc_part in "${dc_parts[@]}"; do
        dc_string="$dc_string,dc=$dc_part"
    done

    base_string="BASE ${dc_string:1}"

    sed -i "s/^#BASE.*/${base_string}/g" /etc/ldap/ldap.conf

    if [[ -n "$SLAPD_CONFIG_PASSWORD" ]]; then
        password_hash=`slappasswd -s "${SLAPD_CONFIG_PASSWORD}"`
        echo "Config Password - $SLAPD_CONFIG_PASSWORD"
        sed_safe_password_hash=${password_hash//\//\\\/}

        slapcat -n0 -F /etc/ldap/slapd.d -l /tmp/config.ldif
        sed -i "s/\(olcRootDN: cn=admin,cn=config\)/\1\nolcRootPW: ${sed_safe_password_hash}/g" /tmp/config.ldif
        rm -rf /etc/ldap/slapd.d/*
        slapadd -n0 -F /etc/ldap/slapd.d -l /tmp/config.ldif
        rm /tmp/config.ldif
    fi

    if [[ -n "$SLAPD_ADDITIONAL_SCHEMAS" ]]; then
        echo "Additional Schemas - $SLAPD_ADDITIONAL_SCHEMAS"
        IFS=","; declare -a schemas=($SLAPD_ADDITIONAL_SCHEMAS); unset IFS

        for schema in "${schemas[@]}"; do
            slapadd -n0 -F /etc/ldap/slapd.d -l "/etc/ldap/schema/${schema}.ldif"
        done
    fi

    if [[ -n "$SLAPD_ADDITIONAL_MODULES" ]]; then
        IFS=","; declare -a modules=($SLAPD_ADDITIONAL_MODULES); unset IFS
        echo "Additional Modules - $SLAPD_ADDITIONAL_MODULES"
        for module in "${modules[@]}"; do
             module_file="/etc/ldap/modules/${module}.ldif"

             if [ "$module" == 'ppolicy' ]; then
                 SLAPD_PPOLICY_DN_PREFIX="${SLAPD_PPOLICY_DN_PREFIX:-cn=default,ou=policies}"

                 sed -i "s/\(olcPPolicyDefault: \)PPOLICY_DN/\1${SLAPD_PPOLICY_DN_PREFIX}$dc_string/g" $module_file
             fi

             slapadd -n0 -F /etc/ldap/slapd.d -l "$module_file"
        done
    fi
else
    slapd_configs_in_env=`env | grep 'SLAPD_'`
    echo "Also in this else statement for some reason"
    if [ -n "${slapd_configs_in_env:+x}" ]; then
        echo "Info: Container already configured, therefore ignoring SLAPD_xxx environment variables and preseed files"
    fi
fi


##### NEED TO MAKE THIS A BIT BETTER....####
# INITIAL_ADMIN_PASSWORD=$(echo $INITIAL_ADMIN_PASSWORD | base64)
# GERRIT_PASSWORD=$(echo $GERRIT_PASSWORD | base64)
# JENKINS_PASSWORD=$(echo $JENKINS_PASSWORD | base64)
if [[ "$first_run" == "true" ]]; then
    if [[ -d "/etc/ldap/prepopulate" ]]; then 
        for file in `ls /etc/ldap/prepopulate/*.ldif`; do
            echo "Running file - $file"
            # envsubst '${INITIAL_ADMIN_USER} ${INITIAL_ADMIN_PASSWORD} ${SLAPD_FULL_DOMAIN} ${JENKINS_PASSWORD} ${GERRIT_PASSWORD} ${SLAPD_DOMAIN}' < $file > $file
            sed -i 's/${INITIAL_ADMIN_USER}/'"$INITIAL_ADMIN_USER"'/' $file
            sed -i 's/${INITIAL_ADMIN_PASSWORD}/'"$INITIAL_ADMIN_PASSWORD"'/' $file
            sed -i 's/${SLAPD_FULL_DOMAIN}/'"$SLAPD_FULL_DOMAIN"'/' $file
            sed -i 's/${JENKINS_PASSWORD}/'"$JENKINS_PASSWORD"'/' $file
            sed -i 's/${GERRIT_PASSWORD}/'"$GERRIT_PASSWORD"'/' $file
            sed -i 's/${SLAPD_DOMAIN}/'"$SLAPD_DOMAIN"'/' $file
            slapadd -F /etc/ldap/slapd.d -l "$file"
        done
    fi
fi

chown -R openldap:openldap /etc/ldap/slapd.d/ /var/lib/ldap/ /var/run/slapd/

exec "$@"