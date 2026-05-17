FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    samba \
    samba-common-bin \
    rsyslog \
    && apt clean

RUN mkdir -p /libraryit/ebooks \
    /libraryit/papers \
    /libraryit/docs \
    /libraryit/sourcecode \
    /var/log/samba

COPY smb.conf /etc/samba/smb.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 445

CMD ["/entrypoint.sh"]
