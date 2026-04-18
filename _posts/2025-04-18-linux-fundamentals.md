---
title: "Linux Fundamentals - Guía Completa"
date: 2025-04-18 10:00:00 -0400
categories: [Linux, Fundamentos]
tags: [linux, filesystem, networking, firewall, iptables, ssh, nfs, permissions, systemd, cron, rsync, backup, security, selinux, apparmor, docker, logs]
---

Esta publicación reúne los conceptos fundamentales de administración de sistemas Linux, desde la gestión del sistema de archivos hasta la seguridad y copias de seguridad. Una referencia rápida para pentesters y administradores de sistemas.

---

## 1. Sistema de Archivos

Administrar sistemas de archivos en Linux es una tarea crucial. Linux admite múltiples sistemas de archivos:

| Sistema | Descripción |
|---|---|
| `ext2` | Sin journaling, útil en USB de baja sobrecarga |
| `ext3` / `ext4` | Con journaling; ext4 es el estándar moderno |
| `Btrfs` | Instantáneas y verificación de integridad integrada |
| `XFS` | Alto rendimiento con archivos grandes |
| `NTFS` | Compatibilidad con sistemas Windows / dual-boot |

### Discos y particiones

La herramienta principal para gestión de discos es `fdisk`:

```bash
sudo fdisk -l
```

```
Disk /dev/vda: 160 GiB, 171798691840 bytes, 335544320 sectors
Device     Boot     Start       End   Sectors  Size Id Type
/dev/vda1  *         2048 158974027 158971980 75.8G 83 Linux
/dev/vda2       158974028 167766794   8792767  4.2G 82 Linux swap
```

### Montaje de sistemas de archivos

Montar una unidad USB:

```bash
sudo mount /dev/sdb1 /mnt/usb
cd /mnt/usb && ls -l
```

Ver los sistemas de archivos montados actualmente:

```bash
mount
```

Desmontar:

```bash
sudo umount /mnt/usb
```

Para verificar si hay procesos usando el sistema de archivos antes de desmontar:

```bash
lsof | grep cry0l1t3
```

El archivo `/etc/fstab` define los sistemas que se montan al arrancar:

```txt
UUID=3d6a020d-...-9e085e9c927a /     btrfs  subvol=@,defaults,noatime 0 1
UUID=3d6a020d-...-9e085e9c927a /home btrfs  subvol=@home,defaults     0 2
UUID=21f7eb94-...-d4f58f94e141 swap  swap   defaults,noatime           0 0
```

### SWAP

El espacio de intercambio permite al kernel mover páginas inactivas de RAM cuando la memoria se llena. Se configura con:

- `mkswap` — prepara un dispositivo como espacio de intercambio
- `swapon` — activa el espacio de intercambio

---

## 2. Configuración de Red

### Interfaces de red

Activar una interfaz:

```bash
sudo ifconfig eth0 up
# o equivalente:
sudo ip link set eth0 up
```

Asignar dirección IP y máscara de red:

```bash
sudo ifconfig eth0 192.168.1.2
sudo ifconfig eth0 netmask 255.255.255.0
sudo route add default gw 192.168.1.1 eth0
```

Editar el DNS en `/etc/resolv.conf`:

```txt
nameserver 8.8.8.8
nameserver 8.8.4.4
```

Configuración persistente en `/etc/network/interfaces`:

```txt
auto eth0
iface eth0 inet static
  address 192.168.1.2
  netmask 255.255.255.0
  gateway 192.168.1.1
  dns-nameservers 8.8.8.8 8.8.4.4
```

### Control de Acceso a la Red (NAC)

| Tipo | Descripción |
|---|---|
| `DAC` | El propietario del recurso define los permisos |
| `MAC` | Permisos aplicados por el sistema operativo |
| `RBAC` | Permisos basados en roles organizacionales |

### Solución de problemas de red

Herramientas útiles: `ping`, `traceroute`, `netstat`, `tcpdump`, `wireshark`, `nmap`

```bash
traceroute www.inlanefreight.com
```

### Hardening de red

- **SELinux** — Control de acceso obligatorio integrado en el kernel, control granular
- **AppArmor** — MAC basado en perfiles, más fácil de administrar
- **TCP Wrappers** — Control de acceso basado en dirección IP de origen

---

## 3. Firewall con iptables

`iptables` filtra tráfico de red con reglas basadas en IP, puerto y protocolo. Alternativas: `nftables`, `ufw`, `firewalld`.

### Componentes principales

| Componente | Descripción |
|---|---|
| `Tables` | Organizan y categorizan las reglas |
| `Chains` | Agrupan reglas por tipo de tráfico |
| `Rules` | Definen criterios y acciones |
| `Targets` | Acción a tomar (ACCEPT, DROP, etc.) |

### Tablas disponibles

| Tabla | Descripción | Cadenas |
|---|---|---|
| `filter` | Filtra por IP, puerto, protocolo | INPUT, OUTPUT, FORWARD |
| `nat` | Modifica IPs de origen/destino | PREROUTING, POSTROUTING |
| `mangle` | Modifica cabeceras de paquetes | PREROUTING, OUTPUT, INPUT... |

### Targets comunes

| Target | Descripción |
|---|---|
| `ACCEPT` | Permite el paquete |
| `DROP` | Descarta silenciosamente |
| `REJECT` | Descarta y notifica al origen |
| `LOG` | Registra en el log del sistema |
| `SNAT` | Cambia IP de origen (NAT) |
| `DNAT` | Cambia IP de destino |
| `MASQUERADE` | SNAT con IP dinámica |

### Ejemplo práctico: bloquear IP en puerto específico

```bash
# 1. Cadena: INPUT
# 2. Origen: -s 192.168.1.50
# 3. Protocolo: -p tcp
# 4. Puerto: --dport 8080
# 5. Acción: -j DROP

sudo iptables -A INPUT -s 192.168.1.50 -p tcp --dport 8080 -j DROP

# Bloquear toda una subred
sudo iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 8080 -j DROP

# Cadenas personalizadas
sudo iptables -A INPUT -p tcp --dport 8080 -j MIPROYECTO
sudo iptables -A MIPROYECTO -s 192.168.1.50 -j ACCEPT
sudo iptables -A MIPROYECTO -j DROP
```

---

## 4. Servicios de Red

### SSH

SSH permite la administración segura de sistemas remotos. El servidor más común es **OpenSSH**.

```bash
ssh cry0l1t3@10.129.17.122
```

Configuración en `/etc/ssh/sshd_config` (número máximo de conexiones, autenticación por clave, etc.).

### NFS (Network File System)

Permisos clave de NFS:

| Permiso | Descripción |
|---|---|
| `rw` | Lectura y escritura |
| `ro` | Solo lectura |
| `no_root_squash` | El root del cliente mantiene sus privilegios |
| `root_squash` | Root del cliente es tratado como usuario normal |
| `sync` | Escritura confirmada antes de transferir |

```bash
# Crear compartición NFS
echo '/home/user/nfs_sharing hostname(rw,sync,no_root_squash)' >> /etc/exports

# Montar compartición remota
mkdir ~/target_nfs
mount 10.129.12.17:/home/john/dev_scripts ~/target_nfs
```

### Servidor web rápido con Python

```bash
python3 -m http.server --directory /home/user/target_files
python3 -m http.server 443
```

---

## 5. Gestión de Permisos

El comando `chmod` cambia los permisos de archivos y directorios:

```bash
chmod 700 filename
```

### Buscar archivos con permisos especiales (SUID)

```bash
find / -perm 4000
find / -perm -4000
```

### Sticky Bit

El **bit pegajoso** en directorios compartidos asegura que solo el propietario del archivo, el propietario del directorio o root puedan eliminar o renombrar archivos. Ideal para directorios como `/tmp`:

```bash
chmod +t /directorio_compartido
# o con notación octal
chmod 1777 /directorio_compartido
```

---

## 6. Gestión de Servicios y Procesos

### Tipos de servicios

- **Servicios del sistema** — Iniciados durante el arranque, esenciales para el SO
- **Servicios instalados por el usuario** — Aplicaciones de servidor y procesos en segundo plano

Los demonios se identifican con la letra `d` al final: `sshd`, `systemd`, `httpd`.

### systemd

`systemd` es el sistema de inicialización estándar en distribuciones modernas. Al primer proceso del arranque se le asigna el `PID 1`.

```bash
# Ver estado de un servicio
systemctl status sshd

# Iniciar / detener / reiniciar
systemctl start sshd
systemctl stop sshd
systemctl restart sshd

# Habilitar al arranque
systemctl enable sshd
```

---

## 7. Programación de Tareas

### Systemd Timers

Para programar una tarea con systemd necesitas 3 pasos:
1. Crear el **timer** (`mytimer.timer`)
2. Crear el **servicio** (`mytimer.service`)
3. **Activar** el timer

Por convención, `mytimer.timer` busca automáticamente `mytimer.service`. Si el nombre es diferente, se especifica con `Unit=` dentro del `.timer`.

### Cron

Estructura del crontab:

| Campo | Rango | Descripción |
|---|---|---|
| Minutos | 0-59 | En qué minuto ejecutar |
| Horas | 0-23 | En qué hora ejecutar |
| Día del mes | 1-31 | En qué día del mes |
| Mes | 1-12 | En qué mes |
| Día de la semana | 0-7 | En qué día de la semana |

```bash
# Editar el crontab del usuario
crontab -e

# Ejemplo: ejecutar un script cada hora en el minuto 0
0 * * * * /path/to/script.sh
```

---

## 8. Copias de Seguridad y Restauración

### Herramientas disponibles

- **Rsync** — Sincronización eficiente (solo transfiere los cambios)
- **Duplicity** — Basado en Rsync + cifrado de copias de seguridad
- **Deja Dup** — Interfaz gráfica para Ubuntu

### Rsync: comandos esenciales

```bash
# Copia de seguridad local → servidor remoto
rsync -av /path/to/mydirectory user@backup_server:/path/to/backup/

# Con compresión, backup incremental y eliminación de archivos borrados
rsync -avz --backup --backup-dir=/path/to/backup/folder --delete \
  /path/to/mydirectory user@backup_server:/path/to/backup/

# Restaurar desde el servidor
rsync -av user@remote_host:/path/to/backup/ /path/to/mydirectory
```

### Sincronización automática con Cron

```bash
#!/bin/bash
# RSYNC_Backup.sh
rsync -avz -e ssh /path/to/mydirectory user@backup_server:/path/to/backup/
```

```bash
chmod +x RSYNC_Backup.sh
crontab -e
# Agregar la línea:
0 * * * * /path/to/RSYNC_Backup.sh
```

Configuración de autenticación por clave (sin contraseña para scripts):

```bash
ssh-keygen -t rsa -b 2048
ssh-copy-id user@backup_server
```

---

## 9. Seguridad en Linux

### Buenas prácticas

- Deshabilitar inicio de sesión SSH con contraseña (usar claves)
- No permitir login como root vía SSH
- Usar `fail2ban` para bloquear IPs tras intentos fallidos
- Auditorías regulares del sistema (kernel desactualizado, permisos, SUID innecesarios)
- Deshabilitar servicios innecesarios

### Control de acceso a servicios

`/etc/hosts.allow` — Define qué hosts pueden acceder:

```txt
# Permitir SSH desde la red local
sshd : 10.129.14.0/24

# Permitir FTP desde un host específico
ftpd : 10.129.14.10
```

`/etc/hosts.deny` — Define qué hosts son bloqueados:

```txt
# Denegar todos los servicios desde un dominio
ALL : .inlanefreight.com

# Denegar SSH desde una IP específica
sshd : 10.129.22.22
```

### SELinux vs AppArmor vs TCP Wrappers

| Mecanismo | Alcance | Complejidad |
|---|---|---|
| **SELinux** | Kernel, control granular de cada proceso/archivo | Alta |
| **AppArmor** | Perfiles por aplicación, más fácil de gestionar | Media |
| **TCP Wrappers** | Control de acceso a servicios por IP | Baja |

### Herramientas de auditoría

- `Snort` — IDS/IPS de red
- `chkrootkit` — Detección de rootkits
- `rkhunter` — Detección de rootkits y backdoors
- `Lynis` — Auditoría de seguridad del sistema

---

## 10. Logs del Sistema

Los logs son esenciales para monitorización y seguridad. Herramientas útiles:

- `syslog` / `rsyslog` — Recolección de logs del sistema
- `ss` — Estadísticas de sockets (`ss -tulnp`)
- `lsof` — Listar archivos y conexiones abiertas
- `ELK Stack` (Elasticsearch + Logstash + Kibana) — Análisis avanzado

```bash
# Ver logs en tiempo real
journalctl -f

# Logs de autenticación
cat /var/log/auth.log

# Estadísticas de puertos abiertos
ss -tulnp
```

---

> **Nota:** Esta guía está orientada a administración de sistemas y ciberseguridad (pentesting). Conocer estas herramientas a fondo permite tanto reconocer configuraciones incorrectas como asegurar sistemas Linux correctamente.
