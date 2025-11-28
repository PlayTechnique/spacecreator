import SwiftUI
import Carbon
import ApplicationServices
import os

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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.spacecreator", category: "SpaceCreation")
    
    // Meh + D = Control + Option + Shift + D
    private let defaultModifiers: UInt32 = UInt32(controlKey | optionKey | shiftKey)
    private let defaultKeyCode: UInt32 = 0x02 // 'D' key
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("SpaceCreator starting up - version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
        setupMenuBar()
        registerHotKey()
        requestAccessibilityPermissions()
        logger.info("SpaceCreator startup complete")
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
        // Get the screen with the frontmost window (not mouse - mouse moves to menu bar when clicking menu)
        var targetScreen: NSScreen? = nil

        logger.info("=== SpaceCreator: Creating new space ===")
        logger.info("Available screens: \(NSScreen.screens.count)")
        for (index, screen) in NSScreen.screens.enumerated() {
            let isMain = screen == NSScreen.main
            logger.info("  Screen [\(index)] \(screen.localizedName): frame=\(String(describing: screen.frame)), isMain=\(isMain)")
        }

        // Try to get the screen of the frontmost app's main window
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            logger.info("Frontmost app: \(frontApp.localizedName ?? "unknown") (bundle: \(frontApp.bundleIdentifier ?? "nil"))")

            if frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                // Use Accessibility API to get the frontmost window's position
                let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
                var windowValue: AnyObject?
                let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)

                logger.info("AX focused window result: \(result.rawValue) (success=\(AXError.success.rawValue))")

                if result == .success, let window = windowValue {
                    var positionValue: AnyObject?
                    let posResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, &positionValue)

                    logger.info("AX position result: \(posResult.rawValue)")

                    if posResult == .success, let posValue = positionValue {
                        var point = CGPoint.zero
                        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
                        logger.info("Window position (AX coords, top-left origin): x=\(point.x), y=\(point.y)")

                        // Convert from top-left origin (Accessibility) to bottom-left origin (NSScreen)
                        let primaryHeight = NSScreen.screens[0].frame.height
                        let nsPoint = NSPoint(x: point.x, y: primaryHeight - point.y)
                        logger.info("Converted position (NSScreen coords): x=\(nsPoint.x), y=\(nsPoint.y)")
                        logger.info("Primary screen height used for conversion: \(primaryHeight)")

                        for (index, screen) in NSScreen.screens.enumerated() {
                            let contains = screen.frame.contains(nsPoint)
                            logger.info("  Screen [\(index)] \(screen.localizedName) contains point: \(contains)")
                            if contains {
                                targetScreen = screen
                                logger.info("  -> Selected screen [\(index)] \(screen.localizedName)")
                                break
                            }
                        }

                        if targetScreen == nil {
                            logger.warning("No screen contains the converted point!")
                        }
                    } else {
                        logger.error("Failed to get window position, AX error: \(posResult.rawValue)")
                    }
                } else {
                    logger.error("Failed to get focused window, AX error: \(result.rawValue)")
                }
            } else {
                logger.info("Frontmost app is SpaceCreator itself, skipping AX lookup")
            }
        } else {
            logger.warning("No frontmost application found")
        }

        if targetScreen == nil {
            logger.warning("No target screen determined, falling back to NSScreen.main")
            targetScreen = NSScreen.main
        }

        guard let finalScreen = targetScreen else {
            logger.error("No screen available at all!")
            return
        }

        logger.info("Final target screen: \(finalScreen.localizedName) at \(String(describing: finalScreen.frame))")

        // Calculate the position for the "+" button on the target screen
        // The "+" button appears in the top-right area of the screen's space bar in Mission Control
        // We need to convert to screen coordinates (macOS uses bottom-left origin)
        let screenFrame = finalScreen.frame
        let addButtonX = Int(screenFrame.maxX - 80)
        // For multi-monitor, we need global coordinates
        // macOS screen coordinates have origin at bottom-left of primary screen
        let primaryScreenHeight = NSScreen.screens[0].frame.height
        let addButtonY = Int(primaryScreenHeight - screenFrame.maxY + 35)

        logger.info("Calculated add button position: x=\(addButtonX), y=\(addButtonY)")
        logger.info("Screen frame: \(String(describing: screenFrame))")

        // Simpler approach: use CGEvent to position mouse, then AppleScript to click
        createSpaceWithMousePosition(on: finalScreen)
    }

    private func createSpaceWithMousePosition(on screen: NSScreen) {
        let screenFrame = screen.frame
        logger.info("createSpaceWithMousePosition called for screen: \(screen.localizedName)")
        logger.info("Screen frame: \(String(describing: screenFrame))")

        // Open Mission Control
        let source = CGEventSource(stateID: .hidSystemState)
        let ctrlUpDown = CGEvent(keyboardEventSource: source, virtualKey: 0x7E, keyDown: true)
        ctrlUpDown?.flags = .maskControl
        ctrlUpDown?.post(tap: .cghidEventTap)

        let ctrlUpUp = CGEvent(keyboardEventSource: source, virtualKey: 0x7E, keyDown: false)
        ctrlUpUp?.flags = .maskControl
        ctrlUpUp?.post(tap: .cghidEventTap)

        logger.info("Sent Control+Up to open Mission Control")

        // Wait for Mission Control to open, then move mouse to target screen's add button area
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            // Position in the top-right of the target screen where + button appears
            // CGEvent uses top-left origin coordinate system
            let primaryScreenHeight = NSScreen.screens[0].frame.height
            let targetX = screenFrame.maxX - 60
            let targetY = primaryScreenHeight - screenFrame.maxY + 25

            logger.info("Mouse target position (CGEvent coords): x=\(targetX), y=\(targetY)")
            logger.info("Primary screen height: \(primaryScreenHeight), screenFrame.maxY: \(screenFrame.maxY)")

            // Move mouse to hover area to reveal + button
            CGWarpMouseCursorPosition(CGPoint(x: targetX, y: targetY))
            logger.info("Warped mouse cursor to hover position")

            // Wait for + button to appear, then click
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                // Click the + button
                let clickPoint = CGPoint(x: targetX, y: targetY)
                logger.info("Clicking at: x=\(clickPoint.x), y=\(clickPoint.y)")

                let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                       mouseCursorPosition: clickPoint, mouseButton: .left)
                mouseDown?.post(tap: .cghidEventTap)

                let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                                     mouseCursorPosition: clickPoint, mouseButton: .left)
                mouseUp?.post(tap: .cghidEventTap)

                logger.info("Click events sent")

                // Exit Mission Control
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                    let escDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: true)
                    escDown?.post(tap: .cghidEventTap)
                    let escUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: false)
                    escUp?.post(tap: .cghidEventTap)

                    logger.info("Sent Escape to exit Mission Control")
                    showNotification(title: "Space Created", body: "New desktop space added")
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
