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
        
        // Let the AppDelegate handle the level (.normal)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.ignoresMouseEvents = true
        self.hidesOnDeactivate = false
        self.animationBehavior = .none
        self.isReleasedWhenClosed = false
        
        // These are the "glue" that keep the window attached to your wallpaper
        // across all monitors and virtual desktops (Spaces).
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        
        // Remove sharingType to allow the Window Server full control
    }
}

// 4. THE APP DELEGATE (Launches the Window)
class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [DesktopWindow] = []
    var statusItem: NSStatusItem?
    var safetyTimer: AnyCancellable?
    var isScreenLocked = false
    var needsRefreshOnUnlock = false
    var forceNextRefresh = false   // bypasses windowsMatchScreens() after unlock+display-change

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        refreshWindows()

        // 1. Listen for hardware changes
        NotificationCenter.default.addObserver(self, selector: #selector(triggerRefresh),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // 2. Listen for lock/unlock events
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(handleLock),
                              name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(handleUnlock),
                              name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)

        // 3. Safety Pulse
        safetyTimer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.reconcile() }
    }

    @objc func handleLock() {
        DispatchQueue.main.async { [weak self] in
            self?.isScreenLocked = true
        }
    }

    @objc func handleUnlock() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScreenLocked = false
            if self.needsRefreshOnUnlock {
                self.needsRefreshOnUnlock = false
                // Pre-lock windows may look valid (correct frames) but be damaged.
                // Force an unconditional rebuild to replace them.
                self.forceNextRefresh = true
                self.triggerRefresh()
            } else {
                self.reconcile()
            }
        }
    }

    func windowsMatchScreens() -> Bool {
        let screens = NSScreen.screens.filter { $0.visibleFrame.width > 0 && $0.visibleFrame.height > 0 }
        guard !screens.isEmpty, windows.count == screens.count else { return false }
        return screens.allSatisfy { screen in
            windows.contains { $0.isVisible && $0.frame == screen.visibleFrame }
        }
    }

    @objc func reconcile() {
        if !windowsMatchScreens() {
            refreshWindows()
        }
    }

    @objc func triggerRefresh() {
        guard !isScreenLocked else {
            needsRefreshOnUnlock = true
            return
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(refreshWindows), object: nil)
        self.perform(#selector(refreshWindows), with: nil, afterDelay: 2.0)
    }

    @objc func refreshWindows() {
        let screens = NSScreen.screens.filter { $0.visibleFrame.width > 0 && $0.visibleFrame.height > 0 }
        guard !screens.isEmpty else { return }

        let force = forceNextRefresh
        forceNextRefresh = false

        if !force && windowsMatchScreens() {
            return
        }

        // Build new windows first, then atomically swap.
        // This prevents a gap where no windows exist if screens are in a transient state.
        var newWindows: [DesktopWindow] = []
        for screen in screens {
            let rect = screen.visibleFrame
            let dw = DesktopWindow(contentRect: rect)
            let cv = NSHostingView(rootView: AnalogClockView())
            cv.wantsLayer = true
            dw.contentView = cv
            dw.setFrame(rect, display: true)
            dw.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            dw.orderFront(nil)
            newWindows.append(dw)
        }

        // Only tear down old windows after new ones are ready
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows = newWindows
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Clock")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Force Refresh", action: #selector(refreshWindows), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
}

// 5. THE MAIN ENTRY POINT
@main
struct DesktopClockApp: App {
    // We use the AppDelegate to handle the complex window logic
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
