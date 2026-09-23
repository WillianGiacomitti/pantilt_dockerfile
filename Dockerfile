FROM osrf/ros:humble-desktop

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-rosbridge-suite \
    ros-humble-vision-msgs \
    ros-humble-cv-bridge \
    ros-humble-web-video-server \
    python3-pip \
    git \
    && pip3 install --no-cache-dir pyserial ultralytics "numpy<2" \
    && rm -rf /var/lib/apt/lists/*

# Deve vir DEPOIS do ultralytics: o torch puxa setuptools 84, que quebra o
# colcon (exige <80). 58.2.0 é a versão recomendada para o ROS 2 Humble.
RUN pip3 install --no-cache-dir setuptools==58.2.0

WORKDIR /app

# Script de inicialização (mantido como arquivo separado, não inline no Dockerfile)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]