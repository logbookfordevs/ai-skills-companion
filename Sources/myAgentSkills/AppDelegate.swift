import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let statusMenu = NSMenu()
    private lazy var popoverEventMonitor = PopoverEventMonitor { [weak self] event in
        self?.handlePopoverEvent(event)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let cliService = SkillsCLIService()
        let installedCatalog = InstalledSkillsCatalogService()
        let customCatalog = CustomSkillsCatalogService()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI Skills Companion")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "AI Skills Companion"
        }

        let quitItem = NSMenuItem(title: "Quit AI Skills Companion", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 940, height: 720)
        popover.contentViewController = PopoverViewController(
            cliService: cliService,
            installedCatalog: installedCatalog,
            customCatalog: customCatalog
        )
    }

    func applicationDidResignActive(_ notification: Notification) {
        closePopover(nil)
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            closePopover(sender)
            statusItem.menu = statusMenu
            statusItem.popUpMenu(statusMenu)
            statusItem.menu = nil
            return
        }

        togglePopover(sender)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
            popoverEventMonitor.start()
        }
    }

    private func closePopover(_ sender: Any?) {
        guard popover.isShown else { return }
        popover.performClose(sender)
        popoverEventMonitor.stop()
    }

    private func handlePopoverEvent(_ event: NSEvent?) {
        guard popover.isShown else { return }

        if let event, event.type == .keyDown, event.keyCode == 53 {
            closePopover(nil)
            return
        }

        if let eventWindow = event?.window {
            if eventWindow === popover.contentViewController?.view.window {
                return
            }

            if eventWindow === statusItem.button?.window {
                return
            }
        }

        closePopover(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
