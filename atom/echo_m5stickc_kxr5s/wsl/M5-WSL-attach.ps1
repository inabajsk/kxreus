# AtomS3 と ATOM Echo をまとめて WSL に接続する
# USB を挿し直した後に、デスクトップの「M5-WSL-attach.cmd」をダブルクリックして実行する
#   - AtomS3   : ESP32-S3 ネイティブUSB, VID:PID 303a:1001  -> WSL では /dev/ttyACM*
#   - ATOM Echo: FTDI 0403:6001, シリアル番号 4D5217E152    -> WSL では /dev/ttyUSB*
#     (M5StickC も同じ FTDI 0403:6001 なので、Echo はシリアル番号で区別する)
# 機器を追加する場合は $TARGETS に行を足す (Match は usbipd state の InstanceId に対する正規表現)。
$ErrorActionPreference = 'Stop'
$usbipd = 'C:\Program Files\usbipd-win\usbipd.exe'
$TARGETS = @(
    @{ Name = 'AtomS3';    Match = '^USB\\VID_303A&PID_1001\\' },
    @{ Name = 'ATOM Echo'; Match = '^USB\\VID_0403&PID_6001\\4D5217E152$' }
)

function Get-Devices { (& $usbipd state | ConvertFrom-Json).Devices }

try {
    if (-not (Test-Path $usbipd)) { throw "usbipd-win が見つかりません: $usbipd" }

    # 1) 見つかった機器を集める
    $found = @()
    foreach ($t in $TARGETS) {
        $d = Get-Devices | Where-Object { $_.BusId -and $_.InstanceId -match $t.Match } | Select-Object -First 1
        if ($d) {
            Write-Host ("検出: {0,-10} BUSID {1}" -f $t.Name, $d.BusId)
            $found += @{ Name = $t.Name; Match = $t.Match; BusId = $d.BusId }
        } else {
            Write-Host ("未接続: {0,-10} (USB が挿さっていません)" -f $t.Name) -ForegroundColor Yellow
        }
    }
    if ($found.Count -eq 0) { throw "AtomS3 も ATOM Echo も見つかりません。USB を確認してください。" }

    # 2) 未共有のものをまとめて bind (管理者権限の確認は1回だけ)
    $toBind = @($found | Where-Object {
        $m = $_.Match; -not ((Get-Devices | Where-Object { $_.InstanceId -match $m } | Select-Object -First 1).PersistedGuid) })
    if ($toBind.Count -gt 0) {
        Write-Host ("共有設定 (bind): {0}。管理者権限の確認が表示されます..." -f (($toBind | ForEach-Object { $_.Name }) -join ', '))
        $cmds = ($toBind | ForEach-Object { "& '$usbipd' bind --busid $($_.BusId)" }) -join '; '
        $p = Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile -Command $cmds" -Verb RunAs -Wait -PassThru
        if ($p.ExitCode -ne 0) { Write-Host "bind の終了コード $($p.ExitCode)" -ForegroundColor Red }
    }

    # 3) attach
    foreach ($f in $found) {
        $m = $f.Match
        $d = Get-Devices | Where-Object { $_.InstanceId -match $m } | Select-Object -First 1
        if ($d.ClientIPAddress) {
            Write-Host ("{0}: 既に WSL に接続済みです (BUSID {1})" -f $f.Name, $f.BusId) -ForegroundColor Green
            continue
        }
        Write-Host ("{0}: WSL に接続しています (BUSID {1})..." -f $f.Name, $f.BusId)
        & $usbipd attach --wsl --busid $f.BusId
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("{0}: 接続しました" -f $f.Name) -ForegroundColor Green
        } else {
            Write-Host ("{0}: attach に失敗しました (終了コード {1})" -f $f.Name, $LASTEXITCODE) -ForegroundColor Red
        }
    }

    Start-Sleep -Seconds 2
    Write-Host ""
    Write-Host "WSL 側のデバイス:"
    $devs = wsl.exe -e sh -c "ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null; true"
    if ($devs) { $devs | ForEach-Object { Write-Host "  $_" } }
    else { Write-Host "  /dev/ttyACM* /dev/ttyUSB* が見つかりません" -ForegroundColor Yellow }
} catch {
    Write-Host "エラー: $_" -ForegroundColor Red
}

Write-Host ""
Read-Host "Enter キーで閉じます"
