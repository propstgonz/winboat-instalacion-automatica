#!/usr/bin/env bash
# Script para Ubuntu y derivados

set -euo pipefail

# --- Comprobación de root ---
if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script debe ejecutarse como root o con sudo."
  exit 1
fi

# --- Determinar usuario real ---
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  USUARIO_REAL="${SUDO_USER}"
else
  USUARIO_REAL=$(logname 2>/dev/null || echo "${USER:-root}")
fi

# Validar que el usuario exista
if ! id -u "${USUARIO_REAL}" &>/dev/null; then
  echo "⚠️ Usuario '${USUARIO_REAL}' no existe: se usará 'root' para operaciones de chown/usermod."
  USUARIO_REAL="root"
fi

HOME_USUARIO=$(eval echo "~${USUARIO_REAL}")

echo "🚀 Iniciando instalación completa de WinBoat y dependencias (usuario: ${USUARIO_REAL})..."
sleep 1

# --- Actualizar sistema ---
echo "📦 Actualizando repositorios y paquetes..."
apt update
apt upgrade -y

# --- Instalar utilidades base ---
echo "🔧 Instalando paquetes base necesarios..."
apt install -y --no-install-recommends \
  curl wget git ca-certificates apt-transport-https software-properties-common \
  build-essential cmake pkg-config

# --- Instalar KVM / libvirt (virtualización) ---
echo "🧠 Instalando qemu-kvm y libvirt..."
apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

# --- Instalar Node.js y Go (opcional para compilar WinBoat) ---
echo "⚙️ Instalando nodejs, npm y golang-go..."
apt install -y nodejs npm golang-go

# --- Instalar Docker si no existe ---
echo "🐳 Instalando Docker si no está presente..."
if ! command -v docker &>/dev/null; then
  echo "➡️ Docker no detectado. Instalando vía instalador oficial..."
  curl -fsSL https://get.docker.com | sh
fi

# Instalar docker-compose plugin (si está disponible)
echo "📦 Instalando docker-compose-plugin..."
apt install -y docker-compose-plugin || true

# --- Habilitar e iniciar Docker ---
echo "🟢 Habilitando e iniciando servicio Docker..."
systemctl daemon-reload
systemctl enable --now docker.service || {
  echo "⚠️ Error iniciando Docker, mostrando logs..."
  journalctl -u docker.service --no-pager -n 20 || true
}

if systemctl is-active --quiet docker; then
  echo "✅ Docker está funcionando correctamente."
else
  echo "❌ Docker no se está ejecutando. Revisa con: sudo systemctl status docker"
fi

# --- Añadir usuario al grupo docker ---
if [ "${USUARIO_REAL}" != "root" ]; then
  echo "👤 Añadiendo al usuario '${USUARIO_REAL}' al grupo docker..."
  usermod -aG docker "${USUARIO_REAL}" || {
    echo "⚠️ No se pudo añadir '${USUARIO_REAL}' al grupo docker."
  }
  echo "ℹ️ El usuario '${USUARIO_REAL}' debe cerrar sesión/reiniciar o ejecutar 'newgrp docker' para que los cambios surtan efecto."
fi

# --- Verificar KVM ---
echo "🧠 Verificando soporte de virtualización..."
if grep -Eq 'vmx|svm' /proc/cpuinfo; then
  echo "✅ Soporte KVM detectado."
else
  echo "⚠️ Advertencia: tu CPU no tiene activada la virtualización. Verifica en la BIOS/UEFI."
fi

# --- Detectar carpeta de Descargas según idioma ---
if [ -d "${HOME_USUARIO}/Descargas" ]; then
  CARPETA_DESCARGAS="${HOME_USUARIO}/Descargas"
elif [ -d "${HOME_USUARIO}/Downloads" ]; then
  CARPETA_DESCARGAS="${HOME_USUARIO}/Downloads"
else
  CARPETA_DESCARGAS="${HOME_USUARIO}/Downloads"
  mkdir -p "${CARPETA_DESCARGAS}"
  chown "${USUARIO_REAL}":"${USUARIO_REAL}" "${CARPETA_DESCARGAS}" || true
fi
echo "📂 Carpeta de descargas detectada: ${CARPETA_DESCARGAS}"

# --- URLs y archivos ---
WINBOAT_DEB_URL="https://github.com/TibixDev/winboat/releases/download/v0.8.7/winboat-0.8.7-amd64.deb"
WINBOAT_DEB_FILE="${CARPETA_DESCARGAS}/winboat-0.8.7-amd64.deb"

# ISO oficial de Microsoft (Windows 10)
ISO_URL="${ISO_URL:-}"  # opcional; deja vacío si no se descarga automáticamente
ISO_FILE="${ISO_FILE:-${CARPETA_DESCARGAS}/windows10.iso}"

ISO_DIR="${CARPETA_DESCARGAS}/ISO"
mkdir -p "${ISO_DIR}"
chown "${USUARIO_REAL}":"${USUARIO_REAL}" "${ISO_DIR}" || true

# --- Descargar WinBoat ---
echo "⬇️ Descargando WinBoat .deb a: ${WINBOAT_DEB_FILE} ..."
if ! curl -L --fail -o "${WINBOAT_DEB_FILE}" "${WINBOAT_DEB_URL}"; then
  echo "❌ Error descargando WinBoat .deb desde ${WINBOAT_DEB_URL}"
  exit 1
fi
chown "${USUARIO_REAL}":"${USUARIO_REAL}" "${WINBOAT_DEB_FILE}" || true

# --- Descargar ISO oficial de Windows 10 (si ISO_URL está definido) ---
if [ -n "${ISO_URL}" ]; then
  echo "⬇️ Descargando ISO oficial de Windows 10 a: ${ISO_FILE} ..."
  if [ ! -f "${ISO_FILE}" ]; then
    echo "⚠️ La descarga de la ISO es grande (varios GB). Esto puede tardar según tu conexión."
    if ! curl -L --fail -o "${ISO_FILE}" "${ISO_URL}"; then
      echo "❌ Error descargando la ISO desde ${ISO_URL}"
      exit 1
    fi
    chown "${USUARIO_REAL}":"${USUARIO_REAL}" "${ISO_FILE}" || true
  else
    echo "ℹ️ ISO ya existe en ${ISO_FILE}, se saltará la descarga."
  fi
else
  echo "ℹ️ No se ha definido ISO_URL; se omitirá la descarga de la ISO."
fi

# --- Instalar FreeRDP 3.x desde repositorios ---
echo "📥 Instalando FreeRDP 3.x y sus dependencias desde repositorios..."
apt install -y freerdp3-x11

# --- Verificar instalación ---
if command -v xfreerdp &>/dev/null; then
  echo "🔎 Versión xfreerdp instalada:"
  xfreerdp --version || true
else
  echo "⚠️ xfreerdp no está disponible en PATH tras la instalación."
fi

# --- Instalar WinBoat ---
echo "📥 Instalando WinBoat desde paquete .deb..."
if dpkg -i "${WINBOAT_DEB_FILE}"; then
  echo "✅ WinBoat instalado correctamente."
else
  echo "⚠️ dpkg reportó dependencias faltantes para WinBoat. Ejecutando apt -f -y para resolverlas..."
  apt install -f -y
fi

# --- Mensajes finales e instrucciones ---
echo
echo "======================================================================="
echo "✅ Proceso completado."
echo
echo "• WinBoat instalado: ${WINBOAT_DEB_FILE}"
echo "• FreeRDP instalado desde repositorios"
if [ -n "${ISO_URL}" ]; then
  echo "• ISO oficial de Windows 10 en castellano descargada en: ${ISO_FILE}"
else
  echo "• ISO no descargada (ISO_URL no definido)"
fi
echo
echo "Cierra la sesión para aplicar los cambios del grupo docker (si corresponde)."
echo "======================================================================="
echo

exit 0
