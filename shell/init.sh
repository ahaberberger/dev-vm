#!/bin/bash
_PACKAGES="openldap-servers openldap-clients lsof"
_SERVICES="slapd httpd"
_SELINUX_CONFIG="/etc/selinux/config"

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
    if [ $? -eq 0 ]; then
        service $i stop || exit $?
    fi
done

grep 'SELINUX=disabled' $_SELINUX_CONFIG >/dev/null 2>&1
if [ $? -ne 0 ]; then
   echo "Disabling SELinux..."
   cp $_SELINUX_CONFIG ${_SELINUX_CONFIG}.old || exit $?
   sed -i 's/SELINUX=\([e,p].*\)/SELINUX=disabled/g' $_SELINUX_CONFIG || exit $?
   echo "SELinux disabled. In order for the changes to take effect, the computer MUST be restarted."
fi

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

_LIBXL_SO="/usr/lib64/libxl.so"
if [ ! -f $_LIBXL_SO ]; then
    echo "Installing libxl..."
    wget -q -O $_LIBXL_SO http://lxwb.wb.mayflower.de/~stefan.krenz/php_excel/oel6.5-x86_64/libxl.so || exit $?
    chmod +x $_LIBXL_SO
fi

_PHP_EXCEL_INI="/etc/php.d/excel.ini"
_PHP_EXCEL_SO="/usr/lib64/php/modules/excel.so"
if [ ! -f $_PHP_EXCEL_SO ]; then
    echo "Installing PHP_Excel extension"
    wget -q -O $_PHP_EXCEL_SO http://lxwb.wb.mayflower.de/~stefan.krenz/php_excel/oel6.5-x86_64/excel.so || exit $?
    chmod +x $_PHP_EXCEL_SO
    echo "extension=$_PHP_EXCEL_SO" > $_PHP_EXCEL_INI
fi

echo "Activating and starting services..."
for i in $_SERVICES; do
    chkconfig $i on || exit $?
    service $i start 2>/dev/null || exit $?
done

