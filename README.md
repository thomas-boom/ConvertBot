# ConvertBot

![macOS](https://img.shields.io/badge/macOS-Sonoma%2B-brightgreen)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-blue)

**ConvertBot** is a macOS Sonoma+ utility for converting video and audio files with a modern, user-friendly SwiftUI interface. It leverages **AVFoundation** for native file conversion and optionally supports **FFmpeg** for AVI file processing.  

---

## Features

- ✅ Convert **video files** (`MOV`, `MP4`, `M4V`, `AVI`)  
- ✅ Convert **audio files** (`M4A`, `WAV`, `CAF`, `AAC`, `AIFF`)  
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
git clone https://github.com/yourusername/ConvertBot.git```

2.	Open ConvertBot.xcodeproj in Xcode.
3.	Build and run the app on your Mac.

⚠️ FFmpeg Support: To support AVI conversion via FFmpeg, include a static FFmpeg binary in the Resources/FFmpeg folder. Make sure the binary is executable:

Usage
	1.	Click Choose Media… to select a video or audio file.
	2.	For video, pick the desired export format (MOV, MP4, M4V).
	3.	For audio, pick the desired export format (M4A, WAV, CAF, AAC, AIFF).
	4.	Optional: Toggle Compress for smaller file size and select video quality.
	5.	Conversion starts immediately; monitor progress with the animated progress bar.
	6.	Once finished, the app notifies you and opens the converted file in Finder.

FFmpeg Support
	•	AVI files are converted using FFmpeg.
	•	Place the binary in Resources/FFmpeg/ffmpeg.
	•	The app automatically detects and uses FFmpeg for AVI files.

⸻

Contributing

Contributions are welcome! Feel free to:
	•	Submit pull requests
	•	Report issues
	•	Suggest features

⸻

License

This project is licensed under the MIT License. See LICENSE￼ for details.

⸻

About

Created by Thomas Boom — 2025
