# DesktopClockMacOS
A minimalist, "wallpaper-integrated" analog clock for macOS. This app lives behind your desktop icons and windows, creating the illusion that the clock is part of your wallpaper. It is multi-monitor aware and optimized for zero-to-low CPU usage.
<img width="1592" height="1043" alt="ScreenshotClock" src="https://github.com/user-attachments/assets/903a23b7-bf71-4c51-ab16-952ffee2fde6" />
<img width="1592" height="1043" alt="ScreenshotClockWithApp" src="https://github.com/user-attachments/assets/3b064c14-adcd-4adf-ba24-e28e44ff2d32" />

# ✨ Features
Wallpaper Illusion: Sits at the .desktopIcon window level (behind apps and icons). Loads automatically on startup and when you unlock your system

Click-Through: Uses ignoresMouseEvents so you can still interact with desktop files "under" the clock.

Multi-Display: Automatically detects all connected monitors and places a clock on each.

Performance: Uses SwiftUI drawingGroup() and GPU acceleration for smooth rendering.

Minimalist Design: Analog face with hour and minute ticks. No distraction because of the seconds hand. Although commented out code already exists. 

# 🛠 Prerequisites
Mac running macOS 12.0 or later.

Xcode (installed via Mac App Store).

# 🚀 Setup Instructions
Create Project: Open Xcode and create a new macOS SwiftUI App named 'DesktopClock'

Add Frameworks: Ensure your DesktopClockApp.swift imports the following:

```
import SwiftUI
import AppKit
import Combine
```

Replace the contents of DesktopClockApp.swift with the final version of the code.

Run: Press Cmd + R to test locally.

# ✨ Build for Production:
Go to Product > Archive. 

Select Distribute App > Custom > Copy App. 

Move the exported .app to your /Applications folder.

# ⚙️ Launch at Login
To have the clock start automatically when you turn on your Mac:

Open System Settings.

Navigate to General > Login Items.

Click the + button and select DesktopClock from your Applications folder.

# 🛑 How to Quit
Since the app is hidden from the Dock and Cmd+Tab:

Find the Clock icon in the top-right macOS Menu Bar.

Select Quit DesktopClock.

Alternatively: Open Terminal and type killall DesktopClock.
