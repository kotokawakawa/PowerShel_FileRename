Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =========================================
# 設定
# =========================================
$WatchScript = "Z:\powershell_2\watch_polling_final.ps1"

# ログファイル
$LogFile = "Z:\Screenshot_2\rename.log"

# アイコン
$Icon = [System.Drawing.SystemIcons]::Information

# =========================================
# 状態管理
# =========================================
$global:WatchProcess = $null

# =========================================
# 監視開始
# =========================================
function Start-Watch {

    if ($global:WatchProcess -and -not $global:WatchProcess.HasExited) {
        return
    }

    $global:WatchProcess = Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$WatchScript`"" `
        -WindowStyle Hidden `
        -PassThru

    $notifyIcon.ShowBalloonTip(
        2000,
        "監視開始",
        "PowerShell監視を開始しました。",
        [System.Windows.Forms.ToolTipIcon]::Info
    )
}

# =========================================
# 監視停止
# =========================================
function Stop-Watch {

    if ($global:WatchProcess -and -not $global:WatchProcess.HasExited) {

        try {
            $global:WatchProcess.Kill()
        }
        catch {}

        $notifyIcon.ShowBalloonTip(
            2000,
            "監視停止",
            "PowerShell監視を停止しました。",
            [System.Windows.Forms.ToolTipIcon]::Warning
        )
    }
}

# =========================================
# NotifyIcon
# =========================================
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $Icon
$notifyIcon.Text = "Photo Rename Watch"
$notifyIcon.Visible = $true

# =========================================
# メニュー
# =========================================
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# 開始
$startItem = $contextMenu.Items.Add("監視開始")
$startItem.Add_Click({
        Start-Watch
    })

# 停止
$stopItem = $contextMenu.Items.Add("監視停止")
$stopItem.Add_Click({
        Stop-Watch
    })

$contextMenu.Items.Add("-")

# ログファイル
$openLogItem = $contextMenu.Items.Add("ログファイルを開く")
$openLogItem.Add_Click({

        if (Test-Path $LogFile) {
            Start-Process $LogFile
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                "ログファイルが存在しません。",
                "Error"
            )
        }
    })

# ログフォルダ
$openFolderItem = $contextMenu.Items.Add("ログフォルダを開く")
$openFolderItem.Add_Click({

        if (Test-Path $LogFile) {
            Start-Process (Split-Path $LogFile)
        }
    })

$contextMenu.Items.Add("-")

# watch script 編集
$editItem = $contextMenu.Items.Add("監視スクリプトを編集")
$editItem.Add_Click({

        if (Test-Path $WatchScript) {
            notepad.exe $WatchScript
        }
    })

$contextMenu.Items.Add("-")

# 終了
$exitItem = $contextMenu.Items.Add("終了")
$exitItem.Add_Click({

        Stop-Watch

        $notifyIcon.Visible = $false
        [System.Windows.Forms.Application]::Exit()
    })

$notifyIcon.ContextMenuStrip = $contextMenu

# =========================================
# 起動時自動開始
# =========================================
Start-Watch

# =========================================
# 常駐
# =========================================
[System.Windows.Forms.Application]::Run()
