#!/bin/bash
_PACKAGES="openldap-servers openldap-clients lsof"
_SERVICES="slapd httpd"

echo "Fetching list of installed packages..."
_INSTALLED_PACKAGES=`yum list installed`

echo "Installing missing packages..."
for i in $_PACKAGES; do
    echo $_INSTALLED_PACKAGES|grep "$i" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo " - $i"
        yum install -y -q $i 2>/dev/null || exit $?
    fi
done

echo "Stopping services..."
for i in $_SERVICES; do
    service $i status >/dev/null 2>&1
    if [ $? -eq 0 ]; theni
        service $i stop || exit $?
    fi
done

echo "Stopping firewall and allowing everyone..."
iptables -F || exit $?
iptables -X || exit $?
iptables -t nat -F || exit $?
iptables -t nat -X || exit $?
iptables -t mangle -F || exit $?
iptables -t mangle -X || exit $?
iptables -P INPUT ACCEPT || exit $?
iptables -P FORWARD ACCEPT || exit $?
iptables -P OUTPUT ACCEPT || exit $?

echo "Removing LDAP configuration..."
rm -rf /etc/openldap/slapd.d/ || exit $?

if [ -d /vagrant/files/etc/openldap/slapd.d/ ]; then
    echo "Copying LDAP configuration..."
    cp -r /vagrant/files/etc/openldap/slapd.d/ /etc/openldap/ || exit $?
fi
if [ -f /vagrant/files/etc/openldap/slapd.d.tgz ]; then
    echo "Extracting LDAP configuration..."
    cd /etc/openldap/
    tar xf /vagrant/files/etc/openldap/slapd.d.tgz || exit $?
fi

echo "Setting owner for LDAP config directory..."
chown -R ldap:ldap /etc/openldap/slapd.d/ || exit $?

echo "Removing LDAP data..."
rm -rf /var/lib/ldap/* || exit $?

echo "Activating and starting services..."
for i in $_SERVICES; do
    chkconfig $i on || exit $?
    service $i start 2>/dev/null || exit $?
done

