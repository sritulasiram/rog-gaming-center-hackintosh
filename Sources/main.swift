import Cocoa
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public static private(set) var shared: AppDelegate?

    private var mainWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let service = AuraService.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[ROGGamingCenter] applicationDidFinishLaunching started")
        AppDelegate.shared = self

        // 1. Run as Regular Windowed macOS Application
        NSApp.setActivationPolicy(.regular)

        // 2. Create Main Window
        NSLog("[ROGGamingCenter] Creating main window...")
        createMainWindow()

        // 3. Configure Menu Bar Companion Status Item
        NSLog("[ROGGamingCenter] Setting up status item...")
        setupStatusItem()

        // 4. Configure Companion Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 290, height: 320)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: AuraPopoverView())

        // 5. Present Main Window on Launch
        NSLog("[ROGGamingCenter] Showing main window...")
        showMainWindow()
        NSLog("[ROGGamingCenter] Launch setup complete.")
    }

    // MARK: - Main Application Window

    private func createMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("ROGGamingCenterMainWindow")
        window.title = "ROG Gaming Center"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 900, height: 600)
        window.contentViewController = NSHostingController(rootView: MainWindowView())
        window.delegate = self
        self.mainWindow = window
    }

    public func showMainWindow() {
        if mainWindow == nil {
            createMainWindow()
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - App Reopen & Close Lifecycle

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return !service.isCloseToTrayEnabled
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if service.isCloseToTrayEnabled {
            // Minimize to menu bar tray
            sender.orderOut(nil)
            return false
        } else {
            NSApp.terminate(nil)
            return true
        }
    }

    // MARK: - Menu Bar Status Item & Companion

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.toolTip = "ROG Gaming Center & Aura Core"
            
            var menubarImg: NSImage?
            if let iconPath = Bundle.main.path(forResource: "menubar_icon", ofType: "png"),
               let img = NSImage(contentsOfFile: iconPath) {
                menubarImg = img
            } else if let img = NSImage(contentsOfFile: "./Resources/menubar_icon.png") {
                menubarImg = img
            }
            
            if let img = menubarImg {
                img.size = NSSize(width: 22, height: 15)
                img.isTemplate = true
                button.image = img
                button.imagePosition = .imageOnly
            } else {
                button.title = "ROG"
            }
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || (event.modifierFlags.contains(.control) && event.type == .leftMouseUp) {
            popover.performClose(sender)
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Context Menu

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "ROG Gaming Center (\(service.deviceName))", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open ROG Gaming Center", action: #selector(openMainWindowAction), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let powerItem = NSMenuItem(
            title: service.isPoweredOn ? "Turn Off Backlight" : "Turn On Backlight",
            action: #selector(togglePowerAction),
            keyEquivalent: "p"
        )
        powerItem.target = self
        menu.addItem(powerItem)

        // Brightness Submenu
        let bMenu = NSMenu()
        for lvl in [0, 1, 2, 3] {
            let label = (lvl == 0) ? "0% (Off)" : "\(lvl * 33)%"
            let item = NSMenuItem(title: label, action: #selector(setBrightnessMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = lvl
            if (service.isPoweredOn ? service.currentBrightness : 0) == lvl {
                item.state = .on
            }
            bMenu.addItem(item)
        }
        let bSubItem = NSMenuItem(title: "Brightness", action: nil, keyEquivalent: "")
        bSubItem.submenu = bMenu
        menu.addItem(bSubItem)

        // Presets Submenu
        let pMenu = NSMenu()
        for preset in AuraPreset.builtInPresets {
            let pItem = NSMenuItem(title: preset.name, action: #selector(applyPresetMenuAction(_:)), keyEquivalent: "")
            pItem.target = self
            pItem.representedObject = preset
            if service.activePresetId == preset.id {
                pItem.state = .on
            }
            pMenu.addItem(pItem)
        }
        let pSubItem = NSMenuItem(title: "Presets", action: nil, keyEquivalent: "")
        pSubItem.submenu = pMenu
        menu.addItem(pSubItem)

        menu.addItem(NSMenuItem.separator())

        let resyncItem = NSMenuItem(title: "Re-Sync Hardware Handshake", action: #selector(resyncAction), keyEquivalent: "r")
        resyncItem.target = self
        menu.addItem(resyncItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit ROG Gaming Center", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        buttonPopMenu(sender)
    }

    private func buttonPopMenu(_ sender: NSStatusBarButton) {
        statusItem.button?.performClick(nil)
        // Clean up menu on main queue after tracking
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    @objc private func openMainWindowAction() {
        showMainWindow()
    }

    @objc private func togglePowerAction() {
        service.togglePower()
    }

    @objc private func setBrightnessMenuAction(_ sender: NSMenuItem) {
        service.setBrightness(sender.tag)
    }

    @objc private func applyPresetMenuAction(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? AuraPreset {
            service.applyPreset(preset)
        }
    }

    @objc private func resyncAction() {
        service.forceHardwareResync()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}

// MARK: - App Entry Point

NSLog("[ROGGamingCenter] Initializing AppDelegate...")
let globalAppDelegate = AppDelegate()
let app = NSApplication.shared
app.delegate = globalAppDelegate
NSLog("[ROGGamingCenter] Calling app.run()...")
app.run()
NSLog("[ROGGamingCenter] app.run() finished.")
