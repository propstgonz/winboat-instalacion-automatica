# 📘 Script de instalación automático de WinBoat para Ubuntu y derivados

Explicación del uso y funcionamiento del script
`instalar-winboat.sh`, que automatiza la instalación de **WinBoat** y
todas sus dependencias en sistemas basados en **Ubuntu**.

------------------------------------------------------------------------

## 🧩 Requisitos previos

Antes de ejecutar el script, asegúrate de cumplir con lo siguiente:

-   Sistema operativo: **Ubuntu 22.04 o superior** (también funciona en
    derivados como Linux Mint, Pop!\_OS o Zorin OS).
-   Usuario con privilegios de `sudo`.
-   Conexión a Internet estable.
-   Espacio libre recomendado: **10 GB** o más (por posibles descargas
    de ISO y contenedores Docker).
-   Tener la virtualización activada en la BIOS
-   Saber abrir la terminal

------------------------------------------------------------------------

## 🗒️ Notas

-   Es tan simple como copiar y pegar comandos en la terminal.
-   El script automatiza completamente la instalación de Winboat, que
    puede llegar a ser algo compleja para usuarios sin experiencia.
-   Está completamente en español, exceptuando el programa en sí.
-   Al ejecutar el programa, ve siguiendo los pasos, y se recomienda
    utilizar la ISO descargada con el script (Es una versión en español).

------------------------------------------------------------------------

## ⚙️ Instrucciones de uso

1.  **Descargar el script**

    ``` bash
    ## Descargar el archivo
    git clone https://github.com/propstgonz/winboat-instalacion-automatica.git

    ## Entrar al directorio
    cd winboat-instalacion-automatica

    ## Volver ejecutable el script
    chmod +x instalar-winboat.sh
    ```

2.  **Ejecutar el script con permisos de superusuario**

    ``` bash
    sudo ./instalar-winboat.sh
    ```

    ⚠️ El script **debe ejecutarse como root o con sudo**.

------------------------------------------------------------------------

## 🧠 Qué hace el script

1.  **Comprueba permisos y usuario real**\
    Determina el usuario que ejecuta la instalación y lo usará para
    asignar permisos y grupos.

2.  **Actualiza el sistema y paquetes base**\
    Ejecuta `apt update && apt upgrade` e instala utilidades esenciales
    como `curl`, `wget`, `git`, `cmake`, entre otros.

3.  **Instala virtualización (KVM/libvirt)**\
    Instala y configura `qemu-kvm`, `libvirt-daemon-system`,
    `virt-manager` y herramientas relacionadas.

4.  **Instala Node.js, npm y Go**\
    Lenguajes opcionales requeridos para compilar WinBoat si se desea.

5.  **Instala y configura Docker**

    -   Descarga e instala Docker si no está presente.\
    -   Habilita e inicia el servicio.\
    -   Agrega el usuario actual al grupo `docker`.

6.  **Verifica soporte de virtualización**\
    Analiza si la CPU soporta `KVM` mediante
    `grep vmx|svm /proc/cpuinfo`.

7.  **Descarga WinBoat y la ISO (opcional)**

    -   Descarga el paquete `.deb` de WinBoat desde GitHub.\
    -   Descarga la ISO oficial de Windows 10 si se define `ISO_URL`.

8.  **Instala FreeRDP 3.x**\
    Se instala desde los repositorios oficiales de Ubuntu.

9.  **Instala WinBoat**\
    Usa `dpkg -i` y corrige dependencias automáticamente con
    `apt install -f`.

10. **Muestra resumen final e instrucciones**\
    Indica la ubicación de la ISO, del paquete `.deb`, y recomienda
    reiniciar sesión.

------------------------------------------------------------------------

## ⚡ Variables opcionales

Puedes definir variables antes de ejecutar el script, por ejemplo:

``` bash
ISO_URL="https://ejemplo.com/windows10.iso" sudo ./instalar-winboat.sh
```

| Variable   | Descripción                                               |
|------------|-----------------------------------------------------------|
| `ISO_URL`  | URL de la ISO de Windows 10 para descarga automática.    |
| `ISO_FILE` | Ruta personalizada donde guardar la ISO.                 |

------------------------------------------------------------------------

## 📂 Estructura de archivos

| Carpeta                       | Descripción                                                      |
|-------------------------------|------------------------------------------------------------------|
| `~/Descargas` o `~/Downloads` | Carpeta de descargas detectada automáticamente.                 |
| `~/Descargas/ISO`             | Carpeta donde se guarda la ISO oficial de Windows 10.           |

------------------------------------------------------------------------

## 🔍 Verificación de instalación

-   Comprobar que Docker funciona:

    ``` bash
    docker run hello-world
    ```

-   Verificar WinBoat:

    ``` bash
    winboat --version
    ```

-   Verificar FreeRDP:

    ``` bash
    xfreerdp --version
    ```

------------------------------------------------------------------------

## 💡 Notas finales

-   Tras añadir el usuario al grupo `docker`, **debes cerrar sesión o
    ejecutar `newgrp docker`** para aplicar los permisos.

-   Si el servicio Docker no inicia correctamente, revisa los logs con:

    ``` bash
    sudo systemctl status docker
    ```

------------------------------------------------------------------------

## 🧾 Licencia

Este script y documentación están bajo licencia **MIT**, y pueden ser
modificados o redistribuidos libremente citando la fuente.

------------------------------------------------------------------------

📦 **Autor original:** TibixDev\
📦 **Link al proyecto original:** https://github.com/TibixDev/winboat
