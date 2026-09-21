#!/bin/bash
# Este script e o PID 1 do container.
set -e

source /opt/ros/humble/setup.bash

# ---------------------------------------------------------------------------
# Funções Auxiliares: Converte VID:PID para o nó de dispositivo /dev no Linux
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

# Busca ID do Joystick (/dev/input/jsX -> retorna apenas o numero X) pelo VID:PID
get_joy_id_by_vid_pid() {
    local target_vid_pid="$1"
    local vid="${target_vid_pid%%:*}"
    local pid="${target_vid_pid##*:}"

    for sys_dev in /sys/class/input/js*; do
        [ -e "$sys_dev" ] || continue
        local dev_dir
        dev_dir=$(readlink -f "$sys_dev/device" 2>/dev/null) || continue

        while [ "$dev_dir" != "/" ] && [ -n "$dev_dir" ]; do
            if [ -f "$dev_dir/idVendor" ] && [ -f "$dev_dir/idProduct" ]; then
                local v=$(cat "$dev_dir/idVendor" 2>/dev/null)
                local p=$(cat "$dev_dir/idProduct" 2>/dev/null)
                if [ "$v" = "$vid" ] && [ "$p" = "$pid" ]; then
                    local js_name=$(basename "$sys_dev")
                    echo "${js_name#js}"
                    return 0
                fi
            fi
            dev_dir=$(dirname "$dev_dir")
        done
    done
    return 1
}

# ---------------------------------------------------------------------------
# Resolução dinâmica dos dispositivos USB
# ---------------------------------------------------------------------------
ESP32_VID_PID="${ESP32_VID_PID:-10c4:ea60}"
JOY_VID_PID="${JOY_VID_PID:-2dc8:310a}"

# Resolvendo porta Serial da ESP32
RESOLVED_SERIAL_PORT=$(get_serial_by_vid_pid "$ESP32_VID_PID" || true)
if [ -z "$RESOLVED_SERIAL_PORT" ]; then
    echo "[entrypoint] AVISO: ESP32 ($ESP32_VID_PID) nao encontrada via VID:PID. Usando fallback /dev/ttyUSB0"
    SERIAL_PORT="${SERIAL_PORT:-/dev/ttyUSB0}"
else
    SERIAL_PORT="$RESOLVED_SERIAL_PORT"
    echo "[entrypoint] ESP32 identificada via VID:PID ($ESP32_VID_PID) em: $SERIAL_PORT"
fi

# Resolvendo ID do Joystick
RESOLVED_JOY_ID=$(get_joy_id_by_vid_pid "$JOY_VID_PID" || true)
if [ -z "$RESOLVED_JOY_ID" ]; then
    echo "[entrypoint] AVISO: Controle ($JOY_VID_PID) nao encontrado via VID:PID. Usando fallback device_id=0"
    JOY_DEVICE_ID="${JOY_DEVICE_ID:-0}"
else
    JOY_DEVICE_ID="$RESOLVED_JOY_ID"
    echo "[entrypoint] Controle identificado via VID:PID ($JOY_VID_PID) no ID: js$JOY_DEVICE_ID"
fi

# ---------------------------------------------------------------------------
# 1. Interface web estática (index.html) - serve na porta 8080
# ---------------------------------------------------------------------------
if [ -d "/app/web" ]; then
  echo "[entrypoint] Subindo servidor web em :8080"
  cd /app/web && python3 -m http.server 8080 &
  cd /app
fi

# ---------------------------------------------------------------------------
# 2. rosbridge_websocket - ponte entre a página web (roslib.js) e os tópicos ROS
# ---------------------------------------------------------------------------
echo "[entrypoint] Subindo rosbridge_websocket em :9090"
ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=9090 &

# ---------------------------------------------------------------------------
# 3. joy_node - lê o controle em /dev/input/jsX e publica sensor_msgs/Joy
# ---------------------------------------------------------------------------
echo "[entrypoint] Subindo joy_node (device_id=${JOY_DEVICE_ID})"
ros2 run joy joy_node --ros-args \
    -p device_id:="${JOY_DEVICE_ID}" \
    -p deadzone:=0.05 &

# ---------------------------------------------------------------------------
# 4. joystick_bridge_node - traduz /joy em comandos para o PTU
# ---------------------------------------------------------------------------
echo "[entrypoint] Subindo joystick_bridge_node"
python3 /app/joystick_bridge_node.py &

# ---------------------------------------------------------------------------
# 5. serial_bridge_node - fala com a ESP32 (processo principal)
# ---------------------------------------------------------------------------
echo "[entrypoint] Subindo serial_bridge_node (device=${SERIAL_PORT})"
exec python3 /app/serial_bridge_node.py --ros-args \
    -p device:="${SERIAL_PORT}" \
    -p baud:=921600