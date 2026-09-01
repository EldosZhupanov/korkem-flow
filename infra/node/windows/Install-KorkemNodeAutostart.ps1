#Requires -Version 5.1
<#
.SYNOPSIS
    Устанавливает автозапуск узла KORKEM в WSL2 при входе в Windows.

.DESCRIPTION
    Регистрирует одну задачу Windows Task Scheduler с наивысшими правами.
    Задача запускает WSL, поднимает compose-стек с наложениями pilot и
    wsl-node, ждёт `/health/ready`, а затем обновляет portproxy и правила
    брандмауэра через Update-KorkemNodeAccess.ps1.

    Рабочая копия скриптов хранится в `%ProgramData%\KORKEM\Node`: файл из
    `\\wsl$` нельзя использовать как действие задачи, потому что до первого
    запуска WSL этот путь недоступен.

    ЗАПУСКАТЬ ИЗ WINDOWS, а не из PowerShell, открытого внутри WSL.

.PARAMETER Distro
    Имя дистрибутива WSL. По умолчанию Ubuntu.

.PARAMETER ProjectPath
    Абсолютный Linux-путь к `infra/frappe_bench` внутри дистрибутива.
    При запуске из `\\wsl.localhost\...` путь выводится из расположения этого
    файла. В остальных случаях его надо передать явно.

.PARAMETER SiteName
    Имя сайта для заголовка Host при проверке `/health/ready`.

.PARAMETER Ports
    Порты, для которых Update-KorkemNodeAccess.ps1 создаёт portproxy и
    правила брандмауэра. Первый порт используется для readiness-проверки.

.PARAMETER ReadyTimeoutSeconds
    Максимальное ожидание `/health/ready`. По умолчанию 300 секунд.

.PARAMETER DryRun
    Показывает установку или удаление, не вызывает wsl.exe и ничего не меняет.

.PARAMETER Uninstall
    Удаляет задачу, portproxy, правила брандмауэра, Event Log source и
    установленную копию скриптов с журналом.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KorkemNodeAutostart.ps1 -DryRun -ProjectPath /home/korkem/furniture_ai/infra/frappe_bench

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KorkemNodeAutostart.ps1 -ProjectPath /home/korkem/furniture_ai/infra/frappe_bench

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KorkemNodeAutostart.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [string] $Distro = 'Ubuntu',
    [string] $ProjectPath,
    [string] $SiteName = 'korkem.localhost',
    [int[]] $Ports = @(8000, 9000),
    [ValidateRange(10, 3600)]
    [int] $ReadyTimeoutSeconds = 300,
    [switch] $DryRun,
    [switch] $Uninstall,
    [switch] $RunNode
)

$ErrorActionPreference = 'Stop'
$TaskName = 'KORKEM Node Autostart'
$EventSource = 'KORKEM Node'
$FirewallGroup = 'KORKEM Node'
$ProxyKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\PortProxy\v4tov4\tcp'
$InstallRoot = Join-Path $env:ProgramData 'KORKEM\Node'
$InstalledScript = Join-Path $InstallRoot 'Install-KorkemNodeAutostart.ps1'
$InstalledAccessScript = Join-Path $InstallRoot 'Update-KorkemNodeAccess.ps1'
$ConfigPath = Join-Path $InstallRoot 'config.json'
$LogPath = Join-Path $InstallRoot 'autostart.log'
$PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Parameters {
    param(
        [string] $Distro,
        [string] $ProjectPath,
        [string] $SiteName,
        [int[]] $Ports
    )

    if ([string]::IsNullOrWhiteSpace($Distro) -or $Distro -match '[\r\n]') {
        throw 'Имя дистрибутива WSL пустое или содержит перевод строки.'
    }
    if ([string]::IsNullOrWhiteSpace($ProjectPath) -or $ProjectPath -notmatch '^/' -or $ProjectPath -match '[\r\n]') {
        throw "ProjectPath должен быть абсолютным Linux-путём к infra/frappe_bench. Получено: '$ProjectPath'"
    }
    if ([string]::IsNullOrWhiteSpace($SiteName) -or $SiteName -notmatch '^[A-Za-z0-9._-]+$') {
        throw "Недопустимое имя сайта: '$SiteName'"
    }
    if (-not $Ports -or $Ports.Count -eq 0) {
        throw 'Нужен хотя бы один порт.'
    }
    $invalidPorts = @($Ports | Where-Object { $_ -lt 1 -or $_ -gt 65535 })
    if ($invalidPorts.Count -gt 0) {
        throw "Порт вне диапазона 1..65535: $($invalidPorts -join ', ')"
    }
    if (@($Ports | Select-Object -Unique).Count -ne $Ports.Count) {
        throw 'Список портов содержит повторы.'
    }
}

function Resolve-ProjectPath {
    param([string] $ExplicitPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return $ExplicitPath.TrimEnd('/')
    }

    # Типичный путь при запуске файла прямо из репозитория WSL:
    # \\wsl.localhost\Ubuntu\home\korkem\furniture_ai\infra\node\windows
    $pattern = '^\\\\(?:wsl\.localhost|wsl\$)\\[^\\]+\\(.+)\\infra\\node\\windows$'
    if ($PSScriptRoot -match $pattern) {
        $repositoryPath = '/' + ($Matches[1] -replace '\\', '/')
        return "$repositoryPath/infra/frappe_bench"
    }

    throw @'
Не удалось вывести Linux-путь проекта из расположения скрипта.
Передайте его явно, например:

    -ProjectPath /home/korkem/furniture_ai/infra/frappe_bench
'@
}

function ConvertTo-OneLine {
    param([AllowNull()] $Value)

    if ($null -eq $Value) { return '' }
    $text = (($Value | Out-String).Trim() -replace '[\r\n]+', ' ')
    if ($text.Length -gt 600) { return $text.Substring(0, 600) }
    return $text
}

function Write-NodeLog {
    param(
        [string] $Address,
        [string] $Step,
        [string] $Result,
        [string] $Message = ''
    )

    if (-not (Test-Path $InstallRoot)) {
        New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    }
    $safeMessage = ConvertTo-OneLine $Message
    $line = '{0} address={1} step={2} result={3} message="{4}"' -f `
        (Get-Date).ToString('o'), $Address, $Step, $Result, $safeMessage.Replace('"', "'")
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Write-FailureEvent {
    param([string] $Message)

    try {
        Write-EventLog -LogName Application -Source $EventSource `
            -EntryType Error -EventId 1001 -Message $Message
    } catch {
        try {
            Write-NodeLog -Address '-' -Step 'EVENT_LOG' -Result 'FAIL' `
                -Message "Не удалось записать ошибку в Windows Event Log: $($_.Exception.Message)"
        } catch {
            # Исходная ошибка всё равно завершит задачу ненулевым кодом. Здесь
            # нельзя заменить её вторичной ошибкой аварийного журналирования.
        }
    }
}

function Get-WslAddress {
    param([string] $Distro)

    $raw = & wsl.exe -d $Distro -- hostname -I 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($raw | Out-String))) {
        throw "Не удалось получить адрес WSL: $(ConvertTo-OneLine $raw)"
    }
    $address = (($raw | Out-String) -split '\s+' |
        Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } |
        Select-Object -First 1)
    if (-not $address) {
        throw "WSL не вернул IPv4-адрес. Получено: '$(ConvertTo-OneLine $raw)'"
    }
    return $address
}

function Start-WslDistribution {
    param([string] $Distro)

    $output = & wsl.exe -d $Distro -- true 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось запустить дистрибутив '$Distro': $(ConvertTo-OneLine $output)"
    }
}

function Start-ComposeStack {
    param([pscustomobject] $Config)

    $output = & wsl.exe -d $Config.Distro --cd $Config.ProjectPath -- `
        docker compose `
        -f docker-compose.yml `
        -f docker-compose.pilot.yml `
        -f docker-compose.wsl-node.yml `
        up -d 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose up завершился с ошибкой: $(ConvertTo-OneLine $output)"
    }
}

function Wait-NodeReady {
    param([pscustomobject] $Config)

    $port = [int]$Config.Ports[0]
    $url = "http://127.0.0.1:${port}/health/ready"
    $headers = @{ Host = [string]$Config.SiteName }
    $deadline = (Get-Date).AddSeconds([int]$Config.ReadyTimeoutSeconds)
    $lastError = 'ответ ещё не получен'

    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $url -Headers $headers `
                -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                return
            }
            $lastError = "HTTP $($response.StatusCode)"
        } catch {
            $lastError = ConvertTo-OneLine $_.Exception.Message
        }
        Start-Sleep -Seconds 2
    }

    throw "Узел не стал готов за $($Config.ReadyTimeoutSeconds) с: $url; последняя ошибка: $lastError"
}

function Update-NodeAccess {
    param([pscustomobject] $Config)

    $escapedScript = $InstalledAccessScript.Replace("'", "''")
    $escapedDistro = ([string]$Config.Distro).Replace("'", "''")
    $portLiteral = (@($Config.Ports | ForEach-Object { [int]$_ }) -join ',')
    $command = "& '$escapedScript' -Distro '$escapedDistro' -Ports @($portLiteral)"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $output = & $PowerShellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
        -EncodedCommand $encoded 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Update-KorkemNodeAccess.ps1 завершился с кодом $LASTEXITCODE`: $(ConvertTo-OneLine $output)"
    }
}

function Invoke-NodeStartup {
    $address = '-'
    $step = 'CONFIG'

    try {
        if (-not (Test-Path -LiteralPath $ConfigPath)) {
            throw "Не найден файл конфигурации '$ConfigPath'. Переустановите автозапуск KORKEM."
        }
        $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Parameters -Distro $config.Distro -ProjectPath $config.ProjectPath `
            -SiteName $config.SiteName -Ports @($config.Ports)
        Write-NodeLog -Address $address -Step $step -Result 'OK' `
            -Message 'Конфигурация прочитана и проверена'

        $step = 'WSL_START'
        Start-WslDistribution -Distro $config.Distro
        Write-NodeLog -Address $address -Step $step -Result 'OK' `
            -Message "Дистрибутив $($config.Distro) запущен"

        $step = 'WSL_ADDRESS'
        $address = Get-WslAddress -Distro $config.Distro
        Write-NodeLog -Address $address -Step $step -Result 'OK' `
            -Message 'Получен актуальный IPv4-адрес WSL'

        $step = 'COMPOSE_UP'
        Start-ComposeStack -Config $config
        Write-NodeLog -Address $address -Step $step -Result 'OK' `
            -Message 'Стек поднят с наложениями pilot и wsl-node'

        $step = 'READINESS'
        Wait-NodeReady -Config $config
        Write-NodeLog -Address $address -Step $step -Result 'OK' `
            -Message '/health/ready ответил HTTP 200'

        $step = 'NODE_ACCESS'
        Update-NodeAccess -Config $config
        Write-NodeLog -Address $address -Step $step -Result 'OK' `
            -Message 'portproxy и правила брандмауэра актуальны'

        Write-NodeLog -Address $address -Step 'SUMMARY' -Result 'OK' `
            -Message 'Автозапуск узла завершён'
        exit 0
    } catch {
        $message = "Шаг $step завершился ошибкой: $($_.Exception.Message)"
        try {
            Write-NodeLog -Address $address -Step $step -Result 'FAIL' -Message $message
        } catch {
            # Event Log остаётся независимым каналом сообщения об отказе.
        }
        Write-FailureEvent -Message $message
        Write-Error $message
        exit 1
    }
}

function Show-InstallPlan {
    param([pscustomobject] $Config)

    Write-Host 'DryRun: ничего не будет изменено и wsl.exe не будет вызван.'
    Write-Host "  Задача          : $TaskName (AtLogOn, RunLevel Highest, одна копия)"
    Write-Host "  Установочный путь: $InstallRoot"
    Write-Host "  Дистрибутив     : $($Config.Distro)"
    Write-Host "  Compose-каталог : $($Config.ProjectPath)"
    Write-Host "  Compose-файлы   : docker-compose.yml + docker-compose.pilot.yml + docker-compose.wsl-node.yml"
    Write-Host "  Readiness       : Host=$($Config.SiteName), timeout=$($Config.ReadyTimeoutSeconds) с"
    Write-Host "  Порты           : $($Config.Ports -join ', ')"
    Write-Host "  Журнал          : $LogPath"
    Write-Host "  Ошибки          : ненулевой код задачи + журнал + Windows Application Event Log"
    Write-Host '  Повторная установка заменит задачу с тем же именем, а не создаст вторую.'
}

function Install-Autostart {
    param([pscustomobject] $Config)

    $sourceAccessScript = Join-Path $PSScriptRoot 'Update-KorkemNodeAccess.ps1'
    if (-not (Test-Path -LiteralPath $sourceAccessScript)) {
        throw "Не найден соседний файл '$sourceAccessScript'."
    }

    if ($DryRun) {
        Show-InstallPlan -Config $Config
        return
    }
    if (-not (Test-Administrator)) {
        throw 'Для регистрации задачи с RunLevel Highest нужны права администратора.'
    }

    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    Copy-Item -LiteralPath $PSCommandPath -Destination $InstalledScript -Force
    Copy-Item -LiteralPath $sourceAccessScript -Destination $InstalledAccessScript -Force
    $Config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8

    if (-not [Diagnostics.EventLog]::SourceExists($EventSource)) {
        New-EventLog -LogName Application -Source $EventSource
    }

    $userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $actionArguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$InstalledScript`" -RunNode"
    $action = New-ScheduledTaskAction -Execute $PowerShellExe -Argument $actionArguments
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
    $principal = New-ScheduledTaskPrincipal -UserId $userId `
        -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings `
        -Description 'Автозапуск локального узла KORKEM в WSL2' -Force | Out-Null

    Write-Host "Задача '$TaskName' установлена для пользователя $userId с RunLevel Highest."
    Write-Host "Повторная установка обновляет эту же задачу. Журнал: $LogPath"
}

function Get-UninstallPorts {
    if (Test-Path -LiteralPath $ConfigPath) {
        try {
            $saved = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            return @($saved.Ports | ForEach-Object { [int]$_ })
        } catch {
            Write-Warning "Не удалось прочитать порты из config.json; будут сняты порты по умолчанию: $($Ports -join ', ')"
        }
    }
    return @($Ports)
}

function Test-PortProxyExists {
    param([int] $Port)

    if (-not (Test-Path -LiteralPath $ProxyKey)) { return $false }
    $name = "0.0.0.0/$Port"
    $value = Get-ItemProperty -LiteralPath $ProxyKey -Name $name `
        -ErrorAction SilentlyContinue
    return ($null -ne $value)
}

function Show-UninstallPlan {
    param([int[]] $PortsToRemove)

    Write-Host 'DryRun: ничего не будет удалено и wsl.exe не будет вызван.'
    Write-Host "  Снять задачу     : $TaskName"
    Write-Host "  Снять portproxy  : 0.0.0.0:$($PortsToRemove -join ', 0.0.0.0:')"
    Write-Host "  Снять firewall   : группа '$FirewallGroup'"
    Write-Host "  Снять Event Log  : source '$EventSource'"
    Write-Host "  Удалить каталог  : $InstallRoot"
}

function Uninstall-Autostart {
    $portsToRemove = @(Get-UninstallPorts)
    if ($DryRun) {
        Show-UninstallPlan -PortsToRemove $portsToRemove
        return
    }
    if (-not (Test-Administrator)) {
        throw 'Для удаления задачи, portproxy и правил брандмауэра нужны права администратора.'
    }

    $failures = New-Object System.Collections.Generic.List[string]
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        }
        Write-Host "Задача '$TaskName' снята."
    } catch {
        $failures.Add("задача: $($_.Exception.Message)")
    }

    foreach ($port in $portsToRemove) {
        try {
            if (Test-PortProxyExists -Port $port) {
                & netsh.exe interface portproxy delete v4tov4 `
                    listenaddress=0.0.0.0 listenport=$port | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "netsh завершился с кодом $LASTEXITCODE"
                }
                Write-Host "Portproxy 0.0.0.0:$port снят."
            } else {
                Write-Host "Portproxy 0.0.0.0:$port уже отсутствует."
            }
        } catch {
            $failures.Add("portproxy $port`: $($_.Exception.Message)")
        }
    }

    try {
        Get-NetFirewallRule -Group $FirewallGroup -ErrorAction SilentlyContinue |
            Remove-NetFirewallRule -ErrorAction Stop
        Write-Host "Правила брандмауэра группы '$FirewallGroup' сняты."
    } catch {
        $failures.Add("брандмауэр: $($_.Exception.Message)")
    }

    try {
        if ([Diagnostics.EventLog]::SourceExists($EventSource)) {
            Remove-EventLog -Source $EventSource
        }
        Write-Host "Источник Event Log '$EventSource' снят."
    } catch {
        $failures.Add("Event Log: $($_.Exception.Message)")
    }

    try {
        if (Test-Path -LiteralPath $InstallRoot) {
            Remove-Item -LiteralPath $InstallRoot -Recurse -Force
        }
        Write-Host "Установочный каталог '$InstallRoot' удалён."
    } catch {
        $failures.Add("каталог установки: $($_.Exception.Message)")
    }

    if ($failures.Count -gt 0) {
        throw "Удаление завершилось с ошибками: $($failures -join '; ')"
    }
    Write-Host 'Автозапуск KORKEM полностью удалён.'
}

# ---------------------------------------------------------------------------

if ($RunNode -and ($DryRun -or $Uninstall)) {
    throw '-RunNode нельзя совмещать с -DryRun или -Uninstall.'
}

if ($RunNode) {
    Invoke-NodeStartup
    exit 0
}

if ($Uninstall) {
    Uninstall-Autostart
    exit 0
}

$resolvedProjectPath = Resolve-ProjectPath -ExplicitPath $ProjectPath
Assert-Parameters -Distro $Distro -ProjectPath $resolvedProjectPath `
    -SiteName $SiteName -Ports $Ports
$configuration = [pscustomobject]@{
    Distro = $Distro
    ProjectPath = $resolvedProjectPath
    SiteName = $SiteName
    Ports = @($Ports)
    ReadyTimeoutSeconds = $ReadyTimeoutSeconds
}
Install-Autostart -Config $configuration
