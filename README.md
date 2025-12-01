# ConvertBot

![macOS](https://img.shields.io/badge/macOS-Sonoma%2B-brightgreen)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-blue)

**ConvertBot** is a macOS Sonoma+ utility for converting video and audio files with a modern, user-friendly SwiftUI interface. It leverages **AVFoundation** for native file conversion and optionally supports **FFmpeg** for (currently only) AVI file processing.  

---

<img width="1012" height="837" alt="Scherm­afbeelding 2025-12-01 om 12 04 15" src="https://github.com/user-attachments/assets/0d484713-3eb6-4a14-a536-ff83f9041a56" />


## Features

- ✅ Convert **video files** (`MOV`, `MP4`, `M4V`, `AVI`)  
- ✅ Convert **audio files** (`M4A`, `WAV`, `MP3`, `AAC`, `AIFF`)  
- ✅ Optional **compression** for smaller file sizes  
- ✅ Select **video quality presets**: Passthrough, High, Medium, Low  
- ✅ Native **progress bar** with percentage indicator  
- ✅ Desktop **notifications** upon conversion completion  
- ✅ Quick access to converted files in Finder  
- ✅ Modern **glass-style UI** using SwiftUI's `ultraThinMaterial`  

---

## Requirements

- macOS Sonoma or later  
- Xcode 15+  
- Swift 5.9+  

---

## Installation

1. Clone this repository:  

```bash
git clone https://github.com/thomas-boom/ConvertBot.git
```

2. Open `ConvertBot.xcodeproj` in Xcode.
3.	Build and run the app on your Mac.

### OR

Download the v1.0 version .app from the Releases page.

## Usage

1. Click **Choose Media…** to select a video or audio file.
2. For video, pick the desired export format: `MOV`, `MP4`, or `M4V`.
3. For audio, pick the desired export format: `M4A`, `WAV`, `MP3`, `AAC`, or `AIFF`.
4. (Optional) Toggle **Compress** for smaller file size and select video quality.
5. Conversion starts immediately; monitor progress with the animated progress bar.
6. When finished, the app will notify you and provide quick access to the converted file in Finder.

## FFmpeg Support

- AVI files are converted using FFmpeg when available.
- `ffmpeg` is currently added to the `Resources` folder.
- The app will detect and use FFmpeg automatically for AVI files.

---

## Contributing

Contributions are welcome! You can:

- Submit pull requests
- Report issues
- Suggest features

Please follow the repository's contribution guidelines when opening PRs.

---

## License

This project is licensed under the MIT License. See `LICENSE` for details.

---

## About

Created by Thomas Boom — 2025
