#!/bin/bash
# ==============================================================================
# Inicialização do ambiente PTU em Linux: gera o .env com UID/GID do host,
# sobe o container e acompanha os logs. Ctrl+C apenas PARA o container.
# ==============================================================================
set -e
cd "$(dirname "$(readlink -f "$0")")"

ESP32_VID_PID="10c4:ea60"
CAMERA_VID_PID="5258:4a55"

# Atualiza (ou acrescenta) uma chave no .env
set_env() {
    touch .env
    if grep -q "^$1=" .env; then
        sed -i "s|^$1=.*|$1=$2|" .env
    else
        echo "$1=$2" >> .env
    fi
}

echo -e "\n[1/3] Preparando ambiente do host..."
set_env HOST_UID "$(id -u)"
set_env HOST_GID "$(id -g)"
set_env DIALOUT_GID "$(getent group dialout | cut -d: -f3)"
set_env VIDEO_GID "$(getent group video | cut -d: -f3)"
# O bind mount precisa existir como seu usuário; senão o Docker o cria como root.
mkdir -p ros2_ws
# Permite que o container abra janelas (rqt/rviz) no X11 do host.
if command -v xhost >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
    xhost +local: >/dev/null 2>&1 || echo "[AVISO] xhost falhou; GUI pode nao abrir."
fi

echo "[2/3] Verificando dispositivos USB..."
for id in "$ESP32_VID_PID" "$CAMERA_VID_PID"; do
    if lsusb -d "$id" >/dev/null 2>&1; then
        echo "[USB] Dispositivo ($id) encontrado."
    else
        echo "[AVISO] Dispositivo ($id) nao encontrado no USB."
    fi
done

parar() {
    echo -e "\n[ENCERRANDO] Parando container (preservado, nao destruido)..."
    # "stop" em vez de "down": preserva a camada gravavel do container.
    docker compose stop
}
trap parar EXIT

echo "[3/3] Subindo container..."
if [ -z "$(docker compose ps -q)" ]; then
    docker compose up -d --build
else
    docker compose up -d
fi
echo "Logs em tempo real. Ctrl+C para parar o container."
docker compose logs -f
