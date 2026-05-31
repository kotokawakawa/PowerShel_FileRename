# =========================================
# 自動監視モード（watch_polling_final.ps1）
# =========================================

# --- 設定 ---
$watchPath = "Z:\Screenshot_2"
$suffix = "検証用"
$ExifTool = "C:\Tools\exiftool.exe"
$UseExifDate = $true
$logFile = Join-Path $watchPath "rename.log"
$extPattern = '^(jpg|jpeg|png|heic|mov|mp4|avi|mkv|mp3|wav|flac|m4a|webm|jxr|arw|dng|tif|tiff|dng|m4v|webp|gif|aae|pdf)$'
$donePattern = '^\d{8}_\d{3}_\d{4}'
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)
$global:seqMap = @{}

# --- 関数1：ログ ---
function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ONCE] $Message"
    Write-Host $line
    $sw = New-Object System.IO.StreamWriter($logFile, $true, $Utf8Bom)
    $sw.WriteLine($line)
    $sw.Close()
}

# --- 関数2：完了待ち ---
function Wait-FileComplete {
    param([string]$Path)
    $last = -1
    while ($true) {
        Start-Sleep -Milliseconds 500
        try {
            $f = Get-Item $Path -ErrorAction Stop
            if ($f.Length -eq $last) { return $true }
            $last = $f.Length
        }
        catch { return $false }
    }
}

# --- 関数3：日時取得 ---
# 修正版：Get-BaseDateTime 関数（異常値フィルター付き）
function Get-BaseDateTime {
    param($File)

    if ($UseExifDate) {
        $targetTags = @(
            "DateTimeOriginal", 
            "CreateDate", 
            "MediaCreateDate", 
            "ModifyDate",
            "DateTimeDigitized",
            "FileModifyDate"
        )

        foreach ($tagName in $targetTags) {
            try {
                # 【改良】 -charset filename=utf8 を追加して文字コード問題を回避
                $dtStr = & $ExifTool -charset filename=utf8 -s -s -s -"$tagName" $File.FullName 2>$null
                
                if ($dtStr -and $dtStr.Trim() -ne "") {
                    $cleanStr = ($dtStr -replace '[^0-9 :]', '').Trim()
                    
                    if ($cleanStr.Length -ge 19) {
                        $rawDate = $cleanStr.Substring(0, 10)
                        $rawTime = $cleanStr.Substring(10, 9)
                        $fixedDate = $rawDate -replace ':', '/'
                        $finalStr = $fixedDate + $rawTime
                        
                        $dt = [datetime]$finalStr

                        # 【新機能】日付が1980年以前（初期値ゴミデータ）なら無視して次を探す
                        if ($dt.Year -le 1980) {
                            continue
                        }

                        return @{
                            Date   = $dt
                            Source = $tagName
                        }
                    }
                }
            }
            catch { continue }
        }
    }

    # --- 関数4：単体処理（同名回避ロジックを強化） ---
    function Invoke-ProcessFile {
        param($File)

        $ext = $File.Extension.TrimStart('.').ToLower()
        if ($ext -notmatch $extPattern) { return }
    
        # 【二重処理防止ロジック】ここが判定箇所です
        # すでに「日付_連番_時間」の形式になっているものはスキップします
        if ($File.Name -match $donePattern) { return }
    
        if (-not (Wait-FileComplete $File.FullName)) { return }

        $File = Get-Item $File.FullName -ErrorAction SilentlyContinue
        if (-not $File) { return }

        $info = Get-BaseDateTime $File
        if (-not $info) { return }

        $date = $info.Date.ToString("yyyyMMdd")
        $time = $info.Date.ToString("HHmm")
        $key = "$date.$ext"

        # 日付別連番の管理
        if (-not $global:seqMap.ContainsKey($key)) { $global:seqMap[$key] = 1 }

        # --- 【改良ポイント】空き番号が見つかるまでループする ---
        $appliedSuffix = ""
        if ($suffix -and $suffix.Trim() -ne "") { $appliedSuffix = "_${suffix}_" }

        while ($true) {
            $seq = "{0:D3}" -f $global:seqMap[$key]
            $newName = "${date}_${seq}_${time}${appliedSuffix}.$ext"
            $newPath = Join-Path $File.DirectoryName $newName

            if (-not (Test-Path $newPath)) {
                # 空き番号が見つかったらループを抜けてリネームへ
                break
            }
        
            # すでにファイルが存在していたら、連番を増やして再試行
            $global:seqMap[$key]++
        }
        # ------------------------------------------------------

        try {
            Rename-Item $File.FullName $newPath -ErrorAction Stop
        
            # 次のファイルのために連番を一つ進めておく
            $global:seqMap[$key]++
        
            Write-Log ("Renamed: {0} → {1} (Source={2})" -f $File.Name, $newName, $info.Source)
        }
        catch {
            Write-Log ("Error renaming {0}: {1}" -f $File.Name, $_.Exception.Message)
        }
    }

    # =========================================
    # 実行メイン（単発リネーム）
    # =========================================
    Write-Host "--- ONCE MODE: Processing started ---" -ForegroundColor Cyan

    $files = Get-ChildItem $watchPath -File -Recurse | Sort-Object CreationTime

    if ($files.Count -eq 0) {
        Write-Host "No files to process."
    }
    else {
        foreach ($f in $files) {
            Invoke-ProcessFile -File $f
        }
    }

    Write-Host "--- ONCE MODE: Finished ---" -ForegroundColor Green
    Start-Sleep -Seconds 5
}    
