import SwiftUI
import AppKit
internal import Combine

// 1. THE ANALOG CLOCK VIEW
struct AnalogClockView: View {
    @State private var date = Date()
    // Timer set to 1 second cz I removed the second hand
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let radius = min(width, height) * 0.3 // Adjust this multiplier to change clock size
            let center = CGPoint(x: width / 2, y: height / 2)

            ZStack {
                // Background Circle (Glass effect)
                Circle()
                    .fill(Color.black.opacity(1))
                    .frame(width: radius * 2.2, height: radius * 2.2)
                
                // 1. Minute Marks (60 ticks)
                ForEach(0..<60) { i in
                    // Only draw minute mark if it's NOT an hour mark
                    if i % 5 != 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2, height: 9) // Thinner and shorter
                            .offset(y: -radius + 5)
                            .rotationEffect(.degrees(Double(i) * 6))
                    }
                }
                
                // Outer Dial Ring
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    .frame(width: radius * 2, height: radius * 2)

                // Hour Marks
                ForEach(0..<12) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 3, height: 15)
                        .offset(y: -radius + 10)
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                // Clock Hands
                ClockHand(length: radius * 0.6, thickness: 8, color: .white, angle: hourAngle())
                ClockHand(length: radius * 0.85, thickness: 5, color: .white, angle: minuteAngle())
                //ClockHand(length: radius * 0.9, thickness: 2, color: .orange, angle: secondAngle())
                
                // Center Pin
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
            }
            .position(center)
            .shadow(color: .black.opacity(0.5), radius: 10)
        }
        .onReceive(timer) { input in
                date = input
        }
    }

    // --- Math for Hand Rotations ---
//    func secondAngle() -> Double {
//        let components = Calendar.current.dateComponents([.second, .nanosecond], from: date)
//        let sec = Double(components.second ?? 0)
//        let nano = Double(components.nanosecond ?? 0) / 1_000_000_000
//        return (sec + nano) * 6
//    }

    func minuteAngle() -> Double {
        let components = Calendar.current.dateComponents([.minute, .second], from: date)
        let min = Double(components.minute ?? 0)
        let sec = Double(components.second ?? 0) / 60
        return (min + sec) * 6
    }

    func hourAngle() -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0)
        let min = Double(components.minute ?? 0) / 60
        return (hour + min) * 30
    }
}

// 2. REUSABLE CLOCK HAND COMPONENT
struct ClockHand: View {
    let length: CGFloat
    let thickness: CGFloat
    let color: Color
    let angle: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: thickness, height: length)
            // This offset moves the "anchor point" to the center of the clock
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }
}

// 3. THE MAGIC WINDOW (Invisible & Backgrounded)
class DesktopWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // This specific level puts it behind all icons/apps but above the wallpaper
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.ignoresMouseEvents = true // Allows you to click items on your desktop
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }
}

// 4. THE APP DELEGATE (Launches the Window)
class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [DesktopWindow] = [] // Store multiple windows

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create a window for every connected screen
        for screen in NSScreen.screens {
            let desktopWindow = DesktopWindow(contentRect: screen.frame)
            let contentView = NSHostingView(rootView: AnalogClockView())
            contentView.wantsLayer = true
            
            desktopWindow.contentView = contentView
            desktopWindow.makeKeyAndOrderFront(nil)
            
            // Link window to this specific screen
            desktopWindow.setFrame(screen.frame, display: true)
            
            windows.append(desktopWindow)
        }
        
        setupMenuBar()
        NSApp.setActivationPolicy(.accessory)
    }

    @objc func refreshWindows() {
        // Force the windows to the front of the desktop layer again after unlocking the laptop
        for window in windows {
            window.orderFrontRegardless() 
        }
    }

    // Add a Menu Bar icon so you can control the app
    var statusItem: NSStatusItem?

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Clock")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Desktop Clock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }

    @objc func toggleLaunchAtLogin() {
        // Note: For a local app, the easiest way is adding it to System Settings
        // after exporting (see Step 3). This menu item serves as a reminder!
    }
}

// 5. THE MAIN ENTRY POINT
@main
struct DesktopClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Required for SwiftUI App lifecycle, but we use AppDelegate for the window
        Settings { EmptyView() }
    }
}
