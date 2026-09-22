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
# Clona o workspace ROS 2 (pantilt_ros) caso ainda não exista no bind mount
# ---------------------------------------------------------------------------
if [ ! -d "/ros2_ws/src/pantilt_ros" ]; then
    echo "[entrypoint] /ros2_ws/src/pantilt_ros nao encontrado. Clonando repositorio..."
    mkdir -p /ros2_ws/src
    git clone https://github.com/WillianGiacomitti/pantilt_ros /ros2_ws/src/pantilt_ros \
        || echo "[entrypoint] AVISO: falha ao clonar pantilt_ros. Verifique rede/URL e clone manualmente se necessario."
else
    echo "[entrypoint] /ros2_ws/src/pantilt_ros ja existe. Pulando clone."
fi

# ---------------------------------------------------------------------------
# Nenhum nó ROS é iniciado automaticamente. Entre com
# "docker exec -it ptu_web_bridge bash", builde o workspace e dê o launch
# manualmente (ver fluxo de uso no CLAUDE.md).
# ---------------------------------------------------------------------------
echo "[entrypoint] Ambiente pronto. Container ocioso aguardando 'docker exec'."
exec sleep infinity
