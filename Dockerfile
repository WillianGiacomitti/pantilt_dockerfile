FROM osrf/ros:humble-desktop

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-rosbridge-suite \
    ros-humble-joy \
    python3-pip \
    && pip3 install --no-cache-dir pyserial \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Nós ROS 2 (Python) da ponte serial e do joystick
COPY serial_bridge_node.py /app/serial_bridge_node.py
COPY joystick_bridge_node.py /app/joystick_bridge_node.py

# Interface web estática servida pelo http.server
COPY web/ /app/web/

# Script de inicialização (mantido como arquivo separado, não inline no Dockerfile)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]