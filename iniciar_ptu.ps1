# ==============================================================================
# Automação Avançada PTU: Gestão Multi-USB e Docker
# ==============================================================================

$wslPath = "/mnt/c/Users/Will/Desktop/TCC/2_Projeto de software/pantilt_dockerfile"

# Lista de IDs de Hardware (VID:PID) dos dispositivos USB
$hardwareIds = @(
    "10c4:ea60", # ESP32 (CP210x)
    "2dc8:310a"  # Camera USB (VID:PID a confirmar)
)

try {
    Write-Host "`n[1/3] Verificando conexoes USB no Windows..." -ForegroundColor Yellow

    # Mapeia a lista atual de dispositivos USB no host Windows
    $usbList = usbipd list

    foreach ($id in $hardwareIds) {
        $espDevice = $usbList | Select-String $id

        if (-not $espDevice) {
            Write-Host "[AVISO] Dispositivo ($id) nao encontrado na USB do Windows!" -ForegroundColor Yellow
            continue
        }

        # Checa se o dispositivo ja esta anexado ao WSL
        if ($espDevice -match "Attached") {
            Write-Host "[USB] Dispositivo ($id) ja esta anexado ao WSL." -ForegroundColor Cyan
        } else {
            Write-Host "[USB] Anexando dispositivo ($id) ao WSL..." -ForegroundColor Green
            usbipd attach --wsl --hardware-id $id
            Start-Sleep -Seconds 1
        }
    }

    Write-Host "`n[2/3] Verificando status dos Containers Docker..." -ForegroundColor Yellow

    # Checa se existem IDs de containers rodando para este compose
    $runningContainers = wsl -d Ubuntu bash -c "cd $wslPath && docker compose ps -q"

    if ($runningContainers) {
        Write-Host "[DOCKER] Containers ja estao em execucao! Conectando ao ambiente existente..." -ForegroundColor Cyan
    } else {
        Write-Host "[DOCKER] Subindo novos containers..." -ForegroundColor Green
        wsl -d Ubuntu bash -c "cd $wslPath && docker compose up -d"
    }

    Write-Host "`n[3/3] Sistema PTU Operacional!" -ForegroundColor Green
    Write-Host "----------------------------------------------------------------------"
    Write-Host " Exibindo logs em tempo real." -ForegroundColor Cyan
    Write-Host " Para desligar os containers e fechar, pressione [Ctrl + C]." -ForegroundColor White
    Write-Host "----------------------------------------------------------------------`n"

    # Acompanha logs em tempo real
    wsl -d Ubuntu bash -c "cd $wslPath && docker compose logs -f"

} finally {
    Write-Host "`n`n[ENCERRANDO] Pressionado fechar/Ctrl+C. Desligando containers Docker..." -ForegroundColor Red
    wsl -d Ubuntu bash -c "cd $wslPath && docker compose down"
    Write-Host "[OK] Containers desligados com sucesso!" -ForegroundColor Green
    Start-Sleep -Seconds 2
}