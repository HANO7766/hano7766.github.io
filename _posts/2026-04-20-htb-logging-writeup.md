---
title: "Logging-HTB"
date: 2026-04-20 12:00:00 -0400
categories: [HTB, Writeups]
tags: [htb, windows, gmsa, wsus, dns, certipy, active-directory, dll-hijacking, troubleshooting]
---

# Logging — HackTheBox (Especial Troubleshooting)

¡Bienvenidos a este nuevo writeup! En esta ocasión voy a desglosar cómo resolver la máquina **Logging** de Hack The Box (Dificultad Media, Windows). 

Más que un simple *paso a paso*, este artículo es una guía nacida de la frustración real y orientada a resolver los bloqueos exactos que me encontré durante su explotación. Desde problemas con **desfases de Kerberos**, hasta los clásicos fallos de librerías Python en **Kali Linux** al intentar abusar de Active Directory.


## 1. Reconocimiento y Acceso Inicial

El primer paso consistió en enumerar los servicios de la máquina. El escaneo habitual de Nmap (`nmap -Pn -p- --min-rate 2000 -T4 <TARGET_IP>`) nos arrojó puertos clásicos de un DC (88, 135, 139, 389, 445, etc.), pero llamativamente los puertos **8530 y 8531** (HTTP/HTTPS para **WSUS**) estaban abiertos. Esto ya era un spoiler gigante del vector final.

Usando las credenciales iniciales dadas (`wallace.everette:Welcome2026@`), listamos los recursos de red por SMB. Había un recurso llamado `Logs` con permisos de lectura.

Al descargar todo el contenido, nos encontramos con un archivo `IdentitySync_Trace_20260219.log` que filtraba información vital:
```text
BindUser: "LOGGING\svc_recovery",
BindPass: "Em3rg3ncyPa$$2025"
```
> **Nota de resolución vital**: El log ponía `2025`, pero la política de rotación de la empresa requería cambiarlo al año en curso. La contraseña real era `Em3rg3ncyPa$$2026`.

### El problema de Kerberos y la VPN
Intenté autenticarme y me encontré con obstáculos. La cuenta `svc_recovery` pertenece al grupo **Protected Users**, por lo que NTLM está bloqueado; obligatoriamente hay que usar **Kerberos**. 
Pero cada petición me lanzaba un `invalidCredentials`. Tras mucha depuración, ¿el culpable? **Un desfase horario**. El reloj del DC (`DC01`) estaba adelantado **7 horas** con respecto a mi VPN de atacante.

Para todo lo relacionado con Kerberos debimos usar la herramienta `faketime` instalada en nuestro Kali para falsear temporalmente la hora de nuestra terminal.

## 2. Abuso de gMSA y Extracción de Hashes

Recopilando datos con BloodHound desde `svc_recovery` nos dimos cuenta de que podíamos lanzar un ataque por medio de gMSA (Group Managed Service Accounts). `svc_recovery` poseía privilegios **GenericWrite** sobre una cuenta de servicio interesantísima llamada `msa_health$`.

Teniendo `GenericWrite`, pudimos sobreescribir la propiedad `msDS-GroupMSAMembership` para agregarnos a nosotros mismos al grupo permitido para leerla.

### ¿Entornos virtuales rotos en Kali?
El script convencional (como `gMSADumper.py`) fallaba, y usar herramientas nativas en Kali Linux presentaba errores como `ModuleNotFoundError: No module named 'pkg_resources'` debido a cómo gestionan las versiones de Python los nuevos entornos virtuales.
**Solución real:**
1. Desactivar el `venv` corrompido (`deactivate`).
2. Utilizar el impacket nativo del sistema para obtener el Ticket Granting Ticket (TGT):
```bash
faketime -f "+7h" impacket-getTGT 'logging.htb/svc_recovery:Em3rg3ncyPa$$2026' -dc-ip <TARGET_IP>
export KRB5CCNAME=svc_recovery.ccache
```
3. Usar `bloodyAD` para agregarnos como miembros que pueden leer hashes.
4. Y por último extraer el hash de `msa_health$` a través del LDAP:
```bash
faketime -f "+7h" nxc ldap <IP> -u svc_recovery -d logging.htb -k --use-kcache --gmsa
```
El hash NT devuelto permitía usar `evil-winrm` y conectarnos directamente. ¡Una barrera menos!

## 3. Secuestro de DLLs y la Flag del User

Ya dentro mediante WinRM como `msa_health$`, investigamos la carpeta `C:\ProgramData\UpdateMonitor\`. Hay una bitácora en la cual una tarea programada llamada "UpdateChecker Agent" (ejecutada mediante el usuario `jaylee.clifton`) descomprime un `Settings_Update.zip` y carga una `settings_update.dll`. 

Todo un clásico **DLL Hijacking** vía tarea programada. Ya que controlábamos la entrada (el `.zip`), pudimos colar código C en una DLL falsa diseñada bajo nuestras condiciones.

### Baches en la inyección de la DLL
Tuvimos dos grandes dolores de cabeza con esta subida:
1. **Error `cc1plus` en Kali:** Al tratar de usar un comando como `i686-w64-mingw32-gcc`, Kali fallaba. La razón era la sintaxis (usar el compilador `g++` en vez de `gcc`). 
2. **Congelamiento de subprocesos:** La DLL era subida y cargada por el sistema. Si usábamos comandos interactivos sin forzar silencio, la tarea se quedaba *colgada* intentando enviar algo por consola (`Access Denied` si queríamos sobreescribirla). Tuvimos que empaquetar de ser necesario usando redirects a `/dev/null` (`< NUL` en Windows).

Aprovechamos que la tarea se ejecutaba como la usuaria para robar la flag al crear este código:
```cpp
system("cmd /c type C:\\Users\\jaylee.clifton\\Desktop\\user.txt > C:\\Share\\Logs\\user.txt");
```
¡Boom! Primera bandera `user.txt` nuestra.

## 4. Obtención de Certificado (ADCS)

Una vez en control del agente de Update, lo re-explotamos para contactar los Servicios de Certificados (AD CS). Evaluando con `Certipy` observamos una plantilla peculiar: `UpdateSrv`. Para aprovecharlo:
1. Nos generamos un CSR local para el nombre de dominio `wsus.logging.htb`.
2. Usamos nuestra DLL maliciosa de nuevo pero con este payload: `certreq -f -submit -attrib "CertificateTemplate:UpdateSrv"...` 
3. Descargamos el `cert.cer` resultante al Kali para firmar nuestro *Web Server* HTTP/HTTPS falso.

No es que este certificado sirviera para PKINIT directamente, pero sí valía para montar el servidor oficial de engaño del sistema.

## 5. El Engaño del Servidor WSUS Malicioso (Root Flag)

A partir de acá comienza el juego del **Hombre en el Medio (MITM)** para DNS. El plan: Levantar un servidor falso WSUS.

Como contábamos con `SeMachineAccountPrivilege`, engañamos los registros del AD para crear una máquina llamada `attacker01$`.

Posterior asalto al DNS: Empleando un script de Python, obligamos a envenenar el registro `A` de `wsus.logging.htb` para que apuntara a mi **IP de VPN de Kali**.

### Enfrentando los bloqueos del DNS de AD
Al hacer todo manual por consola enfrentamos un bucle tremendo donde me arrojaba `entryAlreadyExists` e `ipconfig /flushdns` no propagaba el cambio.
¿La bala de plata en estos casos? `bloodyAD` y usar `nslookup` forzando la máquina original a consultar su servidor local. Tuvimos que eliminar nodos "sucios" preexistentes usando este comando de purga pura:
```bash
bloodyAD --host <IP-DC> -d logging.htb -u attacker01$ -p 'SuperP@ss!' remove dnsRecord wsus.logging.htb
```
Y recrear el registro forzando la compatibilidad de IP pura.

### Escalada Final con `wsuks`
La gente normalmente tira de `pywsus`, pero resulta ser un dolor en servidores 2019 de WSUS, la solución efectiva en este OS es la herramienta [`wsuks`](https://github.com/0xMarcio/wsuks).
Nuevamente, debido a las barreras modernas de `pip` en distribuciones Kali nuevas, debemos forzar la instalación con:
```bash
pip install wsuks --break-system-packages
```

Y luego un servidor Python minimalista firmado con nuestro certificado extraído en pasos anteriores, preparado para servir a las peticiones con un binario firmado de Microsoft como `PsExec64.exe` que, al lanzarse por el sistema con privilegios SYSTEM, nos iba a agregar a al mismísimo grupo de `Administrators`.

**Forzamos al Agente Local al fallo mediante:**
```powershell
usoclient StartScan
```
Pero cuidado. Debido a bloqueos de memoria (cargas huérfanas en el DC), en situaciones tensas toca enviar un "mazo de demolición API" a través del PowerShell del DC:
```powershell
$Session = New-Object -ComObject Microsoft.Update.Session
$Searcher = $Session.CreateUpdateSearcher()
$Searcher.Search("IsInstalled=0")
```
Esto invoca directamente al servicio real en Windows y obliga al DC a descargar el Payload infectado.
En terminal pude captar el momento donde mandaban los `GET` y `POST` solicitando el archivo y minutos más tarde, el token recargo con la mágia local. Podría entrar bajo el grupo Administradores y reclamar `root.txt`.
