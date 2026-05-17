#!/bin/bash

########################################
# GROUP
########################################

groupadd readonly
groupadd staff

########################################
# USER
########################################

useradd -M member
useradd -M contributor
useradd -M librarian

echo "member:member123" | chpasswd
echo "contributor:contrib456" | chpasswd
echo "librarian:lib789" | chpasswd

usermod -aG readonly member
usermod -aG staff contributor
usermod -aG staff librarian

########################################
# SAMBA PASSWORD
########################################

(
echo "member123"
echo "member123"
) | smbpasswd -a -s member

(
echo "contrib456"
echo "contrib456"
) | smbpasswd -a -s contributor

(
echo "lib789"
echo "lib789"
) | smbpasswd -a -s librarian

########################################
# LOG FILE
########################################

touch /tmp/samba.log
touch /libraryit.log

chmod 777 /tmp/samba.log
chmod 777 /libraryit.log

########################################
# FORMATTER
########################################

(
tail -F /tmp/samba.log | while read line
do
    TIMESTAMP=$(date "+[%Y-%m-%d  %H:%M:%S]")

    USER=$(echo "$line" | cut -d'|' -f1)
    SHARE=$(echo "$line" | cut -d'|' -f2)

    if echo "$line" | grep -qi "connect"; then
        LEVEL="INFO"
        ACTION="CONNECT"

    elif echo "$line" | grep -qi "write"; then
        LEVEL="INFO"
        ACTION="WRITE"

    elif echo "$line" | grep -qi "disconnect"; then
        LEVEL="INFO"
        ACTION="DISCONNECT"

    else
        LEVEL="WARNING"
        ACTION="DENIED"
    fi

    echo "$TIMESTAMP  [$LEVEL]  [$USER]  [$ACTION]  [$SHARE]" >> /libraryit.log

done
) &

########################################
# START SAMBA
########################################

smbd --foreground --no-process-group
