FROM osrf/ros:humble-desktop
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-rosbridge-suite \
    python3-pip \
    && pip3 install pyserial \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY serial_bridge_node.py /app/serial_bridge_node.py

RUN echo '#!/bin/bash\n\
source /opt/ros/humble/setup.bash\n\
\n\
if [ -d "/app/web" ]; then\n\
  cd /app/web && python3 -m http.server 8080 &\n\
fi\n\
\n\
ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=9090 &\n\
\n\
python3 /app/serial_bridge_node.py --ros-args -p device:=${SERIAL_PORT:-/dev/ttyUSB0} -p baud:=921600\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]