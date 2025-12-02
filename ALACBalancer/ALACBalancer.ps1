<# Start Functions #>
function ConvertTo-ALACDirectory($folderPath, $targetDecibels = "-18", $threshold = ".25", $maxPeak = "-.01", $logPath = "$($folderPath)\ALACBalancer.log", [switch]$unluckyMode) {
    New-ALACLog -logPath $logPath -message "# Checking FFMpeg in ConvertTo-ALACDirectory"
    if ($env:ffmpeg) {
        Write-host -ForegroundColor Green "FFmpeg loaded."
    }
    elseif (Test-Path "C:\programdata\Chocolatey\bin\ffmpeg.exe") {
        #set path to ffmpeg here
        $env:ffmpeg = "C:\programdata\Chocolatey\bin\ffmpeg.exe"
        Write-Host -ForegroundColor Yellow "FFmpeg found in Chocolatey binaries. Env set. FFmpeg loaded."
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
        New-ALACLog -logPath $logPath -message "While unlucky mode is less dangerous, do remember to clean out the temp folder: ""$($env:LOCALAPPDATA)`\Temp\ConvertTo-LeveledALAC""."
        New-ALACLog -logPath $logPath -message "I'm about to leave a shit-load of files in there..."
    }

    New-ALACLog -logPath $logPath -message "# Moving to Main ConvertTo-ALACDirectory loop"

    # Main ConvertTo-ALACDirectory loop
    if (Test-Path -LiteralPath $folderPath) {
        New-ALACLog -logPath $logPath -message '# Main ConvertTo-ALACDirectory loop'
        $files = Get-Childitem $folderPath -Recurse | Select-Object * | Where-Object { $_.extension -in ".m4a", ".opus", ".wav", ".mp3", ".flac" }
        
        if ($files) {
            New-ALACLog -logPath $logPath -message ">>Files found:" 
            foreach($file in $files){
                New-ALACLog -logPath $logPath -message "    $($file.fullname)"
            }
            
        }
        else {
            New-ALACLog -logPath $logPath -message "I find your lack of files disturbing"
        }

        foreach ($file in $files) {
            if ($unluckyMode) {
                New-ALACLog -logPath $logPath -message "ConvertTo-LeveledALAC -filePath $($file.fullname) -targetDecibels $targetDecibels -threshold $threshold -maxPeak $maxPeak -logPath $logPath -unluckyMode"
                Write-Host -ForegroundColor Yellow "ConvertTo-LeveledALAC $($file.fullname | split-path -Leaf) -unluckyMode"
                ConvertTo-LeveledALAC -filePath $file.fullname -targetDecibels $targetDecibels -threshold $threshold -maxPeak $maxPeak -logPath $logPath -unluckyMode
                }
            else {
                New-ALACLog -logPath $logPath -message "ConvertTo-LeveledALAC -filePath $($file.fullname) -targetDecibels $targetDecibels -threshold $threshold -maxPeak $maxPeak -logPath $logPath"
                Write-Host -ForegroundColor Yellow "ConvertTo-LeveledALAC $($file.fullname | split-path -Leaf)"
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

function ConvertTo-LeveledALAC($filePath, $targetDecibels = "-18", $threshold = ".25", $maxPeak = "-.01", $logPath = "$($filePath)`.log", [switch]$unluckyMode) {
    $tempFile = "$($env:LOCALAPPDATA)`\Temp\ConvertTo-LeveledALAC\$($filePath | Split-Path -Leaf)"
    New-ALACLog -logPath $logPath -message "Processing file ""$($filePath)""."
    if (Test-Path -LiteralPath $filePath -ErrorAction SilentlyContinue) {
        New-Item -Path "$($env:LOCALAPPDATA)`\Temp" -Name ConvertTo-LeveledALAC -ItemType Directory -Force -ErrorAction SilentlyContinue
        Copy-Item -LiteralPath $filePath -Destination $tempFile -Force -Confirm:$false -ErrorAction SilentlyContinue
        $Path = $tempFile | Split-Path -Parent
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
    $data = Get-LoudnessData -filePath $tempFile -logPath $logPath

    New-ALACLog -logPath $logPath -message "Average Volume: $($data.input_i)dB. True Peak: $($data.input_tp)dB."
    if ($data) {
        New-ALACLog -logPath $logPath -message "Calculating volume adjustment."
        New-ALACLog -logPath $logPath -message "Target volume: $($targetDecibels)dB (plus or minus $($threshold)dB). True Peak limited to $($maxPeak)`dB."
        $volAdjust = $targetDecibels - $($data.input_i)
        New-ALACLog -logPath $logPath -message "Adjustment: $($targetDecibels)dB - $($data.input_i)dB = $($volAdjust)dB. Seeing if there's $($maxPeak)`dB for the True Peak."
        if (($volAdjust -gt 0) -and ($volAdjust + $data.input_tp -gt $maxPeak)) {
            $volAdjust = $maxPeak - $data.input_tp
            New-ALACLog -logPath $logPath -message "True Peak is $($data.input_tp). Adjustment reduced to $($volAdjust)dB."
        } 
        else { 
            New-ALACLog -logPath $logPath -message 'Plenty of space on the other side of that peak...trust me. Rabbit is good, Rabbit is wise.'
        }
        if (([math]::abs($volAdjust) -gt [math]::abs($threshold)) -or (!([io.path]::GetExtension($filePath) -in '.m4a'))) {
            if ($data.input_tp -gt -40){
                New-ALACLog -logPath $logPath -message "This looks fine; True Peak ($data.input_tp) isn't absolute silence."
                if ($unluckyMode) {
                    New-ALACLog -logPath $logPath -message "Adjusting volume of ""$($filePath)"" by $($volAdjust)dB to target average of $($targetDecibels)`dB, and leaving a backup."
                    Write-Host -ForegroundColor DarkGreen "Adjusting " -NoNewline
                    Write-Host -ForegroundColor Green "$($filePath | Split-Path -Leaf) " -NoNewline
                    Write-Host -ForegroundColor DarkGreen "by $($volAdjust)dB in unluckyMode"
                    $newFile = New-LeveledALAC -filePath $tempFile -volAdjust $volAdjust -logPath $logPath -unluckyMode
                    $data.input_i = $data.input_i + $volAdjust
                    $data.input_tp = $data.input_tp + $volAdjust
                    $backupPath = "$($filePath | Split-Path -Parent)\(backup) $($filePath | Split-Path -Leaf)"
                    Move-Item -LiteralPath $filePath -Destination $backupPath -Force -Confirm:$false
                    Copy-Item -LiteralPath $newFile -Destination $filePath -Force -Confirm:$false
                }
                else {
                    New-ALACLog -logPath $logPath -message "Feeling lucky, punk? Adjusting volume of ""$($filePath)"" by $($volAdjust)dB to target average of $($targetDecibels)`dB without leaving a backup."
                    Write-Host -ForegroundColor DarkGreen "Adjusting " -NoNewline
                    Write-Host -ForegroundColor Green "$($filePath | Split-Path -Leaf) " -NoNewline
                    Write-Host -ForegroundColor DarkGreen "by $($volAdjust)dB."
                    $newFile = New-LeveledALAC -filePath $tempFile -volAdjust $volAdjust -logPath $logPath
                    # $data.input_i = -10.19
                    $data.input_i = $data.input_i + $volAdjust
                    # $data.input_tp = 0.50
                    $data.input_tp = $data.input_tp + $volAdjust
                    Remove-Item -LiteralPath $filePath -Force -Confirm:$false
                    Move-Item -LiteralPath $newFile -Destination $filePath -Force -Confirm:$false
                }
            } else {
                New-ALACLog -logPath $logPath -message "I'm skipping $($filePath | split-path -Leaf). It's not me, it's you! $($filePath | split-path -Leaf) has a true peak of $($data.input_tp). You can't even hear it."
                Write-Host -ForegroundColor DarkYellow "Skipping silent file: " -NoNewline
                Write-Host -ForegroundColor Yellow " $($filePath | Split-Path -Leaf) " -NoNewline
                Write-Host -ForegroundColor DarkYellow ": (TP = $($data.input_tp)db)"
                Remove-Item -LiteralPath $tempFile -Force -Confirm:$false -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath "$tempFile`.log" -Force -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        else {
            New-ALACLog -logPath $logPath -message "$($filePath) is already within the threshold. Cleaning up and moving on!"
            Write-Host -ForegroundColor DarkYellow "Skipping " -NoNewline
            Write-Host -ForegroundColor Yellow "$($filePath)" -NoNewline
            Write-Host -ForegroundColor DarkYellow ": it's already everything it needs to be!"
            Remove-Item -LiteralPath $tempFile -Force -Confirm:$false -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$tempFile`.log" -Force -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
    else { 
        New-ALACLog -logPath $logPath -message '## Break in ConvertTo-LeveledALAC: $data missing'
        New-ALACLog -logPath $logPath -message '#### $data contents:'
        New-ALACLog -logPath $logPath -message $data
        Write-Host -ForegroundColor DarkRed '## Break in ConvertTo-LeveledALAC: $data missing'
        Write-Host -ForegroundColor DarkRed '#### $data contents:'
        Write-Host -ForegroundColor Red "$data"
        break; 
    }
}

function Get-LoudnessData($filePath, $logPath = "$($filePath)`.log") {
    if (Test-Path -LiteralPath $filePath) {
        # Capture stderr output directly using proper argument array
        $stderr = & $env:ffmpeg -i "$filePath" -af "loudnorm=I=-18:TP=-.01:LRA=1:print_format=json" -f null - 2>&1
        $data = Compare-LoudnessData -rawOutput $stderr -logPath $logPath
        return $data
    }
    else { 
        New-ALACLog -logPath $logPath -message '## Break in Get-LoudnessData: What is $filePath?'
        break; 
    }
}

function Compare-LoudnessData($rawOutput, $logPath) {
    # Find and extract JSON from the captured output
    $jsonMatch = [regex]::Match($rawOutput, '\{\s*"input_i"[\s\S]*?"target_offset"\s*:\s*"[^"]*"\s*\}')
    
    if ($jsonMatch.Success) {
        try {
            $jsonData = $jsonMatch.Value | ConvertFrom-Json
            
            $data = @{}
            [double]$data.input_i = [double]$jsonData.input_i
            [double]$data.input_tp = [double]$jsonData.input_tp
            [double]$data.input_lra = [double]$jsonData.input_lra
            [double]$data.input_thresh = [double]$jsonData.input_thresh
            [double]$data.output_i = [double]$jsonData.output_i
            [double]$data.output_tp = [double]$jsonData.output_tp
            [double]$data.output_lra = [double]$jsonData.output_lra
            [double]$data.output_thresh = [double]$jsonData.output_thresh
            $data.normalization_type = $jsonData.normalization_type
            [double]$data.target_offset = [double]$jsonData.target_offset
            [double]$data.DR = $data.input_tp - $data.input_i
            
            return $data
        }
        catch {
            New-ALACLog -logPath $logPath -message "Failed to parse JSON: $_"
            break;
        }
    }
    else {
        New-ALACLog -logPath $logPath -message "No JSON found in ffmpeg output"
        break;
    }
}

function New-LeveledALAC($filePath, $volAdjust, $logPath = "$($filePath)`.log", [switch]$unluckyMode) {
    if ($null -eq $filePath) {
        New-ALACLog -logPath $logPath -message '## Break in New-LeveledALAC: $filePath is jacked.'
        New-ALACLog -logPath $logPath -message '#### $filePath contents:'
        New-ALACLog -logPath $logPath -message $filePath
        break;
    }
    if ($null -eq $volAdjust) {
        New-ALACLog -logPath $logPath -message '## Break in New-LeveledALAC: $volAdjust is jacked.'
        New-ALACLog -logPath $logPath -message '#### $volAdjust contents:'
        New-ALACLog -logPath $logPath -message $volAdjust
        break;
    }
    $tempPath = "$($filePath | Split-Path -Parent)\temp_$($filePath | split-path -leaf)"
    $newPath = "$($filePath | Split-Path -Parent)\$([io.path]::GetFileNameWithoutExtension($filePath))`.m4a"
    New-ALACLog -logPath $logPath -message "Creating temp copy of ""$filePath"""
    Move-Item -LiteralPath $filePath -Destination $tempPath -Force
    $arg2 = ' -i "{0}" -filter:a "volume={1}dB" -c:v copy -map_metadata:s:a 0:s:a -acodec alac -ar 44100 -sample_fmt s16p "{2}"' -f $tempPath, $volAdjust, $newPath
    Start-Process -FilePath $env:ffmpeg -ArgumentList $arg2 -NoNewWindow -Wait
    if (!($unluckyMode)) {
        # Remove-Item -LiteralPath $logPath -Confirm:$false
        Remove-Item -LiteralPath $tempPath -Confirm:$false
        # Remove-Item -LiteralPath $dataFile -Confirm:$false
    } 
    else {
        if ((Get-ItemProperty $newPath).length -gt 0) {
            New-ALACLog -logPath $logPath -message "Good news. ""$newPath"" isn't null. Feel free to delete ""$tempPath""."
            # Remove-Item -LiteralPath $dataFile -Confirm:$false
        }
    }
    return $newPath
}

function New-ALACLog($logPath, $message) {
    '' | Out-File -LiteralPath $logPath -Encoding ascii -Append 
    $message | Out-File -LiteralPath $logPath -Encoding ascii -Append
}
<# End Functions #>

<# Recent fixes 

Line 120: I goofed. I had the script move the new ALAC file back to the original location as the original file name, including the wrong extension.

Line 103: Speaking of wrong extensions, I also had the script process the file to ALAC if the file doesn't have the .m4a extension.

#>