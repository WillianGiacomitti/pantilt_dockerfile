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

WORKDIR /app

# Script de inicialização (mantido como arquivo separado, não inline no Dockerfile)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]