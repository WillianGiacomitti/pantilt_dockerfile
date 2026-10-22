FROM osrf/ros:humble-desktop

ENV DEBIAN_FRONTEND=noninteractive

# UID/GID do usuário do host, para que os arquivos do bind mount ./ros2_ws
# pertençam a você e não ao root. Preenchidos pelo iniciar_ptu.sh via .env.
ARG HOST_UID=1000
ARG HOST_GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-rosbridge-suite \
    ros-humble-vision-msgs \
    ros-humble-cv-bridge \
    ros-humble-web-video-server \
    python3-pip \
    git \
    sudo \
    && pip3 install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu121 \
    && pip3 install --no-cache-dir pyserial ultralytics "numpy<2" \
    && rm -rf /var/lib/apt/lists/*

# Deve vir DEPOIS do ultralytics: o torch puxa setuptools 84, que quebra o
# colcon (exige <80). 58.2.0 é a versão recomendada para o ROS 2 Humble.
# O torch vem do índice cu121 (CUDA 12.1), compatível com drivers a partir da
# série 525. O torch padrão do pip (CUDA 13) exige um driver bem mais novo.
RUN pip3 install --no-cache-dir setuptools==58.2.0

# Usuário não-root com o UID/GID do host. dialout (serial) e video (câmera)
# são reforçados em runtime pelo group_add do compose, que usa os GIDs do host.
RUN (getent group ${HOST_GID} || groupadd -g ${HOST_GID} ros) \
    && (id -u ${HOST_UID} >/dev/null 2>&1 && userdel -r $(id -nu ${HOST_UID}) || true) \
    && useradd -m -u ${HOST_UID} -g ${HOST_GID} -s /bin/bash ros \
    && usermod -aG dialout,video,sudo ros \
    && echo "ros ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ros \
    && chmod 0440 /etc/sudoers.d/ros

ENV HOME=/home/ros

WORKDIR /app
RUN chown ros:${HOST_GID} /app

# Script de inicialização (mantido como arquivo separado, não inline no Dockerfile)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Alias "ws": entra em /ros2_ws e carrega os sources (o .bashrc do usuário já
# carrega o ~/.bash_aliases).
COPY --chown=${HOST_UID}:${HOST_GID} bash_aliases /home/ros/.bash_aliases

USER ros

ENTRYPOINT ["/entrypoint.sh"]
