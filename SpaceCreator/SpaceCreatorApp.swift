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
        let script = """
        tell application "System Events"
            -- Open Mission Control
            key code 126 using control down
            delay 0.5
            
            -- Click the add button in Mission Control
            tell process "Dock"
                set missionControlGroup to group 2 of group 1 of group 1
                click button 1 of missionControlGroup
            end tell
            
            delay 0.3
            
            -- Exit Mission Control
            key code 53
        end tell
        """
        
        // Try the simpler AppleScript method first
        let simpleScript = """
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
        if let scriptObject = NSAppleScript(source: simpleScript) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                print("AppleScript error: \(error)")
                // Fallback to keyboard simulation
                createSpaceViaKeyboardSimulation()
            } else {
                showNotification(title: "Space Created", body: "New desktop space added")
            }
        }
    }
    
    private func createSpaceViaKeyboardSimulation() {
        // Open Mission Control (Control + Up Arrow)
        let missionControlDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x7E, keyDown: true)
        missionControlDown?.flags = .maskControl
        missionControlDown?.post(tap: .cghidEventTap)
        
        let missionControlUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x7E, keyDown: false)
        missionControlUp?.flags = .maskControl
        missionControlUp?.post(tap: .cghidEventTap)
        
        // Wait for Mission Control to open, then try to add a space
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            // Move mouse to top-right area where the + button appears
            let screenFrame = NSScreen.main?.frame ?? NSRect.zero
            let addButtonPosition = CGPoint(x: screenFrame.width - 50, y: screenFrame.height - 30)
            
            // Move mouse
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: addButtonPosition, mouseButton: .left)?.post(tap: .cghidEventTap)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Click
                CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: addButtonPosition, mouseButton: .left)?.post(tap: .cghidEventTap)
                CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: addButtonPosition, mouseButton: .left)?.post(tap: .cghidEventTap)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Press Escape to exit Mission Control
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
