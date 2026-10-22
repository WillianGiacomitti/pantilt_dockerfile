#!/bin/bash
# Este script e o PID 1 do container.
set -e

source /opt/ros/humble/setup.bash

# ---------------------------------------------------------------------------
# Função Auxiliar: Converte VID:PID para o nó de dispositivo /dev no Linux
# ---------------------------------------------------------------------------

# Busca porta Serial (/dev/ttyUSB* ou /dev/ttyACM*) pelo VID:PID
get_serial_by_vid_pid() {
    local target_vid_pid="$1"
    local vid="${target_vid_pid%%:*}"
    local pid="${target_vid_pid##*:}"

    for sys_dev in /sys/class/tty/ttyUSB* /sys/class/tty/ttyACM*; do
        [ -e "$sys_dev" ] || continue
        local dev_dir
        dev_dir=$(readlink -f "$sys_dev/device" 2>/dev/null) || continue

        while [ "$dev_dir" != "/" ] && [ -n "$dev_dir" ]; do
            if [ -f "$dev_dir/idVendor" ] && [ -f "$dev_dir/idProduct" ]; then
                local v=$(cat "$dev_dir/idVendor" 2>/dev/null)
                local p=$(cat "$dev_dir/idProduct" 2>/dev/null)
                if [ "$v" = "$vid" ] && [ "$p" = "$pid" ]; then
                    echo "/dev/$(basename "$sys_dev")"
                    return 0
                fi
            fi
            dev_dir=$(dirname "$dev_dir")
        done
    done
    return 1
}

# Busca o nó de captura /dev/videoN de uma câmera USB pelo VID:PID. Cada câmera
# UVC expõe vários nós (captura + metadados); o de captura tem index 0.
get_video_by_vid_pid() {
    local target_vid_pid="$1"
    local vid="${target_vid_pid%%:*}"
    local pid="${target_vid_pid##*:}"

    for sys_dev in /sys/class/video4linux/video*; do
        [ -e "$sys_dev" ] || continue
        [ "$(cat "$sys_dev/index" 2>/dev/null)" = "0" ] || continue
        local dev_dir
        dev_dir=$(readlink -f "$sys_dev/device" 2>/dev/null) || continue

        while [ "$dev_dir" != "/" ] && [ -n "$dev_dir" ]; do
            if [ -f "$dev_dir/idVendor" ] && [ -f "$dev_dir/idProduct" ]; then
                local v=$(cat "$dev_dir/idVendor" 2>/dev/null)
                local p=$(cat "$dev_dir/idProduct" 2>/dev/null)
                if [ "$v" = "$vid" ] && [ "$p" = "$pid" ]; then
                    echo "/dev/$(basename "$sys_dev")"
                    return 0
                fi
            fi
            dev_dir=$(dirname "$dev_dir")
        done
    done
    return 1
}

# ---------------------------------------------------------------------------
# Resolução dinâmica da porta serial da ESP32
# ---------------------------------------------------------------------------
ESP32_VID_PID="${ESP32_VID_PID:-10c4:ea60}"

RESOLVED_SERIAL_PORT=$(get_serial_by_vid_pid "$ESP32_VID_PID" || true)
if [ -z "$RESOLVED_SERIAL_PORT" ]; then
    echo "[entrypoint] AVISO: ESP32 ($ESP32_VID_PID) nao encontrada via VID:PID. Usando fallback /dev/ttyUSB0"
    SERIAL_PORT="${SERIAL_PORT:-/dev/ttyUSB0}"
else
    SERIAL_PORT="$RESOLVED_SERIAL_PORT"
    echo "[entrypoint] ESP32 identificada via VID:PID ($ESP32_VID_PID) em: $SERIAL_PORT"
fi
export SERIAL_PORT

# ---------------------------------------------------------------------------
# Resolução dinâmica da câmera USB (o número do /dev/videoN varia, por exemplo
# por causa da webcam integrada do notebook)
# ---------------------------------------------------------------------------
CAMERA_VID_PID="${CAMERA_VID_PID:-5258:4a55}"

RESOLVED_CAMERA=$(get_video_by_vid_pid "$CAMERA_VID_PID" || true)
if [ -z "$RESOLVED_CAMERA" ]; then
    echo "[entrypoint] AVISO: camera ($CAMERA_VID_PID) nao encontrada via VID:PID. Usando fallback /dev/video0"
    CAMERA_DEVICE="${CAMERA_DEVICE:-/dev/video0}"
else
    CAMERA_DEVICE="$RESOLVED_CAMERA"
    echo "[entrypoint] Camera identificada via VID:PID ($CAMERA_VID_PID) em: $CAMERA_DEVICE"
fi
export CAMERA_DEVICE

# ---------------------------------------------------------------------------
# Clona o workspace ROS 2 (pantilt_ros) caso ainda não exista no bind mount
# ---------------------------------------------------------------------------
if [ ! -d "/ros2_ws/src/pantilt_ros" ]; then
    echo "[entrypoint] /ros2_ws/src/pantilt_ros nao encontrado. Clonando repositorio..."
    mkdir -p /ros2_ws/src || echo "[entrypoint] AVISO: sem permissao em /ros2_ws. Crie ./ros2_ws no host antes do 'up' (o iniciar_ptu.sh faz isso)."
    git clone https://github.com/WillianGiacomitti/pantilt_ros /ros2_ws/src/pantilt_ros \
        || echo "[entrypoint] AVISO: falha ao clonar pantilt_ros. Verifique rede/URL e clone manualmente se necessario."
else
    echo "[entrypoint] /ros2_ws/src/pantilt_ros ja existe. Pulando clone."
fi

# ---------------------------------------------------------------------------
# Confere o perfil do Fast DDS. Sem ele o Fast DDS apenas loga XMLPARSER Error
# e segue com os padrões (SHM de 512 KB), então a perda de quadros passaria
# despercebida.
# ---------------------------------------------------------------------------
if [ -n "$FASTRTPS_DEFAULT_PROFILES_FILE" ] && [ ! -f "$FASTRTPS_DEFAULT_PROFILES_FILE" ]; then
    echo "[entrypoint] AVISO: perfil do Fast DDS nao encontrado em $FASTRTPS_DEFAULT_PROFILES_FILE."
    echo "[entrypoint]        Imagens grandes podem perder quadros (ver ajustes_pantilt_dockerfile.md)."
fi

# ---------------------------------------------------------------------------
# Nenhum nó ROS é iniciado automaticamente. Entre com
# "docker exec -it ptu_web_bridge bash", builde o workspace e dê o launch
# manualmente (ver fluxo de uso no CLAUDE.md).
# ---------------------------------------------------------------------------
echo "[entrypoint] Ambiente pronto. Container ocioso aguardando 'docker exec'."
exec sleep infinity
