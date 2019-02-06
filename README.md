# ALACBalancer
Uses FFmpeg to read dynamic range data from ALAC files, and adjust volume to -15dB with a -1dB true peak limit -- no normalizing.

Before You Run:
FFmpeg.exe optimally should exist at "C:\program files\ffmpeg\bin\ffmpeg.exe" or "C:\program files (x86)\ffmpeg\bin\ffmpeg.exe". The script will set the location found as the environment variable $env:ffmpeg, which is used by the script to execute ffmpeg processes. FFmpeg can be installed in any location, as long as $env:ffmpeg contains that path.

Usage:
Load script by running .\ALACBalancer.ps1 from within the same directory in Powershell.

Run
>Process-AlacDirectory -folderPath <Path to ALAC files>
>Process-AlacDirectory <Path to ALAC files>

This will automatically find all ALAC files recursively based on this location and adjust volume to average -15dB, allowing peak to be no louder than -1dB. Note that PowerShell hates files with [ or ] in the name, and is likely to fail should any paths include these characters. 

Other script arguments:
-folderPath <Path to ALAC files> 
-targetDecibels: the default is "-15", but any number can be set here to determine the average volume.
-threshold: the default is "1", which actually means -1dB. You can set this to "0" if you prefer to let the peaks touch the waveform maximum.
-logPath: the default is "$($folderPath)\ALACBalancer.log". This means that it extracts the specified folder path above and maintains the process log.
-unluckyMode: this will preserve the original copy of your ALAC file if you're afraid you're about to jack them up.

Note:
This script is only searching for files with the extension .m4a when processing. If you run this on a location with AAC files, they will be processed and converted to ALAC (say goodbye to space savings), with no actual increase in quality.

