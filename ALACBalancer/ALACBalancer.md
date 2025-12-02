# ALACBalancer (Serial Version)

Audio loudness normalization tool that converts audio files to ALAC format with consistent loudness levels using the LUFS standard.

## Requirements

- **PowerShell**: 5.1+ (Windows PowerShell or PowerShell 7+)
- **FFmpeg**: 8.0+ installed and in system PATH
- **Audio Formats**: Supports .m4a, .opus, .wav, .mp3, .flac input files

## Installation

1. Ensure FFmpeg is installed:
   ```powershell
   ffmpeg -version
   ```
   If not found, install via Chocolatey:
   ```powershell
   choco install ffmpeg
   ```

## Usage

### Basic Syntax

```powershell
. "C:\Users\judge\OneDrive\Documents\WindowsPowerShell\ALACBalancer.ps1"
ConvertTo-ALACDirectory -folderPath "C:\path\to\audio\files"
```

### Parameters

- `-folderPath` (required): Directory containing audio files to process
- `-targetDecibels` (optional, default: "-18"): Target loudness in LUFS
- `-threshold` (optional, default: ".25"): Minimum adjustment threshold in dB
- `-maxPeak` (optional, default: "-.01"): Maximum peak level in dB
- `-unluckyMode` (optional): Backup original files with "(backup)" prefix instead of replacing

### Examples

**Basic usage (defaults to -18 LUFS):**
```powershell
ConvertTo-ALACDirectory -folderPath "Y:\Music"
```

**Custom loudness target:**
```powershell
ConvertTo-ALACDirectory -folderPath "Y:\Music" -targetDecibels "-16"
```

**With backup mode:**
```powershell
ConvertTo-ALACDirectory -folderPath "Y:\Music" -unluckyMode
```

## Processing Details

- **Processing**: Serial (one file at a time)
- **Typical Speed**: ~8-10 seconds per minute of audio
- **Output Format**: ALAC (.m4a) at 44.1 kHz, stereo
- **Temp Files**: Stored in `%LOCALAPPDATA%\Temp\ConvertTo-LeveledALAC\`
- **Log Files**: ALACBalancer.log is created at the input folderPath

## File Handling

- Processes files recursively through subdirectories
- Preserves original metadata (artist, album, date, genre, etc.)
- Handles special characters in filenames using `-LiteralPath`
- Skips files already within threshold of target loudness
- Skips very quiet files (silent/near-silent below -40 dB input)

## Performance

- **Single-threaded**: ~2 minutes for 12 typical audio files
- Best for: Small batches, quick processing, compatibility with older PowerShell versions

## Comparison

For larger batches or performance-critical workflows, see `ALACBalancer_threads.ps1` for the parallel version (requires PowerShell 7+, **3.3x faster**).
