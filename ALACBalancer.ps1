<# Start Functions #>
function Process-ALACDirectory($folderPath,$targetDecibels="-15",$threshold="1",$logPath="$($folderPath)\ALACBalancer.log",[switch]$unluckyMode){
    if($env:ffmpeg){
        Write-host -ForegroundColor Green "FFmpeg loaded."
    } elseif (Test-Path "C:\program files\ffmpeg\bin\ffmpeg.exe") {
        #set path to ffmpeg here
        $env:ffmpeg = "C:\program files\ffmpeg\bin\ffmpeg.exe"
        Write-Host -ForegroundColor Yellow "FFmpeg found in program files. Env set. FFmpeg loaded."
    } elseif (Test-Path "C:\program files (x86)\ffmpeg\bin\ffmpeg.exe"){
        $env:ffmpeg = "C:\program files (x86)\ffmpeg\bin\ffmpeg.exe"
        Write-Host -ForegroundColor Yellow "FFmpeg found in program files. Env set. FFmpeg loaded."
    } else {
        Write-Host -ForegroundColor Yellow "This script can not run without FFmpeg. Please install FFmpeg to C:\Program Files\FFmpeg or set your custom path to environment variable %ffmpeg%."
        Start-Sleep -Seconds 20
        exit
    }

    if($unluckyMode){
        ALAC-LogMessage -logPath $logPath -message 'I''m feeling unlucky.'
    }
    if(Test-Path -LiteralPath $folderPath){
        $files = Get-Childitem $folderPath -Recurse | Select * | Where-Object {$_.extension -eq ".m4a"} | Sort-Object -Descending
        foreach($file in $files){
            if($unluckyMode){
                Process-ALACFile -filePath $file.fullname -targetDecibels $targetDecibels -threshold $threshold -logPath $logPath
            } else {
                Process-ALACFile -filePath $file.fullname -targetDecibels $targetDecibels -threshold $threshold -logPath $logPath -luckyMode
            }
        }
    } else { 
        ALAC-LogMessage -logPath $logPath -message '## break in Process-ALACDirectory: $folderPath isn''t a path?'
        ALAC-LogMessage -logPath $logPath -message '#### $folderPath contents:'
        ALAC-LogMessage -logPath $logPath -message $folderPath
        break; 
    }
}

function Process-ALACFile($filePath,$targetDecibels="-15",$threshold="1",$logPath="$($filePath)`.log",[switch]$luckyMode){
    ALAC-LogMessage -logPath $logPath -message "Processing file ""$($filePath)""."
    if(Test-Path -LiteralPath $filePath){
        $Name = $filePath | Split-Path -Leaf
        $Path = $filePath | Split-Path -Parent
        $baseName = [io.path]::GetFileNameWithoutExtension($origFile)
        $dataFile = "$Path\LoudnessData.log"
        <# Feature: Volume Validation and DR Info
        $rangeLog = "$Path\DR_log.txt"
        $rangeLock = $false
        #>
    } else { 
        ALAC-LogMessage -logPath $logPath -message '## Break in Process-ALACFile: $filePath seems to be jacked'
        ALAC-LogMessage -logPath $logPath -message '#### $filePath contents:'
        ALAC-LogMessage -logPath $logPath -message $filePath
        break; 
    }
    ALAC-LogMessage -logPath $logPath -message "Reading loudness data."
    $data = Get-LoudnessData -filePath $filePath -dataFile $dataFile -logPath $logPath
    ALAC-LogMessage -logPath $logPath -message "Average Volume: $($data.input_i)dB. True Peak: $($data.input_tp)dB."
    if($data){
        ALAC-LogMessage -logPath $logPath -message "Calculating volume adjustment."
        ALAC-LogMessage -logPath $logPath -message "Target volume: $($targetDecibels)dB (plus or minus $($threshold)dB). True Peak limited to -1dB."
        $volAdjust = $targetDecibels - $($data.input_i)
        ALAC-LogMessage -logPath $logPath -message "Adjustment: $($targetDecibels)dB - $($data.input_i)dB = $($volAdjust)dB. Seeing how much space is on the other side of True Peak."
        if(($volAdjust -gt 0) -and ($volAdjust + $data.input_tp -gt -1)){
            $oldVolAdjust = $volAdjust
            $volAdjust = -1 - $data.input_tp
            ALAC-LogMessage -logPath $logPath -message "True Peak is high (good dynamic range). Adjustment reduced to $($volAdjust)dB."
        } else { 
            ALAC-LogMessage -logPath $logPath -message 'Plenty of space on the other side of that peak...trust me. Rabbit is good, Rabbit is wise.'
        }
        if([math]::abs($volAdjust) -gt [math]::abs($threshold)){
            if($luckyMode){
                ALAC-LogMessage -logPath $logPath -message "Feeling lucky, punk? Adjusting volume of ""$($filePath)"" by $($volAdjust)dB to target average of $($targetDecibels)`dB without leaving a backup."
                New-BalancedALAC -filePath $filePath -volAdjust $volAdjust -logPath $logPath -dataFile $dataFile -luckyMode
                $data.input_i = $data.input_i + $volAdjust
                $data.input_tp = $data.input_tp + $volAdjust
            } else {
                ALAC-LogMessage -logPath $logPath -message "Adjusting volume of ""$($filePath)"" by $($volAdjust)dB to target average of $($targetDecibels)`dB, and leaving a backup."
                New-BalancedALAC -filePath $filePath -volAdjust $volAdjust -logPath $logPath -dataFile $dataFile
                $data.input_i = $data.input_i + $volAdjust
                $data.input_tp = $data.input_tp + $volAdjust
            }
        } else {
            ALAC-LogMessage -logPath $logPath -message "$($filePath) is already within the threshold. Cleaning up and moving on!"
            if($logPath -eq "$filePath`.log"){
                Write-Host -ForegroundColor Green "$($filePath) is already within the threshold. Cleaning up!"
                Remove-Item "$filePath`.log" -Force -Confirm:$false
                Remove-Item $dataFile -Force -Confirm:$false
            } else { 
                Remove-Item $dataFile -Force -Confirm:$false
            }
        }
    } else { 
        ALAC-LogMessage -logPath $logPath -message '## Break in Process-ALACFile: $data missing'
        ALAC-LogMessage -logPath $logPath -message '#### $data contents:'
        ALAC-LogMessage -logPath $logPath -message $data
        break; 
    }
}

function Get-LoudnessData($filePath,$dataFile="$($filePath)`.data.log",$logPath="$($filePath)`.log"){
    #if($filePath -like '*`[*'){ 'true' }
    if(Test-Path -LiteralPath $filePath){
        $arg1 = ' -i "{0}" -af loudnorm=I=-15:TP=-1.0:LRA=1:print_format=json -f null -' -f $filePath
        Start-Process -FilePath $env:ffmpeg -ArgumentList $arg1 -RedirectStandardError $dataFile -NoNewWindow -Wait
    } else { 
        ALAC-LogMessage -logPath $logPath -message '## Break in Get-LoudnessData: What is $filePath?'
        ALAC-LogMessage -logPath $logPath -message '#### $filePath contents:'
        ALAC-LogMessage -logPath $logPath -message $filePath
        break; 
    }
    $data = Filter-LoudnessData -dataFile $dataFile
    return $data
}

function Filter-LoudnessData($dataFile,$logPath="$($dataFile)`.log"){
    if(Test-Path -LiteralPath $dataFile){
        $data = @{}
        $data.raw = Get-Content -Path $dataFile -Tail 12
        $data.input_i = $data.raw[-11].split('"')[3]
        $data.input_tp = $data.raw[-10].split('"')[3]
        $data.input_lra = $data.raw[-9].split('"')[3]
        $data.input_thresh = $data.raw[-8].split('"')[3]
        $data.output_i = $data.raw[-7].split('"')[3]
        $data.output_tp = $data.raw[-6].split('"')[3]
        $data.output_lra = $data.raw[-5].split('"')[3]
        $data.output_thresh = $data.raw[-4].split('"')[3]
        $data.normalization_type = $data.raw[-3].split('"')[3]
        $data.target_offset = $data.raw[-2].split('"')[3]
        $data.DR = $data.input_tp - $data.input_i
    } else { 
        ALAC-LogMessage -logPath $logPath -message '## Break in Filter-LoudnessData: $dataFile doesn''t exist.'
        ALAC-LogMessage -logPath $logPath -message '#### $dataFile contents:'
        ALAC-LogMessage -logPath $logPath -message $dataFile
        break; 
    }
    Return $data
}

function New-BalancedALAC($filePath,$volAdjust,$dataFile,$logPath="$($filePath)`.log",[switch]$luckyMode){
    if(!($filePath)){
        ALAC-LogMessage -logPath $logPath -message '## Break in New-BalancedALAC: $filePath is jacked.'
        ALAC-LogMessage -logPath $logPath -message '#### $filePath contents:'
        ALAC-LogMessage -logPath $logPath -message $filePath
        break;
    }
    if(!($volAdjust)){
        ALAC-LogMessage -logPath $logPath -message '## Break in New-BalancedALAC: $volAdjust is jacked.'
        ALAC-LogMessage -logPath $logPath -message '#### $volAdjust contents:'
        ALAC-LogMessage -logPath $logPath -message $volAdjust
        break;
    }
    if(!($dataFile)){
        ALAC-LogMessage -logPath $logPath -message '## Break in New-BalancedALAC: $dataFile is jacked.'
        ALAC-LogMessage -logPath $logPath -message '#### $dataFile contents:'
        ALAC-LogMessage -logPath $logPath -message $dataFile
        break;
    }
    $tempPath = "$($filePath | Split-Path -Parent)\temp_$($filePath | split-path -leaf)"
    ALAC-LogMessage -logPath $logPath -message "Creating temp copy of ""$filePath"""
    Move-Item -LiteralPath $filePath -Destination $tempPath -Force
    $arg2 = ' -i "{0}" -filter:a "volume={1}dB" -c:v copy -map_metadata:s:a 0:s:a -acodec alac -ar 44100 -sample_fmt s16p "{2}"' -f $tempPath,$volAdjust,$filePath
    Start-Process -FilePath $env:ffmpeg -ArgumentList $arg2 -RedirectStandardError $dataFile -NoNewWindow -Wait
    if($luckyMode){
        ALAC-LogMessage -logPath $logPath -message '$luckyMode enabled: deleting temp file.'
        Remove-Item -LiteralPath $tempPath -Confirm:$false
        Remove-Item -LiteralPath $dataFile -Confirm:$false
    }
    if(!($luckyMode)){
        if((Get-ItemProperty $filePath).length -gt 0){
        ALAC-LogMessage -logPath $logPath -message "Good news. ""$filepath"" isn't null. Feel free to delete ""$tempPath""."
        Remove-Item -LiteralPath $dataFile -Confirm:$false
        }
    }
}

function ALAC-LogMessage($logPath,$message){
    '' | Out-File -LiteralPath $logPath -Encoding ascii -Append 
    $message | Out-File -LiteralPath $logPath -Encoding ascii -Append
}
<# End Functions #>


<# Testing Space 
Process-ALACDirectory "M:\CDFlac\Junip\Junip - Junip - 2013 (320 kbps)" -luckyMode
#>
