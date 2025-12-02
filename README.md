# ALACBalancer

*The ALACBalancer cmdlets use FFmpeg to read dynamic range data from individual audio files (`ConvertTo-LeveledALAC`), or scans folders for audio files (`ConvertTo-ALACDirectory`), adjusting volume to -16dB (or any volume you specify), without normalizing.*

This script utilizes FFmpeg's built in [EBU R 128 Loudness Normalization](https://en.wikipedia.org/wiki/EBU_R_128) loudness measuring standard to detect volume average. Once the loudness data has been attained, it compares it to the arguments provided to verify that the loudness data fall within the parameters provided. Should an audio file fall outside the parameters, it will adjust the volume to match and create a new ALAC file.

## Before You Run

FFmpeg.exe optimally should exist at "C:\program files\ffmpeg\bin\ffmpeg.exe" or "C:\program files (x86)\ffmpeg\bin\ffmpeg.exe". The script will set the location found as the environment variable $env:ffmpeg, which is used by the script to execute ffmpeg processes. FFmpeg can be installed in any location, as long as $env:ffmpeg contains that path.

## Usage

Load script by running .\ALACBalancer.ps1 from within the same directory in Powershell.

## To process a single audio file

Run
>ConvertTo-LeveledALAC -filePath <Path to audio file>

Run
>ConvertTo-ALACDirectory -folderPath <Path to audio files>

This will search for audio files recursively based on the specified path, adjust volume to average -18dB, allowing peak to be no louder than -.01dB. 

## Other script arguments

- folderPath is the only required argument
- targetDecibels: the default is "-18", but any number can be set here to determine the average volume. 
- threshold: this is the swing range in average DR around which the script will ignore the file and move on.
- maxPeak: the default is "-.01", or -.01dB. This prevents the waveform from peaking, as the DA process can produce a waveform that's still capable of clipping, and therefore capable of damaging audio equipment.
- logPath: the default is "$($folderPath)\ALACBalancer.log". This means that it extracts the specified folder path above and maintains the process log.
- unluckyMode: this will preserve the original copy of your ALAC file if you're afraid you're about to jack them up. I trust the script, but I don't expect you to trust it until you've seen it at work.

## **Things to be aware of**

- Currently only supports ALAC files

## Auto Load

- If the folder(s) don't already exist, create C:\Users\<User>\Documents\PowerShell\Modules\ALACBalancer, and add the appropriate ps1 and psd1 files. 
- Close any PowerShell terminals and re-open. 
- This will allow you to automatically load the module by typing the commands above. 
- Remember, pwsh.exe (PowerShell Core 7+) must be the terminal used to run ALACBalancer_threads--in Windows 11, I just opened the Terminal app and set the icon for PS 7 as the default profile in settings.