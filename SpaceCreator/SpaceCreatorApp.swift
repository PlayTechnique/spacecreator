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
        logger.info("=== SpaceCreator: Creating new space via AppleScript ===")

        // Use AppleScript to directly interact with Mission Control UI elements
        // This approach doesn't require calculating screen coordinates
        let script = """
        do shell script "open -b 'com.apple.exposelauncher'"
        delay 0.7
        tell application "System Events"
            tell process "Dock"
                set mc to group 2 of group 1 of group 1
                click button 1 of mc
            end tell
            delay 0.3
            key code 53
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            _ = scriptObject.executeAndReturnError(&error)

            if let error = error {
                logger.error("AppleScript error: \(String(describing: error))")
                // Fallback: try alternative UI element paths
                tryAlternativeAppleScript()
            } else {
                logger.info("AppleScript executed successfully")
                showNotification(title: "Space Created", body: "New desktop space added")
            }
        }
    }

    private func tryAlternativeAppleScript() {
        logger.info("Trying alternative AppleScript approach")

        // Try different UI element paths that may work on different macOS versions
        let alternativeScript = """
        do shell script "open -b 'com.apple.exposelauncher'"
        delay 0.7
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

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: alternativeScript) {
            scriptObject.executeAndReturnError(&error)

            if let error = error {
                logger.error("Alternative AppleScript also failed: \(String(describing: error))")
            } else {
                logger.info("Alternative AppleScript executed successfully")
                showNotification(title: "Space Created", body: "New desktop space added")
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
