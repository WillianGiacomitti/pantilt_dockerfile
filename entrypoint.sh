#!/bin/bash
# Este script é o PID 1 do container: ele é o processo que o Docker considera
# "o container" propriamente dito. Quando ele termina, o container termina.
set -e

source /opt/ros/humble/setup.bash

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
# 3. joy_node - lê o controle 8BitDo em /dev/input/jsX e publica sensor_msgs/Joy
# ---------------------------------------------------------------------------
JOY_DEVICE_ID="${JOY_DEVICE_ID:-0}"
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
# 5. serial_bridge_node - fala com a ESP32 (processo principal, roda em foreground)
#    Fica em foreground de propósito: se ele cair, o container inteiro reinicia
#    (junto com os processos acima), em vez de ficar "meio vivo" sem a ponte serial.
# ---------------------------------------------------------------------------
SERIAL_PORT="${SERIAL_PORT:-/dev/ttyUSB0}"
echo "[entrypoint] Subindo serial_bridge_node (device=${SERIAL_PORT})"
exec python3 /app/serial_bridge_node.py --ros-args \
    -p device:="${SERIAL_PORT}" \
    -p baud:=921600