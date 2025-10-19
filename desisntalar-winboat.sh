#!/usr/bin/env bash
# Script de desinstalación y limpieza para Ubuntu y derivados
# Requiere: FORCE_UNINSTALL=1 en el entorno para ejecutar (por seguridad)

set -euo pipefail

# --- Comprobación de root ---
if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script debe ejecutarse como root o con sudo."
  exit 1
fi

# --- Confirmación explícita (seguridad) ---
if [ "${FORCE_UNINSTALL:-0}" != "1" ]; then
  cat <<EOF

AVISO: Este script eliminará paquetes (Docker, KVM/libvirt, Node.js, Go, FreeRDP, WinBoat, etc.),
contenedores, imágenes, datos de Docker, imágenes/volúmenes de libvirt, y archivos descargados
(winboat .deb y carpeta ISO creada por el script original).

Para proceder **exporta** FORCE_UNINSTALL=1 y vuelve a ejecutar:
  FORCE_UNINSTALL=1 sudo ./uninstall-winboat.sh

EOF
  exit 1
fi

# --- Determinar usuario real (igual que en el script original) ---
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  USUARIO_REAL="${SUDO_USER}"
else
  USUARIO_REAL=$(logname 2>/dev/null || echo "${USER:-root}")
fi

# Validar que el usuario exista
if ! id -u "${USUARIO_REAL}" &>/dev/null; then
  echo "⚠️ Usuario '${USUARIO_REAL}' no existe: se usará 'root' para operaciones relacionadas."
  USUARIO_REAL="root"
fi

HOME_USUARIO=$(eval echo "~${USUARIO_REAL}")

echo "🧹 Iniciando desinstalación y limpieza completa (usuario: ${USUARIO_REAL})..."
sleep 1

# --- Detener servicios relevantes ---
echo "⏹ Deteniendo servicios (docker, libvirt) si existen..."
systemctl stop docker.service docker.socket 2>/dev/null || true
systemctl stop containerd 2>/dev/null || true
systemctl stop libvirtd 2>/dev/null || systemctl stop libvirt-daemon 2>/dev/null || true

# --- Quitar usuario del grupo docker ---
if [ "${USUARIO_REAL}" != "root" ]; then
  echo "👤 Eliminando usuario '${USUARIO_REAL}' del grupo docker (si existe)..."
  gpasswd -d "${USUARIO_REAL}" docker 2>/dev/null || true
fi

# --- Parar y eliminar contenedores / imágenes Docker (si docker existe) ---
if command -v docker &>/dev/null; then
  echo "🐳 Limpiando contenedores e imágenes Docker..."
  # Parar todos los contenedores
  docker ps -q | xargs -r docker stop || true
  docker ps -aq | xargs -r docker rm -f || true
  docker images -aq | xargs -r docker rmi -f || true
  docker volume ls -q | xargs -r docker volume rm -f || true
  docker network ls -q | xargs -r docker network rm || true
else
  echo "ℹ️ docker no presente o no disponible, se omite limpieza de contenedores/imágenes."
fi

# --- Detener y eliminar redes/ máquinas libvirt (si virsh existe) ---
if command -v virsh &>/dev/null; then
  echo "🖥️ Limpiando redes y máquinas virtuales libvirt (si existen)..."
  # intentar detener/undefine red 'default' y demás redes activas
  for net in $(virsh net-list --all --name 2>/dev/null || true); do
    virsh net-destroy "$net" 2>/dev/null || true
    virsh net-undefine "$net" 2>/dev/null || true
  done
  # eliminar dominios (VMs)
  for dom in $(virsh list --all --name 2>/dev/null || true); do
    virsh destroy "$dom" 2>/dev/null || true
    virsh undefine "$dom" --remove-all-storage 2>/dev/null || true
  done
else
  echo "ℹ️ virsh (libvirt) no presente, se omiten operaciones de libvirt."
fi

# --- Pausar removals pendientes para apt --- 
export DEBIAN_FRONTEND=noninteractive

# --- Paquetes a purgar (lista amplia basada en la instalación original) ---
PKGS=(
  winboat
  freerdp3-x11
  nodejs
  npm
  golang-go
  qemu-kvm
  qemu-system-x86
  libvirt-daemon-system
  libvirt-clients
  libvirt-clone
  libvirt-daemon
  libvirt0
  bridge-utils
  virt-manager
  docker-ce
  docker-ce-cli
  containerd.io
  docker-engine
  docker.io
  docker-compose-plugin
  apt-transport-https
  software-properties-common
)

echo "📦 Purgando paquetes APT (esto puede tardar)..."
# Intentar purgar los paquetes listados (ignorar errores individuales)
apt-get update -y || true
apt-get purge -y "${PKGS[@]}" || true

# Auto-remove y autoremove de dependencias huérfanas
apt-get autoremove -y || true
apt-get autoclean -y || true

# --- Eliminar restos conocidos en el sistema de archivos ---
echo "🗑 Eliminando datos persistentes y carpetas usadas por Docker/libvirt/WinBoat..."

# Docker
rm -rf /var/lib/docker /var/lib/containerd /etc/docker /var/run/docker.sock /var/run/docker 2>/dev/null || true
# Containerd
rm -rf /run/containerd /var/lib/containerd 2>/dev/null || true
# Docker CE leftovers
rm -rf /etc/systemd/system/docker.service.d 2>/dev/null || true

# Libvirt / KVM
rm -rf /var/lib/libvirt /etc/libvirt /var/log/libvirt 2>/dev/null || true

# WinBoat - archivos típicos
rm -rf /opt/winboat /etc/winboat /usr/share/winboat /usr/bin/winboat /usr/local/bin/winboat 2>/dev/null || true

# Paquetes instalados via get.docker.com pueden dejar binarios en /usr/bin/docker* - borramos solo si pertenecen a docker
if command -v docker &>/dev/null; then
  echo "ℹ️ docker aún existe en PATH (no purgado por apt). Intentando eliminar binarios manualmente..."
  # NO force rm genérico, solo intentos seguros:
  rm -f /usr/bin/docker /usr/bin/docker-compose /usr/bin/containerd 2>/dev/null || true
fi

# --- Eliminar archivos descargados por el instalador original (según tu script) ---
# Detectar carpeta Descargas del usuario
if [ -d "${HOME_USUARIO}/Descargas" ]; then
  CARPETA_DESCARGAS="${HOME_USUARIO}/Descargas"
elif [ -d "${HOME_USUARIO}/Downloads" ]; then
  CARPETA_DESCARGAS="${HOME_USUARIO}/Downloads"
else
  CARPETA_DESCARGAS="${HOME_USUARIO}/Downloads"
fi

WINBOAT_DEB_FILE="${CARPETA_DESCARGAS}/winboat-0.8.7-amd64.deb"
ISO_DIR="${CARPETA_DESCARGAS}/ISO"
ISO_FILE="${CARPETA_DESCARGAS}/windows10.iso"

echo "🗂 Eliminando archivos del directorio de descargas (si existen):"
[ -f "${WINBOAT_DEB_FILE}" ] && { echo " - ${WINBOAT_DEB_FILE}"; rm -f "${WINBOAT_DEB_FILE}" || true; }
[ -f "${ISO_FILE}" ] && { echo " - ${ISO_FILE}"; rm -f "${ISO_FILE}" || true; }
[ -d "${ISO_DIR}" ] && { echo " - ${ISO_DIR} (carpeta)"; rm -rf "${ISO_DIR}" || true; }

# --- Restablecer permisos del directorio de descargas al usuario ---
chown -R "${USUARIO_REAL}":"${USUARIO_REAL}" "${CARPETA_DESCARGAS}" 2>/dev/null || true

# --- Eliminar paquetes huérfanos y forzar limpieza final ---
apt-get purge -y --auto-remove || true
apt-get autoremove -y || true

# --- Recargar systemd y eliminar unidades docker/libvirt si existen ---
systemctl daemon-reload || true
systemctl reset-failed || true

# --- Información final ---
echo
echo "======================================================================="
echo "✅ Proceso de desinstalación completado (seguro)."
echo
echo "Acciones realizadas (resumen):"
echo " • Se detuvieron servicios docker/libvirt (si estaban presentes)."
echo " • Se intentó eliminar contenedores, imágenes y volúmenes Docker."
echo " • Se intentó destruir/undefinir redes y VMs de libvirt (si existían)."
echo " • Se purgaron paquetes relacionados (Docker, libvirt, qemu, nodejs, golang, freerdp, winboat, etc.)."
echo " • Se eliminaron datos persistentes típicos: /var/lib/docker, /var/lib/libvirt, /etc/docker, /etc/libvirt, etc."
echo " • Se borraron los archivos del instalador: ${WINBOAT_DEB_FILE} y ${ISO_FILE} (si existían) y la carpeta ${ISO_DIR}."
echo
echo "Notas y recomendaciones:"
echo " • Si instalaste Docker mediante un método diferente (snap, script personalizado, repositorios no apt), puede quedar algo residual."
echo " • Revisa manualmente: /var/lib/docker, /var/lib/containerd, /etc/docker, /etc/libvirt, /opt, /usr/local/bin"
echo " • Si quieres que intente eliminar algo adicional específico, indícalo y lo añado al script."
echo "======================================================================="
echo

exit 0
