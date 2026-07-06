import AppKit
import UniformTypeIdentifiers
import WebKit

private enum AppConfig {
    static let appName = "DewQRaft"
    static let popoverSize = NSSize(width: 560, height: 520)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let webViewController = WebViewController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()
        configureStatusItem()
        configurePopover()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit DewQRaft", action: #selector(quit), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = StatusIcon.image()
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.toolTip = AppConfig.appName
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = AppConfig.popoverSize
        popover.contentViewController = webViewController
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            webViewController.loadIfNeeded()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            webViewController.focus()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit DewQRaft", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

final class WebViewController: NSViewController, WKScriptMessageHandler {
    private var didLoad = false
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController.add(self, name: "dewQRaftNative")

        let view = WKWebView(frame: .zero, configuration: configuration)
        return view
    }()

    override func loadView() {
        view = webView
        view.frame = NSRect(origin: .zero, size: AppConfig.popoverSize)
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true

        guard let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") else {
            webView.loadHTMLString("<body style='font:14px -apple-system;color:#111;background:#f4efe5'>Missing index.html</body>", baseURL: nil)
            return
        }

        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    func focus() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.window?.makeFirstResponder(self.webView)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == "dewQRaftNative",
            let body = message.body as? [String: Any],
            let type = body["type"] as? String
        else { return }

        switch type {
        case "copyPng":
            guard let base64 = body["base64"] as? String, let data = Data(base64Encoded: base64) else { return }
            copyPng(data)
            callJavaScriptDone("PNG copied")
        case "copyText":
            guard let text = body["text"] as? String else { return }
            copyText(text)
            callJavaScriptDone((body["label"] as? String) ?? "Copied")
        case "save":
            saveFile(from: body)
        default:
            break
        }
    }

    private func copyPng(_ data: Data) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: .png)
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func saveFile(from body: [String: Any]) {
        let fileName = (body["fileName"] as? String) ?? "dewqraft-code"
        let mime = (body["mime"] as? String) ?? "application/octet-stream"
        let data: Data

        if let base64 = body["base64"] as? String, let decoded = Data(base64Encoded: base64) {
            data = decoded
        } else if let text = body["text"] as? String, let encoded = text.data(using: .utf8) {
            data = encoded
        } else {
            callJavaScriptDone("Nothing to save")
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = allowedTypes(for: mime)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                self?.callJavaScriptDone("Saved")
            } catch {
                self?.callJavaScriptDone("Save failed")
            }
        }
    }

    private func allowedTypes(for mime: String) -> [UTType] {
        switch mime {
        case "image/png":
            return [.png]
        case "image/svg+xml":
            return [UTType(filenameExtension: "svg") ?? .data]
        default:
            return [.data]
        }
    }

    private func callJavaScriptDone(_ message: String) {
        let escaped = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.dewQRaftNativeDone && window.dewQRaftNativeDone('\(escaped)');")
    }
}

private enum StatusIcon {
    static func image() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.black.setStroke()
        let stroke = NSBezierPath()
        stroke.lineWidth = 1.7
        for rect in [
            NSRect(x: 2.5, y: 11, width: 4.5, height: 4.5),
            NSRect(x: 11, y: 11, width: 4.5, height: 4.5),
            NSRect(x: 2.5, y: 2.5, width: 4.5, height: 4.5)
        ] {
            stroke.appendRoundedRect(rect, xRadius: 1.0, yRadius: 1.0)
        }
        stroke.stroke()

        NSColor.black.setFill()
        for rect in [
            NSRect(x: 10.5, y: 6.8, width: 2.0, height: 2.0),
            NSRect(x: 14.0, y: 6.8, width: 2.0, height: 2.0),
            NSRect(x: 10.5, y: 3.0, width: 2.0, height: 2.0),
            NSRect(x: 13.8, y: 2.8, width: 2.0, height: 4.8)
        ] {
            NSBezierPath(rect: rect).fill()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
