# CLAUDE.md — pantilt_dockerfile

Instruções para o Claude Code neste repositório. Leia este arquivo inteiro antes de qualquer tarefa.

## Contexto

Ambiente Docker do TCC (controle servo visual pan-tilt). Este repositório contém **apenas o ambiente**: imagem, compose, entrypoint e scripts de inicialização no Windows. Os nós ROS 2 ficam no repositório `pantilt_ros`, e a arquitetura em `pantilt_ros/docs/architecture.md`.

**Regra principal: não crie nem mantenha nós ROS (arquivos .py de nós) neste repositório.**

## Ambiente do host

- Windows + WSL2 (Ubuntu) + Docker.
- Dispositivos USB repassados ao WSL com `usbipd` (scripts `iniciar_ptu.ps1` e `iniciar_ptu.bat`):
  - ESP32 (CP210x): VID:PID `10c4:ea60`;
  - câmera USB: ainda a definir. O kernel padrão do WSL2 normalmente não tem driver UVC; a alternativa é fazer stream MJPEG a partir do Windows.
- O entrypoint resolve a porta serial da ESP32 pelo VID:PID.

## Estado alvo (a implementar)

**Dockerfile**

- Base `osrf/ros:humble-desktop`.
- Pacotes apt: `ros-humble-rosbridge-suite`, `ros-humble-vision-msgs`, `ros-humble-cv-bridge`, `ros-humble-web-video-server`, `python3-pip`, `git`.
- pip: `pyserial`, `ultralytics` (torch de CPU no início) e **`"numpy<2"`**. Sem essa trava, o numpy 2 quebra o `cv_bridge` do Humble.
- Remover `ros-humble-joy`: o joystick foi descartado.

**docker-compose.yml**

- Volume `./ros2_ws:/ros2_ws`, para que as alterações persistam e fiquem visíveis no Windows.
- Portas: 8080 (web), 9090 (rosbridge), 8081 (web_video_server).
- Manter `/dev:/dev` e `privileged: true` (acesso à serial).
- Remover `JOY_VID_PID`.

**entrypoint.sh**

1. `source /opt/ros/humble/setup.bash`.
2. Resolver `SERIAL_PORT` pelo VID:PID e exportar a variável (lógica atual mantida).
3. Se `/ros2_ws/src/pantilt_ros` não existir, `git clone https://github.com/WillianGiacomitti/pantilt_ros /ros2_ws/src/pantilt_ros`.
4. **Não iniciar nós automaticamente.** Terminar com `exec sleep infinity`.
5. O usuário entra com `docker exec -it <container> bash`, faz o build e lança manualmente.
6. O servidor HTTP, o rosbridge e o web_video_server passam a subir pelo launch do `pantilt_web`, e não mais pelo entrypoint.

**Remover do repositório** (migrados ou descartados):

- `serial_bridge_node.py` → vai para `pantilt_ros/pantilt_hardware`;
- `joystick_bridge_node.py` → descartado;
- `web/` → vai para `pantilt_ros/pantilt_web`;
- variáveis não usadas do `.env` (`CONTAINER_NAME`, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`, que não está instalado).

## Fluxo de uso esperado

```bash
# Windows: anexa USB e sobe o container
iniciar_ptu.bat

# dentro do container
docker exec -it ptu_web_bridge bash
cd /ros2_ws && colcon build --symlink-install && source install/setup.bash
ros2 launch pantilt_bringup hardware.launch.py
```

## Regras de trabalho

1. **Planeje antes de editar.** Liste os arquivos que vai tocar e espere aprovação.
2. **Escopo estrito:** não edite arquivos fora da tarefa.
3. **Não faça commits** nem push. O autor revisa e commita.
4. **Não adicione dependências** sem perguntar.
5. Comentários em português.
6. Mudanças nos scripts `.ps1`/`.bat` devem continuar funcionando no Windows (PowerShell) e manter o caminho do WSL configurável.
7. Ao terminar, explique o que mudou e como validar (`docker compose build`, `docker compose up -d`, `docker exec`).

## Ciclo de vida do container

O que é instalado ou ajustado manualmente dentro do container (Claude Code, login, histórico de chats, pacotes avulsos) vive na **camada gravável do container**, não na imagem:

- `docker compose stop` / `up -d` **preservam** esse estado. É o ciclo normal de uso, e é o que o Ctrl+C do `iniciar_ptu.ps1` faz.
- `docker compose down` e qualquer `docker compose build` que recrie o container **descartam** esse estado.

Portanto: o que precisa ser permanente vai para o `Dockerfile` (ou para um volume no `docker-compose.yml`), nunca apenas dentro do container. O pin `setuptools==58.2.0` está no Dockerfile por esse motivo — precisa vir depois do `ultralytics`, porque o torch instala uma versão que quebra o `colcon`.

Para reanexar a ESP32 quando o USB cai: Ctrl+C na janela do `iniciar_ptu.bat` e rodar o script de novo. O `up -d` reexecuta o entrypoint, então o `SERIAL_PORT` é re-resolvido sem perder nada.