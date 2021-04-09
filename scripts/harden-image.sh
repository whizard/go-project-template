#!/bin/sh
set -x
set -e

# Update APT packages, upgrade existing then delete cache
apt update
apt upgrade -y
rm -rf /var/cache/apt/*

# Add user to run container: appuser
useradd -d /app -s /sbin/nologo -u 1000 appuser
sed -i -r 's/^appuser:!:/appuser:x:/' /etc/shadow

chown -R appuser:users /app

# Improve strength of diffie-hellman-group-exchange-sha256 (Custom DH with SHA2).
# See https://stribika.github.io/2015/01/04/secure-secure-shell.html
#
# Columns in the moduli file are:
# Time Type Tests Tries Size Generator Modulus
#
# This file is provided by the openssh package on Fedora.
moduli=/etc/ssh/moduli
if [[ -f ${moduli} ]]; then
  cp ${moduli} ${moduli}.orig
  awk '$5 >= 2000' ${moduli}.orig > ${moduli}
  rm -f ${moduli}.orig
fi

# Remove existing crontabs, if any.
rm -fr /var/spool/cron
rm -fr /etc/crontabs
rm -fr /etc/periodic

# Remove all but a handful of admin commands.
find /sbin /usr/sbin ! -type d \
  -a ! -name setup-proxy \
  -a ! -name sshd \
  -a ! -name start.sh \
  -delete

# Remove world-writable permissions.
# This breaks apps that need to write to /tmp,
# such as ssh-agent.
find / -xdev -type d -perm +0002 -exec chmod o-w {} +
find / -xdev -type f -perm +0002 -exec chmod o-w {} +

# Remove unnecessary user accounts.
sed -i -r "/^(${SERVICE_USER}|root)/!d" /etc/group
sed -i -r "/^(${SERVICE_USER}|root)/!d" /etc/passwd
sed -i -r "/^(${SERVICE_USER}|root)/!d" /etc/shadow

# Remove interactive login shell for everybody but user.
sed -i -r '/^'${SERVICE_USER}':/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd

sysdirs="
  /bin
  /etc
  /lib
  /sbin
  /usr
"

# Remove crufty...
#   /etc/shadow-
#   /etc/passwd-
#   /etc/group-
find $sysdirs -xdev -type f -regex '.*-$' -exec rm -f {} +

# Ensure system dirs are owned by root and not writable by anybody else.
find $sysdirs -xdev -type d \
  -exec chown root:root {} \; \
  -exec chmod 0755 {} \;

# Remove all suid files.
find $sysdirs -xdev -type f -a -perm +4000 -delete

# Remove all but a handful of admin commands.
find /sbin /usr/sbin ! -type d \
-a ! -name nologin \
-delete

# Remove all but a handful of executable commands.
find /bin /usr/bin ! -type d \
-a ! -name cd \
-a ! -name ls \
-a ! -name sh \
-a ! -name bash \
-a ! -name dir \
-a ! -name rm \
-a ! -name find \
-a ! -name test \
-delete

# Remove other programs that could be dangerous.
find $sysdirs -xdev \( \
  -name hexdump -o \
  -name chgrp -o \
  -name chmod -o \
  -name chown -o \
  -name ln -o \
  -name od -o \
  -name strings -o \
  -name su \
  \) -delete


# Remove init scripts since we do not use them.
rm -fr /etc/init.d
rm -fr /lib/rc
rm -fr /etc/conf.d
rm -fr /etc/inittab
rm -fr /etc/runlevels
rm -fr /etc/rc.conf

# Remove kernel tunables since we do not need them.
rm -fr /etc/sysctl*
rm -fr /etc/modprobe.d
rm -fr /etc/modules
rm -fr /etc/mdev.conf
rm -fr /etc/acpi

# Remove root homedir since we do not need it.
rm -fr /root

# Remove fstab since we do not need it.
rm -f /etc/fstab

# Remove broken symlinks (because we removed the targets above).
find $sysdirs -xdev -type l -exec test ! -e {} \; -delete