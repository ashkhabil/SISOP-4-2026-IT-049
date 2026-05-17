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

    ########################################
    # FILTER FULL_AUDIT ONLY
    ########################################

    if ! echo "$line" | grep -q "|"; then
        continue
    fi

    USER=$(echo "$line" | cut -d'|' -f1)
    SHARE=$(echo "$line" | cut -d'|' -f2)

    ########################################
    # VALIDASI USER
    ########################################

    if [[ "$USER" != "member" &&
          "$USER" != "contributor" &&
          "$USER" != "librarian" ]]; then
        continue
    fi

    TIMESTAMP=$(date "+[%Y-%m-%d  %H:%M:%S]")

    ########################################
    # CONNECT
    ########################################

    if echo "$line" | grep -qi "connect"; then
        LEVEL="INFO"
        ACTION="CONNECT"
        TARGET="$SHARE"

    ########################################
    # DISCONNECT
    ########################################

    elif echo "$line" | grep -qi "disconnect"; then
        LEVEL="INFO"
        ACTION="DISCONNECT"
        TARGET="$SHARE"

    ########################################
    # WRITE
    ########################################

    elif echo "$line" | grep -qi "write"; then
        LEVEL="INFO"
        ACTION="WRITE"

        FILE=$(echo "$line" | awk -F'|' '{print $NF}')

        if [ -z "$FILE" ]; then
            TARGET="$SHARE"
        else
            TARGET="$FILE"
        fi

    ########################################
    # DENIED
    ########################################

    elif echo "$line" | grep -qi "denied"; then
        LEVEL="WARNING"
        ACTION="DENIED"
        TARGET="$SHARE"

    else
        continue
    fi

    echo "$TIMESTAMP  [$LEVEL]  [$USER]  [$ACTION]  [$TARGET]" >> /libraryit.log

done
) &

########################################
# START SAMBA
########################################

smbd --foreground --no-process-group
