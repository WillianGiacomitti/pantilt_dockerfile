# ==============================================================================
# Automação Avançada PTU: Gestão Inteligente de USB e Docker
# ==============================================================================

$wslPath = "/mnt/c/Users/Will/Desktop/TCC/2_Detector/pantilt_dockerfile"
$hardwareId = "10c4:ea60"

try {
    Write-Host "`n[1/3] Verificando conexao USB do ESP32..." -ForegroundColor Yellow

    # Lista dispositivos usbipd
    $usbList = usbipd list
    $espDevice = $usbList | Select-String $hardwareId

    if (-not $espDevice) {
        Write-Host "[ERRO] ESP32 nao encontrado na porta USB do Windows!" -ForegroundColor Red
        Write-Host "Verifique o cabo USB e tente novamente." -ForegroundColor Red
        return
    }

    # Verifica se a placa ja esta no estado Attached
    if ($espDevice -match "Attached") {
        Write-Host "[USB] ESP32 ja esta anexado ao WSL." -ForegroundColor Cyan
    } else {
        Write-Host "[USB] Anexando ESP32 ao WSL Ubuntu..." -ForegroundColor Green
        usbipd attach --wsl --hardware-id $hardwareId
        Start-Sleep -Seconds 2
    }

    # Garante a existencia do /dev/ttyUSB0 dentro do Linux
    $devCheck = wsl -d Ubuntu bash -c "ls /dev/ttyUSB* 2>/dev/null"
    if (-not $devCheck) {
        Write-Host "[AVISO] Mapeamento Serial nao encontrado. Reiniciando porta..." -ForegroundColor Yellow
        usbipd detach --hardware-id $hardwareId 2>$null
        Start-Sleep -Seconds 1
        usbipd attach --wsl --hardware-id $hardwareId
        Start-Sleep -Seconds 2
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

    # Acompanha logs em tempo real (Mantem o script travado aqui ate o Ctrl+C)
    wsl -d Ubuntu bash -c "cd $wslPath && docker compose logs -f"

} finally {
    # Este bloco SEMPRE sera executado quando o script for interrompido (Ctrl+C ou erro)
    Write-Host "`n`n[ENCERRANDO] Pressionado fechar/Ctrl+C. Desligando containers Docker..." -ForegroundColor Red
    wsl -d Ubuntu bash -c "cd $wslPath && docker compose down"
    Write-Host "[OK] Containers desligados com sucesso!" -ForegroundColor Green
    Start-Sleep -Seconds 2
}