import SwiftUI
import Carbon
import ApplicationServices

@main
struct SpaceCreatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    // Meh + D = Control + Option + Shift + D
    private let defaultModifiers: UInt32 = UInt32(controlKey | optionKey | shiftKey)
    private let defaultKeyCode: UInt32 = 0x02 // 'D' key
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerHotKey()
        requestAccessibilityPermissions()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKey()
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Space Creator")
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Create New Space (⌃⌥⇧D)", action: #selector(createNewSpace), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Accessibility Permissions", action: #selector(checkPermissions), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    // MARK: - Hot Key Registration
    
    private func registerHotKey() {
        // Define the hot key ID
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x53504352) // 'SPCR' as a signature
        hotKeyID.id = 1
        
        // Install the event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            appDelegate.createNewSpace()
            return noErr
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        
        // Register the hot key (Meh + D)
        let status = RegisterEventHotKey(
            defaultKeyCode,
            defaultModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            print("Failed to register hot key: \(status)")
        } else {
            print("Hot key registered successfully: Meh + D (⌃⌥⇧D)")
        }
    }
    
    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
    
    // MARK: - Accessibility Permissions
    
    private func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("Accessibility permissions needed. Please grant access in System Preferences.")
        }
    }
    
    @objc private func checkPermissions() {
        let trusted = AXIsProcessTrusted()
        
        let alert = NSAlert()
        if trusted {
            alert.messageText = "Accessibility Permissions Granted"
            alert.informativeText = "The app has the necessary permissions to create desktop spaces."
            alert.alertStyle = .informational
        } else {
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Please grant accessibility permissions in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
        }
        
        let response = alert.runModal()
        if !trusted && response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    // MARK: - Create New Space
    
    @objc func createNewSpace() {
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            DispatchQueue.main.async {
                self.showPermissionsAlert()
            }
            return
        }
        
        // Method: Use Mission Control keyboard shortcut then click the add button
        // This requires simulating Control+Up Arrow, then clicking the "+" button
        
        // Alternative method: Use private APIs via scripting
        createSpaceViaAppleScript()
    }
    
    private func createSpaceViaAppleScript() {
        // Get the screen where the mouse cursor currently is
        let mouseLocation = NSEvent.mouseLocation
        var targetScreen = NSScreen.main ?? NSScreen.screens[0]

        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                targetScreen = screen
                break
            }
        }

        // Calculate the position for the "+" button on the target screen
        // The "+" button appears in the top-right area of the screen's space bar in Mission Control
        // We need to convert to screen coordinates (macOS uses bottom-left origin)
        let screenFrame = targetScreen.frame
        let addButtonX = Int(screenFrame.maxX - 80)
        // For multi-monitor, we need global coordinates
        // macOS screen coordinates have origin at bottom-left of primary screen
        let primaryScreenHeight = NSScreen.screens[0].frame.height
        let addButtonY = Int(primaryScreenHeight - screenFrame.maxY + 35)

        let script = """
        do shell script "open -b 'com.apple.exposelauncher'"
        delay 0.7
        tell application "System Events"
            -- Move mouse to the top-right of the target screen to reveal the + button
            do shell script "cliclick m:\(addButtonX),\(addButtonY)"
        end tell
        delay 0.4
        tell application "System Events"
            tell process "Dock"
                set allGroups to groups of group 1 of group 1
                repeat with g in allGroups
                    try
                        if exists button 1 of g then
                            click button 1 of g
                            exit repeat
                        end if
                    end try
                end repeat
            end tell
            delay 0.3
            key code 53
        end tell
        """

        // Simpler approach: use CGEvent to position mouse, then AppleScript to click
        createSpaceWithMousePosition(on: targetScreen)
    }

    private func createSpaceWithMousePosition(on screen: NSScreen) {
        let screenFrame = screen.frame

        // Open Mission Control
        let source = CGEventSource(stateID: .hidSystemState)
        let ctrlUpDown = CGEvent(keyboardEventSource: source, virtualKey: 0x7E, keyDown: true)
        ctrlUpDown?.flags = .maskControl
        ctrlUpDown?.post(tap: .cghidEventTap)

        let ctrlUpUp = CGEvent(keyboardEventSource: source, virtualKey: 0x7E, keyDown: false)
        ctrlUpUp?.flags = .maskControl
        ctrlUpUp?.post(tap: .cghidEventTap)

        // Wait for Mission Control to open, then move mouse to target screen's add button area
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Position in the top-right of the target screen where + button appears
            // CGEvent uses top-left origin coordinate system
            let primaryScreenHeight = NSScreen.screens[0].frame.height
            let targetX = screenFrame.maxX - 60
            let targetY = primaryScreenHeight - screenFrame.maxY + 25

            // Move mouse to hover area to reveal + button
            let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                   mouseCursorPosition: CGPoint(x: targetX, y: targetY),
                                   mouseButton: .left)
            moveEvent?.post(tap: .cghidEventTap)

            // Wait for + button to appear, then click
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Click the + button
                let clickPoint = CGPoint(x: targetX, y: targetY)

                let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                       mouseCursorPosition: clickPoint, mouseButton: .left)
                mouseDown?.post(tap: .cghidEventTap)

                let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                                     mouseCursorPosition: clickPoint, mouseButton: .left)
                mouseUp?.post(tap: .cghidEventTap)

                // Exit Mission Control
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let escDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: true)
                    escDown?.post(tap: .cghidEventTap)
                    let escUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: false)
                    escUp?.post(tap: .cghidEventTap)

                    self.showNotification(title: "Space Created", body: "New desktop space added")
                }
            }
        }
    }
    
    private func showPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "To create desktop spaces, please grant accessibility permissions in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    private func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = nil
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
