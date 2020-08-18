<# Start Functions #>
function ConvertTo-ALACDirectory($folderPath, $targetDecibels = "-16", $threshold = ".25", $maxPeak = "-.25", $logPath = "$($folderPath)\ALACBalancer.log", [switch]$unluckyMode) {
    if ($env:ffmpeg) {
        Write-host -ForegroundColor Green "FFmpeg loaded."
    }
    elseif (Test-Path "C:\program files\ffmpeg\bin\ffmpeg.exe") {
        #set path to ffmpeg here
        $env:ffmpeg = "C:\program files\ffmpeg\bin\ffmpeg.exe"
        Write-Host -ForegroundColor Yellow "FFmpeg found in program files. Env set. FFmpeg loaded."
    }
    elseif (Test-Path "C:\program files (x86)\ffmpeg\bin\ffmpeg.exe") {
        $env:ffmpeg = "C:\program files (x86)\ffmpeg\bin\ffmpeg.exe"
        Write-Host -ForegroundColor Yellow "FFmpeg found in program files. Env set. FFmpeg loaded."
    }
    else {
        Write-Host -ForegroundColor Yellow "This script can not run without FFmpeg. Please install FFmpeg to C:\Program Files\FFmpeg or set your custom path to environment variable %ffmpeg%."
        Start-Sleep -Seconds 20
        exit
    }


    if ($unluckyMode) {
        New-ALACLog -logPath $logPath -message 'I''m feeling unlucky.'
    }
    if (Test-Path -LiteralPath $folderPath) {
        $files = Get-Childitem $folderPath -Recurse | Select-Object * | Where-Object { $_.extension -eq ".m4a", ".opus", ".wav", ".mp3", ".flac" } | Sort-Object -Descending
        foreach ($file in $files) {
            if ($unluckyMode) {
                ConvertTo-LeveledALAC -filePath $file.fullname -targetDecibels $targetDecibels -threshold $threshold -maxPeak $maxPeak -logPath $logPath -unluckyMode
            }
            else {
                ConvertTo-LeveledALAC -filePath $file.fullname -targetDecibels $targetDecibels -threshold $threshold -maxPeak $maxPeak -logPath $logPath
            }
        }
    }
    else { 
        New-ALACLog -logPath $logPath -message '## break in ConvertTo-ALACDirectory: $folderPath isn''t a path?'
        New-ALACLog -logPath $logPath -message '#### $folderPath contents:'
        New-ALACLog -logPath $logPath -message $folderPath
        break; 
    }
}

function ConvertTo-LeveledALAC($filePath, $targetDecibels = "-16", $threshold = ".25", $maxPeak = "-.25", $logPath = "$($filePath)`.log", [switch]$unluckyMode) {
    New-ALACLog -logPath $logPath -message "Processing file ""$($filePath)""."
    if (Test-Path -LiteralPath $filePath) {
        $Path = $filePath | Split-Path -Parent
        $dataFile = "$Path\LoudnessData.log"
        <# Feature: Volume Validation and DR Info
        $rangeLog = "$Path\DR_log.txt"
        $rangeLock = $false
        #>
    }
    else { 
        New-ALACLog -logPath $logPath -message '## Break in ConvertTo-LeveledALAC: $filePath seems to be jacked'
        New-ALACLog -logPath $logPath -message '#### $filePath contents:'
        New-ALACLog -logPath $logPath -message $filePath
        break; 
    }
    New-ALACLog -logPath $logPath -message "Reading loudness data."
    $data = Get-LoudnessData -filePath $filePath -dataFile $dataFile -logPath $logPath
    New-ALACLog -logPath $logPath -message "Average Volume: $($data.input_i)dB. True Peak: $($data.input_tp)dB."
    if ($data) {
        New-ALACLog -logPath $logPath -message "Calculating volume adjustment."
        New-ALACLog -logPath $logPath -message "Target volume: $($targetDecibels)dB (plus or minus $($threshold)dB). True Peak limited to $($maxPeak)`dB."
        $volAdjust = $targetDecibels - $($data.input_i)
        New-ALACLog -logPath $logPath -message "Adjustment: $($targetDecibels)dB - $($data.input_i)dB = $($volAdjust)dB. Seeing if there's $($maxPeak)`dB for the True Peak."
        if (($volAdjust -gt 0) -and ($volAdjust + $data.input_tp -gt $maxPeak)) {
            $volAdjust = $maxPeak - $data.input_tp
            New-ALACLog -logPath $logPath -message "True Peak is high (good dynamic range). Adjustment reduced to $($volAdjust)dB."
        }
        else { 
            New-ALACLog -logPath $logPath -message 'Plenty of space on the other side of that peak...trust me. Rabbit is good, Rabbit is wise.'
        }
        if ([math]::abs($volAdjust) -gt [math]::abs($threshold)) {
            if ($unluckyMode) {
                New-ALACLog -logPath $logPath -message "Feeling lucky, punk? Adjusting volume of ""$($filePath)"" by $($volAdjust)dB to target average of $($targetDecibels)`dB without leaving a backup."
                New-LeveledALAC -filePath $filePath -volAdjust $volAdjust -logPath $logPath -dataFile $dataFile
                $data.input_i = $data.input_i + $volAdjust
                $data.input_tp = $data.input_tp + $volAdjust
            }
            else {
                New-ALACLog -logPath $logPath -message "Adjusting volume of ""$($filePath)"" by $($volAdjust)dB to target average of $($targetDecibels)`dB, and leaving a backup."
                New-LeveledALAC -filePath $filePath -volAdjust $volAdjust -logPath $logPath -dataFile $dataFile -unluckyMode
                $data.input_i = $data.input_i + $volAdjust
                $data.input_tp = $data.input_tp + $volAdjust
            }
        }
        else {
            New-ALACLog -logPath $logPath -message "$($filePath) is already within the threshold. Cleaning up and moving on!"
            if ($logPath -eq "$filePath`.log") {
                Write-Host -ForegroundColor Green "$($filePath) is already within the threshold. Cleaning up!"
                Remove-Item "$filePath`.log" -Force -Confirm:$false
                Remove-Item $dataFile -Force -Confirm:$false
            }
            else { 
                Remove-Item $dataFile -Force -Confirm:$false
            }
        }
    }
    else { 
        New-ALACLog -logPath $logPath -message '## Break in ConvertTo-LeveledALAC: $data missing'
        New-ALACLog -logPath $logPath -message '#### $data contents:'
        New-ALACLog -logPath $logPath -message $data
        break; 
    }
}

function Get-LoudnessData($filePath, $dataFile = "$($filePath)`.data.log", $logPath = "$($filePath)`.log") {
    #if($filePath -like '*`[*'){ 'true' }
    if (Test-Path -LiteralPath $filePath) {
        $arg1 = ' -i "{0}" -af loudnorm=I=-15:TP=-1.0:LRA=1:print_format=json -f null -' -f $filePath
        Start-Process -FilePath $env:ffmpeg -ArgumentList $arg1 -RedirectStandardError $dataFile -NoNewWindow -Wait
    }
    else { 
        New-ALACLog -logPath $logPath -message '## Break in Get-LoudnessData: What is $filePath?'
        New-ALACLog -logPath $logPath -message '#### $filePath contents:'
        New-ALACLog -logPath $logPath -message $filePath
        break; 
    }
    $data = Compare-LoudnessData -dataFile $dataFile
    return $data
}

function Compare-LoudnessData($dataFile, $logPath = "$($dataFile)`.log") {
    if (Test-Path -LiteralPath $dataFile) {
        $rawData = Get-Content -Path $dataFile -Tail 12;
        $data = @{
            input_i            = $rawData[-11].split('"')[3];
            input_tp           = $rawData[-10].split('"')[3];
            input_lra          = $rawData[-9].split('"')[3];
            input_thresh       = $rawData[-8].split('"')[3];
            output_i           = $rawData[-7].split('"')[3];
            output_tp          = $rawData[-6].split('"')[3];
            output_lra         = $rawData[-5].split('"')[3];
            output_thresh      = $rawData[-4].split('"')[3];
            normalization_type = $rawData[-3].split('"')[3];
            target_offset      = $rawData[-2].split('"')[3];
            DR                 = $data.input_tp - $data.input_i
        }
    }
    else { 
        New-ALACLog -logPath $logPath -message '## Break in Compare-LoudnessData: $dataFile doesn''t exist.'
        New-ALACLog -logPath $logPath -message '#### $dataFile contents:'
        New-ALACLog -logPath $logPath -message $dataFile
        break; 
    }
    Return $data
}

function New-LeveledALAC($filePath, $volAdjust, $dataFile, $logPath = "$($filePath)`.log", [switch]$unluckyMode) {
    if (!($filePath)) {
        New-ALACLog -logPath $logPath -message '## Break in New-LeveledALAC: $filePath is jacked.'
        New-ALACLog -logPath $logPath -message '#### $filePath contents:'
        New-ALACLog -logPath $logPath -message $filePath
        break;
    }
    if (!($volAdjust)) {
        New-ALACLog -logPath $logPath -message '## Break in New-LeveledALAC: $volAdjust is jacked.'
        New-ALACLog -logPath $logPath -message '#### $volAdjust contents:'
        New-ALACLog -logPath $logPath -message $volAdjust
        break;
    }
    if (!($dataFile)) {
        New-ALACLog -logPath $logPath -message '## Break in New-LeveledALAC: $dataFile is jacked.'
        New-ALACLog -logPath $logPath -message '#### $dataFile contents:'
        New-ALACLog -logPath $logPath -message $dataFile
        break;
    }
    $tempPath = "$($filePath | Split-Path -Parent)\temp_$($filePath | split-path -leaf)"
    $newPath = "$($filePath | Split-Path -Parent)\$([io.path]::GetFileNameWithoutExtension($filePath))`.m4a"
    New-ALACLog -logPath $logPath -message "Creating temp copy of ""$filePath"""
    Move-Item -LiteralPath $filePath -Destination $tempPath -Force
    $arg2 = ' -i "{0}" -filter:a "volume={1}dB" -c:v copy -map_metadata:s:a 0:s:a -acodec alac -ar 44100 -sample_fmt s16p "{2}"' -f $tempPath, $volAdjust, $newPath
    Start-Process -FilePath $env:ffmpeg -ArgumentList $arg2 -RedirectStandardError $dataFile -NoNewWindow -Wait
    if ($unluckyMode) {
        Remove-Item -LiteralPath $logPath -Confirm:$false
        Remove-Item -LiteralPath $tempPath -Confirm:$false
        Remove-Item -LiteralPath $dataFile -Confirm:$false
    } 
    else {
        if ((Get-ItemProperty $newPath).length -gt 0) {
            New-ALACLog -logPath $logPath -message "Good news. ""$newPath"" isn't null. Feel free to delete ""$tempPath""."
            Remove-Item -LiteralPath $dataFile -Confirm:$false
        }
    }
}

function New-ALACLog($logPath, $message) {
    '' | Out-File -LiteralPath $logPath -Encoding ascii -Append 
    $message | Out-File -LiteralPath $logPath -Encoding ascii -Append
}
<# End Functions #>
