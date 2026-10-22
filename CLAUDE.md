# CLAUDE.md — pantilt_dockerfile (branch `linux`)

Instruções para o Claude Code neste repositório. Leia este arquivo inteiro antes de qualquer tarefa.

## Contexto

Ambiente Docker do TCC (controle servo visual pan-tilt). Este repositório contém **apenas o ambiente**: imagem, compose, entrypoint e script de inicialização. Os nós ROS 2 ficam no repositório `pantilt_ros`, e a arquitetura em `pantilt_ros/docs/architecture.md`.

**Regra principal: não crie nem mantenha nós ROS (arquivos .py de nós) neste repositório.**

Esta branch roda em **Linux nativo**. A `master` é a versão Windows + WSL2 (com `usbipd` e os scripts `.ps1`/`.bat`). O `ajustes_pantilt_dockerfile.md` descreve o histórico do lado Windows e não foi atualizado.

## Ambiente do host

- Linux com Docker + Compose v2 e o usuário no grupo `docker`.
- USB direto no host, sem `usbipd`/bind/attach:
  - ESP32 (CP210x): VID:PID `10c4:ea60`;
  - câmera USB: VID:PID `5258:4a55`. A webcam integrada de notebook ocupa `/dev/video0`, então a numeração varia e o entrypoint resolve o nó certo por VID:PID.
- GPU NVIDIA: requer `nvidia-container-toolkit` no host.
- GUI (rqt/rviz): X11 do host; o `iniciar_ptu.sh` roda `xhost +local:`.

## Estado atual

**Dockerfile**

- Base `osrf/ros:humble-desktop`, pacotes apt `rosbridge-suite`, `vision-msgs`, `cv-bridge`, `web-video-server`, `python3-pip`, `git`, `sudo`.
- pip: `pyserial`, `ultralytics` (torch com CUDA, o padrão do pip em Linux x86) e **`"numpy<2"`** (numpy 2 quebra o `cv_bridge` do Humble). `setuptools==58.2.0` depois, porque o torch instala uma versão que quebra o `colcon`.
- Usuário `ros` criado com `HOST_UID`/`HOST_GID` (build args), nos grupos `dialout`, `video` e `sudo` (sem senha). O container roda como esse usuário, então os arquivos de `./ros2_ws` são seus.

**docker-compose.yml**

- `network_mode: host`: 8080 (web), 9090 (rosbridge) e 8081 (web_video_server) ficam direto em `localhost`; não há `ports:`. Cuidado com `ROS_DOMAIN_ID` igual ao de outro ROS 2 rodando no host (padrão 42).
- `user` e `group_add` com UID/GID e GIDs de `dialout`/`video` do host (vindos do `.env`).
- `privileged: true` e `/dev:/dev` (serial e `/dev/video*`, inclusive câmera plugada depois).
- Volumes: `./ros2_ws:/ros2_ws` e `/tmp/.X11-unix`.
- GPU via `deploy.resources.reservations.devices` (driver nvidia).
- `FASTRTPS_DEFAULT_PROFILES_FILE` apontando para o `fastdds.xml` do `pantilt_ros`: vale para **todo** processo ROS do container.
- `shm_size: "1gb"`: cada processo ROS reserva ~10 MB de SHM; com os 64 MB padrão o Fast DDS cai para UDP fragmentado e as imagens perdem quadros.

**entrypoint.sh**

1. `source /opt/ros/humble/setup.bash`.
2. Resolve `SERIAL_PORT` (ESP32) e `CAMERA_DEVICE` (câmera) por VID:PID e exporta; com fallback para `/dev/ttyUSB0` e `/dev/video0`.
3. Se `/ros2_ws/src/pantilt_ros` não existir, clona `https://github.com/WillianGiacomitti/pantilt_ros`.
4. Avisa se o `fastdds.xml` não existir.
5. **Não inicia nós.** Termina com `exec sleep infinity`; o servidor web, o rosbridge e o web_video_server sobem pelo launch do `pantilt_web`.

**.env**: `ROS_DOMAIN_ID`, `HOST_UID`, `HOST_GID`, `DIALOUT_GID`, `VIDEO_GID`. Os quatro últimos são reescritos pelo `iniciar_ptu.sh`.

## Fluxo de uso

```bash
# Host: gera o .env, cria ./ros2_ws, sobe o container e mostra os logs
./iniciar_ptu.sh

# Em outro terminal, dentro do container
docker exec -it ptu_web_bridge bash
cd /ros2_ws && colcon build --symlink-install && source install/setup.bash
ros2 launch pantilt_bringup hardware.launch.py
```

Ctrl+C no `iniciar_ptu.sh` faz `docker compose stop` (preserva o container). Se a ESP32 for reconectada, rode `docker compose restart` ou o script de novo: o entrypoint re-resolve `SERIAL_PORT` e `CAMERA_DEVICE`.

## Regras de trabalho

1. **Planeje antes de editar.** Liste os arquivos que vai tocar e espere aprovação.
2. **Escopo estrito:** não edite arquivos fora da tarefa.
3. **Não faça commits** nem push. O autor revisa e commita.
4. **Não adicione dependências** sem perguntar.
5. Comentários em português.
6. Ao terminar, explique o que mudou e como validar (`docker compose build`, `docker compose up -d`, `docker exec`).

## Ciclo de vida do container

O que é instalado ou ajustado manualmente dentro do container (Claude Code, login, histórico de chats, pacotes avulsos) vive na **camada gravável do container**, não na imagem:

- `docker compose stop` / `up -d` **preservam** esse estado. É o ciclo normal de uso, e é o que o Ctrl+C do `iniciar_ptu.sh` faz.
- `docker compose down` e qualquer `docker compose build` que recrie o container **descartam** esse estado.

Portanto: o que precisa ser permanente vai para o `Dockerfile` (ou para um volume no `docker-compose.yml`), nunca apenas dentro do container.
