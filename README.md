# SISOP-4-2026-IT-049

## Reporting

Ashkhabil Abror Budihardjo (5027251049)

### Soal 1

penjelasan

Pada soal ini diminta untuk membuat filesystem virtual menggunakan FUSE (Filesystem in Userspace) dengan bahasa C. Filesystem yang dibuat bertindak sebagai filesystem mirror atau passthrough terhadap folder `amba_files/`.

Selain melakukan passthrough terhadap file asli, filesystem juga harus memiliki sebuah file virtual bernama `tujuan.txt`. File virtual ini tidak benar-benar ada pada source directory, tetapi hanya muncul pada mount directory dan isinya dibangkitkan secara on-the-fly.

Isi dari `tujuan.txt` berasal dari gabungan fragmen koordinat yang terdapat pada file `1.txt` sampai `7.txt`.

Struktur Direktori

Sebelum program dijalankan:

```bash
.
├── amba_files/
│   ├── 1.txt
│   ├── 2.txt
│   ├── 3.txt
│   ├── 4.txt
│   ├── 5.txt
│   ├── 6.txt
│   └── 7.txt
├── kenz_rescue.c
└── mnt/
```

Langkah Pengerjaan

Menghapus file zip setelah extract

Arsip `amba_files.zip` diekstrak terlebih dahulu kemudian file zip dihapus agar sesuai dengan requirement soal.

```bash
unzip amba_files.zip
rm amba_files.zip
```

`unzip amba_files.zip` digunakan untuk mengekstrak isi file zip.
`rm amba_files.zip` digunakan untuk menghapus file zip setelah proses extract selesai.

Implementasi Program FUSE

Program dibuat menggunakan FUSE versi 28.

Library dan Konfigurasi Awal

```c
#define FUSE_USE_VERSION 28
#define _FILE_OFFSET_BITS 64
#define _DEFAULT_SOURCE

#include <fuse.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <stdlib.h>
```

`FUSE_USE_VERSION 28` digunakan untuk menentukan versi FUSE yang dipakai.
`_FILE_OFFSET_BITS 64` digunakan agar filesystem mendukung file berukuran besar.
Header seperti `fuse.h`, `dirent.h`, `fcntl.h`, dan `sys/stat.h` digunakan untuk operasi filesystem.

Variabel Global

```c
static const char *dirpath = "/home/adduser/sisop/praktikum/amba_files";
static const char *virtual_file = "/tujuan.txt";
```

`dirpath` merupakan source directory asli yang berisi file `1.txt` sampai `7.txt`.
`virtual_file` digunakan untuk mendefinisikan file virtual yang hanya muncul pada mount directory.

Fungsi generate_tujuan()

Fungsi ini digunakan untuk membangkitkan isi file virtual `tujuan.txt`.

```c
static char *generate_tujuan() {
    static char result[4096];
    result[0] = '\0';

    strcat(result, "Tujuan Mas Amba: ");

    for (int i = 1; i <= 7; i++) {
        char filepath[256];
        snprintf(filepath, sizeof(filepath), "%s/%d.txt", dirpath, i);

        FILE *fp = fopen(filepath, "r");
        if (!fp) continue;

        char line[1024];
        while (fgets(line, sizeof(line), fp)) {
            char *start = strstr(line, "KOORD: ");
            if (start) {
                start += strlen("KOORD: ");

                char *newline = strchr(start, '\n');
                if (newline) *newline = '\0';

                strcat(result, start);
                break;
            }
        }

        fclose(fp);
    }

    strcat(result, "\n");
    return result;
}
```

Fungsi ini bekerja dengan cara:

1. Membuat string awal:

```txt
Tujuan Mas Amba:
```

2. Melakukan loop dari file `1.txt` sampai `7.txt`.

3. Membaca setiap file dan mencari string:

```txt
KOORD:
```

4. Mengambil fragmen koordinat setelah `KOORD:`.

5. Menggabungkan seluruh fragmen menjadi satu string.

6. Mengembalikan hasil akhir sebagai isi dari `tujuan.txt`.

Contoh output:

```txt
Tujuan Mas Amba: -7.957382728443728,112.4698688227961,23:59 WIB
```

Callback getattr

Fungsi `getattr` digunakan untuk mendapatkan metadata file.

```c
static int xmp_getattr(const char *path, struct stat *stbuf) {
    int res;
    char fpath[1000];

    memset(stbuf, 0, sizeof(struct stat));

    if (strcmp(path, virtual_file) == 0) {
        char *content = generate_tujuan();

        stbuf->st_mode = S_IFREG | 0444;
        stbuf->st_nlink = 1;
        stbuf->st_size = strlen(content);
        return 0;
    }

    snprintf(fpath, sizeof(fpath), "%s%s", dirpath, path);

    res = lstat(fpath, stbuf);
    if (res == -1) return -errno;

    return 0;
}
```

Fungsi ini memiliki dua tugas:

1. Jika file yang diakses adalah `tujuan.txt`, maka metadata dibuat secara virtual.
2. Jika bukan file virtual, maka metadata diteruskan langsung ke file asli pada source directory.

Bagian:

```c
stbuf->st_mode = S_IFREG | 0444;
```

menunjukkan bahwa `tujuan.txt` merupakan regular file dengan permission read-only.

Callback readdir

Fungsi `readdir` digunakan untuk membaca isi directory.

```c
static int xmp_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                       off_t offset, struct fuse_file_info *fi) {
    char fpath[1000];

    if (strcmp(path, "/") == 0)
        snprintf(fpath, sizeof(fpath), "%s", dirpath);
    else
        snprintf(fpath, sizeof(fpath), "%s%s", dirpath, path);

    DIR *dp;
    struct dirent *de;

    (void) offset;
    (void) fi;

    dp = opendir(fpath);
    if (dp == NULL) return -errno;

    while ((de = readdir(dp)) != NULL) {
        struct stat st;
        memset(&st, 0, sizeof(st));

        st.st_ino = de->d_ino;
        st.st_mode = de->d_type << 12;

        if (filler(buf, de->d_name, &st, 0))
            break;
    }

    filler(buf, "tujuan.txt", NULL, 0);

    closedir(dp);
    return 0;
}
```

Fungsi ini digunakan untuk:

1. Membaca isi folder asli `amba_files`.
2. Menampilkan seluruh file asli.
3. Menambahkan file virtual `tujuan.txt`.

Bagian:

```c
filler(buf, "tujuan.txt", NULL, 0);
```

berfungsi untuk memunculkan file virtual pada mount directory.

Sehingga hasil `ls mnt/` menjadi:

```bash
1.txt 2.txt 3.txt 4.txt 5.txt 6.txt 7.txt tujuan.txt
```

Callback open

Fungsi `open` digunakan saat file dibuka.

```c
static int xmp_open(const char *path, struct fuse_file_info *fi) {
    char fpath[1000];
    int res;

    if (strcmp(path, virtual_file) == 0)
        return 0;

    snprintf(fpath, sizeof(fpath), "%s%s", dirpath, path);

    res = open(fpath, fi->flags);
    if (res == -1) return -errno;

    close(res);
    return 0;
}
```

Jika file yang dibuka adalah `tujuan.txt`, maka fungsi langsung mengembalikan nilai sukses.
Jika bukan, maka operasi diteruskan ke file asli.
Filesystem ini hanya bersifat read-only sehingga tidak ada operasi write.

Callback read

Fungsi `read` digunakan untuk membaca isi file.

```c
static int xmp_read(const char *path, char *buf, size_t size,
                    off_t offset, struct fuse_file_info *fi) {

    if (strcmp(path, virtual_file) == 0) {
        char *content = generate_tujuan();
        size_t len = strlen(content);

        if (offset < len) {
            if (offset + size > len)
                size = len - offset;

            memcpy(buf, content + offset, size);
        } else {
            size = 0;
        }

        return size;
    }

    char fpath[1000];
    snprintf(fpath, sizeof(fpath), "%s%s", dirpath, path);

    int fd;
    int res;

    (void) fi;

    fd = open(fpath, O_RDONLY);
    if (fd == -1) return -errno;

    res = pread(fd, buf, size, offset);
    if (res == -1) res = -errno;

    close(fd);
    return res;
}
```

Fungsi ini memiliki dua kondisi:

1. Membaca file virtual

Jika file yang dibaca adalah `tujuan.txt`, maka isi file dibuat secara dinamis menggunakan `generate_tujuan()`.
Data disalin ke buffer menggunakan `memcpy()`.

2. Membaca file asli

Jika file bukan virtual, file dibuka menggunakan `open()`.
Isi file dibaca menggunakan `pread()`.
Hasilnya diteruskan ke user.

Karena itu filesystem bekerja seperti mirror filesystem.

Struktur fuse_operations

```c
static struct fuse_operations xmp_oper = {
    .getattr = xmp_getattr,
    .readdir = xmp_readdir,
    .open    = xmp_open,
    .read    = xmp_read,
};
```

Struktur ini digunakan untuk mendaftarkan callback FUSE yang akan digunakan.
`getattr` mengambil metadata file.
`readdir` membaca isi directory.
`open` membuka file.
`read` membaca isi file.

Fungsi Main

```c
int main(int argc, char *argv[]) {
    umask(0);
    return fuse_main(argc, argv, &xmp_oper, NULL);
}
```

Fungsi `main` digunakan untuk menjalankan filesystem FUSE.

Bagian:

```c
fuse_main(argc, argv, &xmp_oper, NULL);
```

akan:

1. Melakukan mount filesystem.
2. Menjalankan callback FUSE.
3. Menjaga filesystem tetap aktif sampai di-unmount.

### Output

Berikut adalah outputnya.

<img width="730" height="47" alt="Screenshot 2026-05-17 224619" src="https://github.com/user-attachments/assets/ad8dfd9a-843e-4280-80d3-ec4b17fe6455" />
<img width="623" height="43" alt="Screenshot 2026-05-17 224632" src="https://github.com/user-attachments/assets/367735b2-710b-465e-b733-cb6cf92250d7" />
<img width="879" height="209" alt="Screenshot 2026-05-17 224715" src="https://github.com/user-attachments/assets/da5777b9-08f3-422b-baa8-26a46af71d6c" />
<img width="789" height="121" alt="Screenshot 2026-05-17 224850" src="https://github.com/user-attachments/assets/cf89b0b1-4cee-4ead-9a46-a06d04ce0ffe" />
<img width="725" height="118" alt="Screenshot 2026-05-17 224935" src="https://github.com/user-attachments/assets/e03a9377-b41a-4fc6-97e3-5fce38a985c8" />

### Kendala

Tidak ada kendala.

### Soal 3

penjelasan

Pada soal ini dibuat sebuah sistem server Samba berbasis Docker bernama `libraryit-server`.
Server berjalan secara otomatis menggunakan `docker compose up` tanpa setup manual tambahan. Sistem memiliki:

* user dan group otomatis
* konfigurasi share Samba
* permission berbeda pada setiap koleksi
* bind mount agar data permanen
* logging realtime menggunakan service terpisah

---

Struktur Repository

```text
soal_3/
├── docker-compose.yml
├── Dockerfile
├── smb.conf
├── entrypoint.sh
├── logs/
│   └── libraryit.log
└── data/
    ├── ebooks/
    ├── papers/
    ├── docs/
    └── sourcecode/
```

Dockerfile

File `Dockerfile` digunakan untuk membuat image server Samba berbasis Ubuntu.

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    samba \
    samba-common-bin \
    && apt clean

RUN mkdir -p \
    /libraryit/ebooks \
    /libraryit/papers \
    /libraryit/docs \
    /libraryit/sourcecode

COPY smb.conf /etc/samba/smb.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 445

CMD ["/entrypoint.sh"]
```

Penjelasan:

* Menggunakan image Ubuntu 22.04
* Menginstall Samba dan utilitasnya
* Membuat direktori koleksi
* Menyalin konfigurasi Samba
* Menjalankan `entrypoint.sh` saat container aktif

docker-compose.yml

File `docker-compose.yml` digunakan untuk menjalankan service utama dan logger.

```yaml
version: '3'

services:

  libraryit-server:
    build: .
    container_name: libraryit-server

    ports:
      - "1445:445"

    volumes:
      - ./data/ebooks:/libraryit/ebooks
      - ./data/papers:/libraryit/papers
      - ./data/docs:/libraryit/docs
      - ./data/sourcecode:/libraryit/sourcecode
      - ./logs/libraryit.log:/libraryit.log

    restart: always

  libraryit-logger:
    image: alpine
    container_name: libraryit-logger

    depends_on:
      - libraryit-server

    volumes:
      - ./logs/libraryit.log:/libraryit.log

    command: sh -c "tail -F /libraryit.log"
```

Penjelasan:

* `libraryit-server` menjalankan Samba server
* `libraryit-logger` memonitor log secara realtime
* data menggunakan bind mount agar permanen
* logger membaca file `libraryit.log`

Konfigurasi Samba

Konfigurasi Samba terdapat pada file `smb.conf`.

```ini
[global]

logging = file
log file = /tmp/samba.log

log level = 1
max log size = 0

vfs objects = full_audit

full_audit:prefix = %u|%S
full_audit:success = connect disconnect mkdir rmdir read write rename unlink
full_audit:failure = all

full_audit:facility = LOCAL7
full_audit:priority = NOTICE

#################################################

[ebooks]
path = /libraryit/ebooks

valid users = @readonly,@staff
write list = @staff

read only = yes
browseable = yes

force user = root
force group = staff

create mask = 0664
directory mask = 0775

#################################################

[papers]
path = /libraryit/papers

valid users = @readonly,@staff
write list = @staff

read only = yes
browseable = yes

force user = root
force group = staff

create mask = 0664
directory mask = 0775

#################################################

[sourcecode]
path = /libraryit/sourcecode

valid users = @staff
write list = contributor,librarian

read only = no
browseable = no

force user = root
force group = staff

create mask = 0660
directory mask = 0770

#################################################

[docs]
path = /libraryit/docs

valid users = @readonly,@staff
write list = librarian

read only = yes
browseable = yes

force user = root
force group = staff

create mask = 0664
directory mask = 0775
```

Penjelasan:

* `ebooks` dan `papers` dapat ditulis oleh group `staff`
* `sourcecode` hanya dapat diakses group `staff`
* `docs` hanya dapat ditulis oleh user `librarian`
* `browseable = no` membuat `sourcecode` tidak terlihat oleh member
* `force user = root` digunakan agar bind mount Linux tidak menolak akses Samba

---

entrypoint.sh

File `entrypoint.sh` digunakan untuk:

* membuat user dan group otomatis
* membuat password Samba
* membuat formatter log realtime
* menjalankan Samba

```bash
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
```

Penjelasan:

* Membuat group `readonly` dan `staff`
* Membuat user otomatis
* Membuat password Linux dan Samba
* Membaca log Samba realtime
* Mengubah format log sesuai requirement soal

Permission Folder Host

sourcecode

Folder `sourcecode` menggunakan permission `750`.

```bash
sudo chmod 750 data/sourcecode
```

Penjelasan:

* owner memiliki full access
* group hanya read dan execute
* selain owner/group tidak bisa mengakses

docs

Folder `docs` dibuat readonly dari host.

```bash
sudo chmod 555 data/docs
```

Penjelasan:

* host tidak dapat menulis langsung
* file hanya dapat dimodifikasi melalui Samba

### Output

Berikut adalah outputnya.

<img width="856" height="511" alt="Screenshot 2026-05-17 214411" src="https://github.com/user-attachments/assets/331a3c33-135f-49e3-9180-803111ecca12" />
<img width="626" height="31" alt="Screenshot 2026-05-17 214349" src="https://github.com/user-attachments/assets/ba2bbd91-6786-4a29-b059-c102737a7545" />
<img width="761" height="322" alt="Screenshot 2026-05-17 214335" src="https://github.com/user-attachments/assets/9e30a27f-5bbf-456b-b484-d50118b8aba1" />
<img width="960" height="290" alt="Screenshot 2026-05-17 214307" src="https://github.com/user-attachments/assets/dc3cd678-544a-4d63-9a21-e7230cdeb922" />
<img width="935" height="37" alt="Screenshot 2026-05-17 214236" src="https://github.com/user-attachments/assets/a1ca7d69-0999-46b6-9bc1-3eede810c75b" />
<img width="1431" height="223" alt="Screenshot 2026-05-17 214203" src="https://github.com/user-attachments/assets/12e95132-72f5-43d7-a09e-d8815dbe681f" />
<img width="1256" height="275" alt="Screenshot 2026-05-17 214129" src="https://github.com/user-attachments/assets/5634c271-67a1-4713-a827-24687e264a72" />

### Kendala

Tidak bisa membuat format sesuai dengan soal.
