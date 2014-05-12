#!/bin/bash
_PACKAGES="openldap-servers openldap-clients"
_SERVICES="slapd"

yum install -y -q $_PACKAGES 2>/dev/null
for i in $_SERVICES; do
    service $i start 2>/dev/null
done

