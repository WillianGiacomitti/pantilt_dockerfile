# ==============================================================================
# Automação Avançada PTU: Gestão Multi-USB e Docker
# ==============================================================================

$wslPath = "/mnt/c/Users/Will/Desktop/TCC/2_Projeto de software/pantilt_dockerfile"

# Lista de IDs de Hardware (VID:PID) dos dispositivos USB
$hardwareIds = @(
    "10c4:ea60", # ESP32 (CP210x)
    "5258:4a55"  # Camera USB (USB Camera, USB Audio)
)

try {
    Write-Host "`n[1/3] Verificando conexoes USB no Windows..." -ForegroundColor Yellow

    # Mapeia a lista atual de dispositivos USB no host Windows
    $usbList = usbipd list

    foreach ($id in $hardwareIds) {
        $linha = $usbList | Select-String $id | Select-Object -First 1

        if (-not $linha) {
            Write-Host "[AVISO] Dispositivo ($id) nao encontrado na USB do Windows!" -ForegroundColor Yellow
            continue
        }

        $texto = $linha.Line

        # Checa se o dispositivo ja esta anexado ao WSL
        if ($texto -match "Attached") {
            Write-Host "[USB] Dispositivo ($id) ja esta anexado ao WSL." -ForegroundColor Cyan
            continue
        }

        # "Not shared": falta o bind, que exige PowerShell como administrador e
        # so precisa ser feito uma vez por dispositivo. Sem ele o attach falha.
        if ($texto -match "Not shared") {
            $busid = ($texto -split "\s+")[0]
            Write-Host "[AVISO] Dispositivo ($id) esta 'Not shared' - o attach vai falhar." -ForegroundColor Yellow
            Write-Host "        Rode UMA VEZ, em um PowerShell como administrador:" -ForegroundColor Yellow
            Write-Host "          usbipd bind --busid $busid" -ForegroundColor White
            continue
        }

        Write-Host "[USB] Anexando dispositivo ($id) ao WSL..." -ForegroundColor Green
        usbipd attach --wsl --hardware-id $id
        Start-Sleep -Seconds 1
    }

    Write-Host "`n[2/3] Verificando status dos Containers Docker..." -ForegroundColor Yellow

    # Checa se existem IDs de containers rodando para este compose
    $runningContainers = wsl -d Ubuntu bash -c "cd '$wslPath' && docker compose ps -q"

    if ($runningContainers) {
        Write-Host "[DOCKER] Containers ja estao em execucao! Conectando ao ambiente existente..." -ForegroundColor Cyan
    } else {
        Write-Host "[DOCKER] Iniciando containers..." -ForegroundColor Green
        wsl -d Ubuntu bash -c "cd '$wslPath' && docker compose up -d"
    }

    Write-Host "`n[3/3] Sistema PTU Operacional!" -ForegroundColor Green
    Write-Host "----------------------------------------------------------------------"
    Write-Host " Exibindo logs em tempo real." -ForegroundColor Cyan
    Write-Host " Para parar os containers e fechar, pressione [Ctrl + C]." -ForegroundColor White
    Write-Host " O container e apenas parado, nao destruido: o que voce instalou" -ForegroundColor White
    Write-Host " dentro dele continua la na proxima vez que subir." -ForegroundColor White
    Write-Host "----------------------------------------------------------------------`n"

    # Acompanha logs em tempo real
    wsl -d Ubuntu bash -c "cd '$wslPath' && docker compose logs -f"

} finally {
    Write-Host "`n`n[ENCERRANDO] Pressionado fechar/Ctrl+C. Parando containers Docker..." -ForegroundColor Red
    # "stop" em vez de "down": preserva o container e tudo que foi instalado
    # dentro dele (ex: Claude Code, login e chats). "down" destruiria a camada
    # gravavel e esse estado seria perdido.
    wsl -d Ubuntu bash -c "cd '$wslPath' && docker compose stop"
    Write-Host "[OK] Containers parados (preservados) com sucesso!" -ForegroundColor Green
    Start-Sleep -Seconds 2
}