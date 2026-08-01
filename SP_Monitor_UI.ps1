Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Icon 載入邏輯 ---
function Get-AppIcon {
    $scriptDir = if ([string]::IsNullOrEmpty($PSScriptRoot)) { "." } else { $PSScriptRoot }
    $icoPath = [System.IO.Path]::Combine($scriptDir, "app.ico")

    if (Test-Path $icoPath) {
        try { return New-Object System.Drawing.Icon($icoPath) } catch {}
    }

    $appPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($appPath.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase) -and -not $appPath.Contains("powershell")) {
        try { return [System.Drawing.Icon]::ExtractAssociatedIcon($appPath) } catch {}
    }

    return [System.Drawing.SystemIcons]::Application
}

$mainIcon = Get-AppIcon

# --- 主視窗設定 ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "South Plus Status Monitor"
$form.Icon = $mainIcon
$form.Size = New-Object System.Drawing.Size(460, 470)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)

# 隱藏變數
$script:minAction = 0    
$script:closeAction = 0  
$script:cfgDebug = $false 
$script:isMonitoring = $false

# 字型庫
$fontMain  = New-Object System.Drawing.Font("Microsoft JhengHei UI", 9)
$fontBold  = New-Object System.Drawing.Font("Microsoft JhengHei UI", 9, [System.Drawing.FontStyle]::Bold)
$fontTitle = New-Object System.Drawing.Font("Microsoft JhengHei UI", 11, [System.Drawing.FontStyle]::Bold)

# --- 輕量化向量齒輪圖示 ---
function Get-GearBitmap ($size = 20) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 105, 115))
    $cx = $size / 2
    $cy = $size / 2
    for ($i = 0; $i -lt 8; $i++) {
        $state = $g.Save()
        $g.TranslateTransform($cx, $cy)
        $g.RotateTransform($i * 45)
        $g.FillRectangle($brush, -2.5, -($size / 2 - 1), 5, 4)
        $g.Restore($state)
    }
    $g.FillEllipse($brush, 3, 3, $size - 6, $size - 6)
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(248, 249, 250))
    $g.FillEllipse($bgBrush, 7, 7, $size - 14, $size - 14)
    $g.Dispose()
    return $bmp
}

# 初始化通知列圖示
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $mainIcon
$notifyIcon.Text = "South Plus Monitor"
$notifyIcon.Visible = $false

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$contextMenu.Font = $fontMain
$itemShow = $contextMenu.Items.Add("顯示主視窗")
$itemExit = $contextMenu.Items.Add("完全退出")
$notifyIcon.ContextMenuStrip = $contextMenu

function Restore-Window {
    $form.Show()
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $notifyIcon.Visible = $false
    $form.Activate()
}

function Minimize-To-Tray {
    $notifyIcon.Visible = $true
    $form.Hide()
}

$itemShow.Add_Click({ Restore-Window })
$notifyIcon.Add_DoubleClick({ Restore-Window })

$itemExit.Add_Click({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    $form.Close()
    [System.Windows.Forms.Application]::Exit()
})

# --- UI Layout ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "South Plus Status Monitor"
$lblTitle.Font = $fontTitle
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(33, 37, 41)
$lblTitle.Location = New-Object System.Drawing.Point(20, 14)
$lblTitle.AutoSize = $true
$form.Controls.Add($lblTitle)

$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Image = Get-GearBitmap 20
$btnSettings.Location = New-Object System.Drawing.Point(390, 10)
$btnSettings.Size = New-Object System.Drawing.Size(30, 30)
$btnSettings.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSettings.FlatAppearance.BorderSize = 0
$btnSettings.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(230, 233, 238)
$btnSettings.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(210, 215, 222)
$btnSettings.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSettings)

$lblUrl = New-Object System.Windows.Forms.Label
$lblUrl.Text = "Target URL"
$lblUrl.Font = $fontBold
$lblUrl.ForeColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
$lblUrl.Location = New-Object System.Drawing.Point(20, 42)
$lblUrl.AutoSize = $true
$form.Controls.Add($lblUrl)

$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Text = "https://www.south-plus.net/register.php"
$txtUrl.Font = $fontMain
$txtUrl.Location = New-Object System.Drawing.Point(20, 60)
$txtUrl.Size = New-Object System.Drawing.Size(400, 23)
$txtUrl.Enabled = $false
$form.Controls.Add($txtUrl)

$lblInterval = New-Object System.Windows.Forms.Label
$lblInterval.Text = "Sec:"
$lblInterval.Font = $fontBold
$lblInterval.ForeColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
$lblInterval.Location = New-Object System.Drawing.Point(20, 93)
$lblInterval.AutoSize = $true
$form.Controls.Add($lblInterval)

$txtInterval = New-Object System.Windows.Forms.TextBox
$txtInterval.Text = "180"
$txtInterval.Font = $fontMain
$txtInterval.Location = New-Object System.Drawing.Point(55, 90)
$txtInterval.Size = New-Object System.Drawing.Size(55, 23)
$form.Controls.Add($txtInterval)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start"
$btnStart.Font = $fontBold
$btnStart.Location = New-Object System.Drawing.Point(20, 122)
$btnStart.Size = New-Object System.Drawing.Size(195, 28)
$btnStart.FlatStyle = [System.Windows.Forms.FlatStyle]::System
$form.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Stop"
$btnStop.Font = $fontBold
$btnStop.Location = New-Object System.Drawing.Point(225, 122)
$btnStop.Size = New-Object System.Drawing.Size(195, 28)
$btnStop.FlatStyle = [System.Windows.Forms.FlatStyle]::System
$btnStop.Enabled = $false
$form.Controls.Add($btnStop)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Location = New-Object System.Drawing.Point(20, 160)
$txtLog.Size = New-Object System.Drawing.Size(400, 250)
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(30, 33, 40)
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 150)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$txtLog.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($txtLog)

# --- Curl 呼叫 ---
function Invoke-CurlHidden {
    param(
        [string]$url,
        [string]$outputPath
    )

    $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    $arguments = "-k -s -L --max-time 15 -A `"$userAgent`" $url -o `"$outputPath`""

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "curl.exe"
    $startInfo.Arguments = $arguments
    $startInfo.CreateNoWindow = $true       
    $startInfo.UseShellExecute = $false     
    $startInfo.RedirectStandardOutput = $true 
    $startInfo.RedirectStandardError = $true

    $process = $null
    try {
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        $script:lastCurlProcess = $process
        [void]$process.Start()
        
        if ($process.WaitForExit(18000)) {
            return $process.ExitCode
        } else {
            if (-not $process.HasExited) { $process.Kill() }
            return -999
        }
    }
    catch {
        return -1
    }
    finally {
        if ($process) { $process.Dispose() }
    }
}

# --- 齒輪設定表單 ---
$btnSettings.Add_Click({
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.Text = "Settings"
    $settingsForm.Icon = $mainIcon
    $settingsForm.Size = New-Object System.Drawing.Size(340, 290)
    $settingsForm.StartPosition = "CenterParent"
    $settingsForm.FormBorderStyle = "FixedDialog"
    $settingsForm.MaximizeBox = $false
    $settingsForm.MinimizeBox = $false
    $settingsForm.Font = $fontMain

    $grpMin = New-Object System.Windows.Forms.GroupBox
    $grpMin.Text = "點擊最小化 ( _ ) 時的動作"
    $grpMin.Location = New-Object System.Drawing.Point(15, 10)
    $grpMin.Size = New-Object System.Drawing.Size(295, 75)

    $radMinBar = New-Object System.Windows.Forms.RadioButton
    $radMinBar.Text = "單純縮小至工作列"
    $radMinBar.Location = New-Object System.Drawing.Point(15, 20)
    $radMinBar.Size = New-Object System.Drawing.Size(260, 22)
    $radMinBar.Checked = ($script:minAction -eq 0)

    $radMinTray = New-Object System.Windows.Forms.RadioButton
    $radMinTray.Text = "最小化至系統圖示"
    $radMinTray.Location = New-Object System.Drawing.Point(15, 45)
    $radMinTray.Size = New-Object System.Drawing.Size(260, 22)
    $radMinTray.Checked = ($script:minAction -eq 1)

    $grpMin.Controls.Add($radMinBar)
    $grpMin.Controls.Add($radMinTray)
    $settingsForm.Controls.Add($grpMin)

    $grpClose = New-Object System.Windows.Forms.GroupBox
    $grpClose.Text = "點擊關閉 ( ✕ ) 時的動作"
    $grpClose.Location = New-Object System.Drawing.Point(15, 95)
    $grpClose.Size = New-Object System.Drawing.Size(295, 75)

    $radCloseExit = New-Object System.Windows.Forms.RadioButton
    $radCloseExit.Text = "直接結束並關閉程式"
    $radCloseExit.Location = New-Object System.Drawing.Point(15, 20)
    $radCloseExit.Size = New-Object System.Drawing.Size(260, 22)
    $radCloseExit.Checked = ($script:closeAction -eq 0)

    $radCloseTray = New-Object System.Windows.Forms.RadioButton
    $radCloseTray.Text = "最小化至系統圖示"
    $radCloseTray.Location = New-Object System.Drawing.Point(15, 45)
    $radCloseTray.Size = New-Object System.Drawing.Size(260, 22)
    $radCloseTray.Checked = ($script:closeAction -eq 1)

    $grpClose.Controls.Add($radCloseExit)
    $grpClose.Controls.Add($radCloseTray)
    $settingsForm.Controls.Add($grpClose)

    $chkDbg = New-Object System.Windows.Forms.CheckBox
    $chkDbg.Text = "產生 Debug 檔 (debug_page.html)"
    $chkDbg.Location = New-Object System.Drawing.Point(15, 178)
    $chkDbg.Size = New-Object System.Drawing.Size(295, 24)
    $chkDbg.Checked = $script:cfgDebug
    $settingsForm.Controls.Add($chkDbg)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "確定"
    $btnSave.Location = New-Object System.Drawing.Point(115, 212)
    $btnSave.Size = New-Object System.Drawing.Size(90, 28)
    $settingsForm.Controls.Add($btnSave)

    $btnSave.Add_Click({
        $script:minAction = if ($radMinTray.Checked) { 1 } else { 0 }
        $script:closeAction = if ($radCloseTray.Checked) { 1 } else { 0 }
        $script:cfgDebug = $chkDbg.Checked
        $settingsForm.Close()
    })
    [void]$settingsForm.ShowDialog($form)
})

# --- 核心邏輯 ---
function Write-Log ($msg) {
    if ($form.IsHandleCreated -and -not $form.IsDisposed) {
        $time = Get-Date -Format "HH:mm:ss"
        $txtLog.AppendText("[$time] $msg`r`n")
        $txtLog.SelectionStart = $txtLog.TextLength
        $txtLog.ScrollToCaret()
    }
}

function Check-Target {
    $tmpFile = "$env:TEMP\sp_tmp_$([Guid]::NewGuid().ToString().Substring(0,8)).html"

    try {
        $url = $txtUrl.Text
        Write-Log "Checking page status..."
        
        $exitCode = Invoke-CurlHidden -url $url -outputPath $tmpFile
            
        $html = $null
        if ($exitCode -eq 0 -and (Test-Path $tmpFile)) {
            try {
                $html = [System.IO.File]::ReadAllText($tmpFile, [System.Text.Encoding]::GetEncoding("GBK"))
            } catch {}
        }

        if (-not $script:isMonitoring) { 
            if (Test-Path $tmpFile) { Remove-Item $tmpFile -ErrorAction SilentlyContinue }
            return 
        }

        if (-not [string]::IsNullOrWhiteSpace($html) -and $html.Length -ge 1000) {
            Write-Log "Received page size: $($html.Length) chars"

            if ($script:cfgDebug) {
                Copy-Item $tmpFile "debug_page.html" -Force
                Write-Log "Debug mode active: Saved HTML to debug_page.html"
            }

            $isLocked = ($html -match "1小時" -or $html -match "重複" -or $html -match "限制" -or $html -match "提示" -or $html -match "IP" -or $html -match "未開放" -or $html -match "關閉")
            $hasPositiveSign = ($html -match "同意" -or $html -match "reguser" -or $html -match "regpwd" -or $html -match "type=`"password`"" -or $html -match "submit")

            if (-not $isLocked -or $hasPositiveSign) {
                Write-Log "ALERT: OPEN!"
                try { Start-Process $url; Write-Log "Browser launched!" } catch {}

                if ($notifyIcon.Visible) { Restore-Window }
                1..5 | ForEach-Object { [Console]::Beep(1200, 250) }
                [System.Windows.Forms.MessageBox]::Show("Changed! Browser opened!", "Notice", "OK", "Information")
            } else {
                Write-Log "Locked. Waiting..."
            }
        } else {
            Write-Log "Network response empty or invalid. Retrying next cycle..."
        }
    }
    catch {
        Write-Log "ERROR occurred during check."
    }
    finally {
        if (Test-Path $tmpFile) { Remove-Item $tmpFile -ErrorAction SilentlyContinue }
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Add_Tick({ 
    if ($script:isMonitoring) { 
        Check-Target 
    } 
})

$btnStart.Add_Click({
    $script:isMonitoring = $true
    $btnStart.Enabled = $false
    $btnStop.Enabled = $true
    $txtInterval.Enabled = $false
    
    $seconds = [int]$txtInterval.Text
    if ($seconds -lt 10) { $seconds = 10 }
    $timer.Interval = $seconds * 1000
    
    Write-Log "Started! Interval: $seconds sec."
    
    Check-Target
    $timer.Start()
})

$btnStop.Add_Click({
    $script:isMonitoring = $false
    $timer.Stop()
    try { if ($script:lastCurlProcess -and -not $script:lastCurlProcess.HasExited) { $script:lastCurlProcess.Kill() } } catch {}
    
    $btnStart.Enabled = $true
    $btnStop.Enabled = $false
    $txtInterval.Enabled = $true
    Write-Log "Stopped."
})

$form.Add_SizeChanged({ if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized -and $script:minAction -eq 1) { Minimize-To-Tray } })
$form.Add_FormClosing({ param($sender, $e) if ($script:closeAction -eq 1 -and $e.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) { $e.Cancel = $true; Minimize-To-Tray } else { $notifyIcon.Visible = $false; $notifyIcon.Dispose() } })

Write-Log "System Ready. Click 'Start' to begin."
[System.Windows.Forms.Application]::Run($form)