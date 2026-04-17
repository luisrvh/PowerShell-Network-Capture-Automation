#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10080)]
    [int]$Minutos
)

$ErrorActionPreference = 'Stop'

function Test-Administrador {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','OK','ERROR')]
        [string]$Level = 'INFO'
    )

    $line = "[{0}] {1}" -f $Level, $Message
    Write-Host $line
    Add-Content -Path $script:LogFile -Value $line
}

try {
    if (-not (Test-Administrador)) {
        Write-Host 'Solicitando privilegios de administrador...'

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""

        if ($PSBoundParameters.ContainsKey('Minutos')) {
            $psi.Arguments += " -Minutos $Minutos"
        }

        $psi.Verb = 'runas'
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }

    $Base = Split-Path -Parent $PSCommandPath
    Set-Location -Path $Base

    $Etl2Pcap = Join-Path $Base 'etl2pcapng.exe'
    if (-not (Test-Path -LiteralPath $Etl2Pcap)) {
        Write-Host '[ERROR] No se encontró etl2pcapng.exe en la misma carpeta del script.'
        Write-Host "Ruta esperada: $Base"
        Read-Host 'Presiona Enter para salir'
        exit 1
    }

    $Stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $Nombre = "captura_$Stamp"
    $ETL = Join-Path $Base "$Nombre.etl"
    $PCAP = Join-Path $Base "$Nombre.pcapng"
    $CSV = Join-Path $Base "$Nombre.csv"
    $script:LogFile = Join-Path $Base "$Nombre.log"

    if (-not $PSBoundParameters.ContainsKey('Minutos')) {
        Write-Host '====================================='
        Write-Host '  CAPTURA DE RED AUTOMÁTICA'
        Write-Host '====================================='
        Write-Host ''
        Write-Host "Carpeta de trabajo: $Base"
        Write-Host ''
        Write-Host 'Archivos que se generarán:'
        Write-Host "- $Nombre.etl"
        Write-Host "- $Nombre.pcapng"
        Write-Host "- $Nombre.csv"
        Write-Host "- $Nombre.log"
        Write-Host ''

        $entrada = Read-Host 'Tiempo de captura en minutos'
        if (-not [int]::TryParse($entrada, [ref]$Minutos) -or $Minutos -le 0) {
            Write-Host '[ERROR] Debes ingresar un número mayor a 0.'
            Read-Host 'Presiona Enter para salir'
            exit 1
        }
    }

    $Segundos = $Minutos * 60

    @(
        '====================================='
        'CAPTURA DE RED AUTOMÁTICA'
        '====================================='
        "Fecha y hora: $Stamp"
        "Carpeta base: $Base"
        "ETL: $ETL"
        "PCAPNG: $PCAP"
        "CSV: $CSV"
        "LOG: $script:LogFile"
        "Minutos: $Minutos"
        "Segundos: $Segundos"
        '====================================='
    ) | Set-Content -Path $script:LogFile

    Write-Log -Message 'Iniciando captura...'

    $null = & netsh trace start capture=yes tracefile="$ETL" persistent=no report=disabled correlation=no 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Level ERROR -Message 'No se pudo iniciar netsh trace. Revisa permisos o políticas del equipo.'
        Read-Host 'Presiona Enter para salir'
        exit 1
    }

    Write-Log -Level OK -Message 'Captura iniciada correctamente.'
    Write-Host "Esperando $Minutos minuto(s)..."
    Start-Sleep -Seconds $Segundos

    Write-Log -Message 'Deteniendo captura...'
    $null = & netsh trace stop 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Level ERROR -Message 'No se pudo detener correctamente la captura.'
        Read-Host 'Presiona Enter para salir'
        exit 1
    }

    Write-Log -Level OK -Message 'Captura detenida.'

    if (-not (Test-Path -LiteralPath $ETL)) {
        Write-Log -Level ERROR -Message 'No se generó el archivo ETL.'
        Read-Host 'Presiona Enter para salir'
        exit 1
    }

    Write-Log -Level OK -Message "ETL generado: $ETL"

    Write-Log -Message 'Convirtiendo ETL a PCAPNG...'
    $pcapOutput = & $Etl2Pcap $ETL $PCAP 2>&1
    if ($pcapOutput) {
        $pcapOutput | Add-Content -Path $script:LogFile
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Log -Level ERROR -Message 'Falló la conversión a PCAPNG. Puede que el ETL no contenga paquetes convertibles.'
    }
    elseif (Test-Path -LiteralPath $PCAP) {
        Write-Log -Level OK -Message "PCAPNG generado: $PCAP"
    }
    else {
        Write-Log -Level ERROR -Message 'El proceso terminó pero no se encontró el PCAPNG.'
    }

    Write-Log -Message 'Convirtiendo ETL a CSV...'
    $csvOutput = & tracerpt $ETL -o $CSV -of CSV 2>&1
    if ($csvOutput) {
        $csvOutput | Add-Content -Path $script:LogFile
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Log -Level ERROR -Message 'Falló la conversión a CSV.'
    }
    elseif (Test-Path -LiteralPath $CSV) {
        Write-Log -Level OK -Message "CSV generado: $CSV"
    }
    else {
        Write-Log -Level ERROR -Message 'El proceso terminó pero no se encontró el CSV.'
    }

    Add-Content -Path $script:LogFile -Value ''
    Add-Content -Path $script:LogFile -Value '====================================='
    Add-Content -Path $script:LogFile -Value 'PROCESO FINALIZADO'
    Add-Content -Path $script:LogFile -Value '====================================='

    Write-Host ''
    Write-Host '====================================='
    Write-Host '  PROCESO FINALIZADO'
    Write-Host '====================================='
    Write-Host ''
    Write-Host "Todo quedó guardado en: $Base"
    Write-Host ''
    Write-Host 'Archivos generados:'
    Write-Host "- $Nombre.etl"
    Write-Host "- $Nombre.pcapng"
    Write-Host "- $Nombre.csv"
    Write-Host "- $Nombre.log"
    Write-Host ''

    Read-Host 'Presiona Enter para salir'
    exit 0
}
catch {
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value "[ERROR] $($_.Exception.Message)"
    }

    Write-Host "[ERROR] $($_.Exception.Message)"
    Read-Host 'Presiona Enter para salir'
    exit 1
}
