<#
.SYNOPSIS
    Делает узел KORKEM, живущий в WSL2, видимым с планшетов и телефонов в сети цеха.

.DESCRIPTION
    Узел работает в WSL2 (ADR-0024). У виртуальной машины WSL свой NAT-адрес, и
    он МЕНЯЕТСЯ при каждой перезагрузке Windows. Поэтому цепочка

        планшет → <адрес Windows в сети цеха>:8000
                → netsh portproxy
                → <адрес WSL>:8000
                → контейнер стенда

    разрывается на втором переходе всякий раз, когда компьютер перезагрузили:
    правило проброса осталось со старым адресом и указывает в пустоту. Снаружи
    это выглядит как «приложение не видит сервер», то есть как ошибка
    приложения. Скрипт устраняет это, и он же должен запускаться при входе в
    систему — см. Install-KorkemNodeAutostart.ps1.

    ЗАМЕРЕНО 2026-09-01, а не предположено:
      • с самого компьютера http://localhost:8000 отвечает 200 — тот, кто
        ставит систему, видит рабочую систему;
      • с адреса в сети цеха соединение не устанавливается вообще;
      • на порту 8000 в Windows не слушает никто.

    ВАЖНО. Одного проброса мало. Стенд по умолчанию слушает 127.0.0.1 внутри
    WSL, и тогда проброс настроен правильно и всё равно указывает в пустоту.
    Узел обязан быть поднят с наложением docker-compose.wsl-node.yml. Скрипт
    это проверяет и отказывается молча «починить» то, что не починено.

.NOTES
    ЗАПУСКАТЬ ИЗ WINDOWS, а не из оболочки внутри WSL.

    Скрипт вызывает `wsl.exe`. Если сам PowerShell был запущен изнутри WSL,
    этот вызов вложенный, и мост interop зависает целиком:

        WSL ERROR: UtilAcceptVsock:273: accept4 failed 110

    После этого перестают работать вообще все обращения к Windows из этой
    сессии WSL, пока она не будет пересоздана. Проверено на себе 2026-09-01.
    Контейнерам это не вредит — стенд продолжает отвечать, — но проверить
    скрипт становится нечем.

.PARAMETER Distro
    Имя дистрибутива WSL. По умолчанию Ubuntu.

.PARAMETER Ports
    Пробрасываемые порты. 8000 — веб и API, 9000 — socket.io, без которого
    ассистент подключается и молчит.

.PARAMETER DryRun
    Показать, что было бы сделано, и ничего не менять. Работает без прав
    администратора.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Update-KorkemNodeAccess.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File .\Update-KorkemNodeAccess.ps1
#>

[CmdletBinding()]
param(
    [string]   $Distro = 'Ubuntu',
    [int[]]    $Ports  = @(8000, 9000),
    [switch]   $DryRun
)

$ErrorActionPreference = 'Stop'
$FirewallGroup = 'KORKEM Node'
# Локаль-независимое место, где Windows на самом деле хранит проброс. Разбирать
# вывод `netsh ... show` нельзя: его заголовки переведены, и на русской Windows
# любой разбор по словам развалится.
$ProxyKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\PortProxy\v4tov4\tcp'

function Test-Administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WslAddress {
    param([string] $Distro)

    # `hostname -I` отдаёт адреса через пробел; первый — eth0.
    $raw = & wsl.exe -d $Distro -- hostname -I 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
        throw "Не удалось получить адрес WSL у дистрибутива '$Distro'. Он запущен? Проверьте: wsl -l -v"
    }

    $address = ($raw -split '\s+' | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
    if (-not $address) {
        throw "Дистрибутив '$Distro' не вернул адрес IPv4. Получено: '$raw'"
    }
    return $address
}

function Get-ExistingProxy {
    param([int] $Port)

    if (-not (Test-Path $ProxyKey)) { return $null }
    $name = "0.0.0.0/$Port"
    $item = Get-ItemProperty -Path $ProxyKey -Name $name -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    # Данные хранятся как "<адрес>/<порт>".
    return ($item.$name -split '/')[0]
}

function Test-NodeListening {
    param([string] $Distro, [string] $Address, [int] $Port)

    # Проверяем не «слушает ли кто-то», а «слушает ли он на адресе, куда будет
    # указывать проброс». Это и есть та ошибка, ради которой проверка написана.
    $probe = & wsl.exe -d $Distro -- sh -lc "timeout 5 curl -s -o /dev/null -w '%{http_code}' http://${Address}:${Port}/api/method/ping || true" 2>$null
    return ($probe -match '^\d{3}$' -and $probe -ne '000')
}

# ---------------------------------------------------------------------------

$wslAddress = Get-WslAddress -Distro $Distro
Write-Host "Адрес WSL: $wslAddress"

$changes = New-Object System.Collections.Generic.List[string]

foreach ($port in $Ports) {
    $current = Get-ExistingProxy -Port $port

    if ($current -eq $wslAddress) {
        Write-Host "  порт $port : проброс уже верен ($current)"
        continue
    }

    if ($null -eq $current) {
        $changes.Add("порт $port : проброса нет, будет создан → $wslAddress")
    } else {
        # Ровно тот случай, ради которого всё это написано.
        $changes.Add("порт $port : проброс устарел ($current), будет заменён → $wslAddress")
    }
}

# Слушает ли узел там, куда будет указывать проброс. Без этого можно настроить
# безупречный проброс в пустоту и считать работу сделанной.
$webPort = $Ports[0]
if (-not (Test-NodeListening -Distro $Distro -Address $wslAddress -Port $webPort)) {
    Write-Warning @"
Узел не отвечает по адресу ${wslAddress}:${webPort}.

Скорее всего он поднят без наложения для WSL и слушает только 127.0.0.1.
Тогда проброс будет настроен правильно и всё равно не заработает.

Поднимите узел так:

    docker compose -f docker-compose.yml -f docker-compose.pilot.yml \
                   -f docker-compose.wsl-node.yml up -d

Проброс не настраивается, пока это не исправлено.
"@
    exit 2
}
Write-Host "Узел отвечает по ${wslAddress}:${webPort} — есть куда пробрасывать."

if ($changes.Count -eq 0) {
    Write-Host "Менять нечего. Всё уже настроено."
    exit 0
}

Write-Host ""
Write-Host "Будет сделано:"
$changes | ForEach-Object { Write-Host "  $_" }

if ($DryRun) {
    Write-Host ""
    Write-Host "DryRun: ничего не изменено."
    exit 0
}

if (-not (Test-Administrator)) {
    Write-Error @"
Нужны права администратора: netsh portproxy и правила брандмауэра пишутся только с ними.

Запустите PowerShell от имени администратора и повторите. Проверить, что
скрипт собирается сделать, можно и без прав:

    powershell -ExecutionPolicy Bypass -File .\Update-KorkemNodeAccess.ps1 -DryRun
"@
    exit 1
}

foreach ($port in $Ports) {
    $current = Get-ExistingProxy -Port $port
    if ($current -eq $wslAddress) { continue }

    if ($null -ne $current) {
        & netsh.exe interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=$port | Out-Null
    }
    & netsh.exe interface portproxy add v4tov4 `
        listenaddress=0.0.0.0 listenport=$port `
        connectaddress=$wslAddress connectport=$port | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "netsh не смог создать проброс для порта $port" }

    $ruleName = "$FirewallGroup — порт $port"
    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $ruleName -Group $FirewallGroup `
            -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port `
            -Profile Private,Domain | Out-Null
    }
    Write-Host "  порт $port : готово"
}

# Правило брандмауэра намеренно только для Private и Domain. Публичная сеть —
# это кафе и аэропорт; узел там виден быть не должен. Если сеть цеха помечена
# в Windows как «Общедоступная», это надо исправить в настройках сети, а не
# ослаблять правило.

Write-Host ""
Write-Host "Проверка после изменения:"
foreach ($port in $Ports) {
    $after = Get-ExistingProxy -Port $port
    $mark  = if ($after -eq $wslAddress) { 'OK' } else { 'НЕ ПРИМЕНИЛОСЬ' }
    Write-Host "  порт $port → $after  [$mark]"
    if ($after -ne $wslAddress) { exit 1 }
}
