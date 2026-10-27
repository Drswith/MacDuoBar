import AppKit
import Combine
import SwiftUI

@MainActor
final class Preferences: ObservableObject {
    @Published private(set) var layout: Layout
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        layout = Layout.restore(defaults.dictionary(forKey: "layout") as? [String: String])
    }

    func select(_ metric: Metric, at position: Position) {
        layout.select(metric, at: position)
        defaults.set(layout.stored, forKey: "layout")
    }

    func reset() {
        layout = Layout()
        defaults.set(layout.stored, forKey: "layout")
    }
}

@main
enum MacDuoBar {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let reader = SystemReader()
    private let preferences = Preferences()
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var statusPanel: StatusPanel?
    private var outsideClickMonitor: Any?
    private var settings: NSWindow?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item?.button?.target = self
        item?.button?.action = #selector(statusItemClicked)
        item?.button?.setAccessibilityIdentifier("MacDuoBar.status")
        if #unavailable(macOS 26) {
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(rootView: DetailsView(reader: reader, showSettings: { [weak self] in self?.showSettings() }))
        }
        reader.$snapshot.combineLatest(preferences.$layout).sink { [weak self] snapshot, layout in
            self?.updateIcon(snapshot: snapshot, layout: layout)
        }.store(in: &subscriptions)
        reader.start()
        if CommandLine.arguments.contains("--settings") { showSettings() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        closeDetails()
        reader.stop()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === statusPanel else { return }
        if PanelDismissal.shouldClose(primaryMouseDown: NSEvent.pressedMouseButtons & 1 != 0,
                                      location: NSEvent.mouseLocation, statusButtonFrame: statusButtonFrame) {
            closeDetails()
        }
    }

    private var statusButtonFrame: CGRect? {
        guard let button = item?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func updateIcon(snapshot: Snapshot, layout: Layout) {
        guard let button = item?.button else { return }
        button.image = StatusGlyph.image(layout: layout, snapshot: snapshot)
        let description = Position.allCases.filter { layout[$0] != .hidden }.map {
            "\($0.title)\(layout[$0].title)：\(snapshot[layout[$0]].detail)"
        }.joined(separator: "；")
        button.toolTip = description
        button.setAccessibilityLabel("MacDuoBar，\(description)")
    }

    @objc private func statusItemClicked() {
        guard let button = item?.button else { return }
        togglePanel(from: button)
    }

    private func togglePanel(from view: NSView) {
        if popover.isShown || statusPanel != nil {
            closeDetails()
        } else if #available(macOS 26, *) {
            showGlassPanel(from: view)
        } else {
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: view is NSStatusBarButton ? .minY : .maxX)
        }
    }

    @available(macOS 26, *)
    private func showGlassPanel(from view: NSView) {
        guard let window = view.window, let screen = window.screen else { return }
        let width = max(1, min(ControlCenterStyle.width, screen.visibleFrame.width - 28))
        let content = ControlCenterView(reader: reader, width: width, showSettings: { [weak self] in self?.showSettings() })
        let host = NSHostingView(rootView: AnyView(content))
        let availableHeight = screen.visibleFrame.height - 12
        if host.fittingSize.height > availableHeight {
            host.rootView = AnyView(ScrollView { content }.frame(width: width + 12, height: availableHeight))
        }
        let anchor = window.convertToScreen(view.convert(view.bounds, to: nil))
        let frame = PanelPlacement.frame(size: host.fittingSize, anchor: anchor, visibleFrame: screen.visibleFrame, fromMenuBar: view is NSStatusBarButton)
        let panel = StatusPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "MacDuoBar 状态"
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]
        panel.contentView = host
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.closeDetails() }
        statusPanel = panel
        panel.makeKeyAndOrderFront(nil)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let primaryMouseDown = event.type == .leftMouseDown
            let location = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                guard let self,
                      PanelDismissal.shouldClose(primaryMouseDown: primaryMouseDown, location: location,
                                                 statusButtonFrame: self.statusButtonFrame) else { return }
                self.closeDetails()
            }
        }
    }

    private func closeDetails() {
        popover.performClose(nil)
        let panel = statusPanel
        statusPanel = nil
        if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = nil
        panel?.close()
    }

    private func showSettings() {
        closeDetails()
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 430), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "MacDuoBar 设置"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(reader: reader, preferences: preferences, showPanel: { [weak self] in
                guard let self, let content = self.settings?.contentView else { return }
                self.togglePanel(from: content)
            }))
            window.center()
            settings = window
        }
        settings?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class StatusPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

private struct MetricRow: View {
    let metric: Metric
    let reading: Reading

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: metric == .battery ? reading.batterySymbol : reading.centerSymbol ?? metric.symbol)
                .font(.system(size: 17, weight: .medium)).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.title).font(.body.weight(.medium))
                Text(reading.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let value = reading.fraction {
                ProgressView(value: value).frame(width: 62).accessibilityLabel("\(metric.title)比例")
            }
        }
        .frame(minHeight: 34)
        .accessibilityElement(children: .combine)
    }
}

private struct DetailsView: View {
    @ObservedObject var reader: SystemReader
    let showSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MacDuoBar").font(.headline)
            ForEach(Metric.allCases.filter { $0 != .hidden }, id: \.self) { metric in
                MetricRow(metric: metric, reading: reader.snapshot[metric])
            }
            if reader.needsWiFiNameAccess {
                Button("允许读取 Wi-Fi 名称", action: reader.requestWiFiNameAccess)
            }
            Divider()
            DetailActions(showSettings: showSettings)
        }
        .padding(18)
        .frame(width: 340)
    }
}

struct DetailActions: View {
    let showSettings: () -> Void

    var body: some View {
        HStack {
            Button("系统设置…") { openSettingsApp() }
            Spacer()
            Button("设置…", action: showSettings).keyboardShortcut(",")
            Button("退出") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }

    private func openSettingsApp() {
        let url = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        if !NSWorkspace.shared.open(url) {
            let alert = NSAlert()
            alert.messageText = "无法打开系统设置"
            alert.informativeText = "请从 Apple 菜单打开系统设置。"
            alert.runModal()
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var reader: SystemReader
    @ObservedObject var preferences: Preferences
    let showPanel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: showPanel) {
                Image(nsImage: StatusGlyph.image(layout: preferences.layout, snapshot: reader.snapshot))
                    .resizable().interpolation(.high).frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开状态面板")
            .help("打开当前布局的状态面板")
            .padding(.top, 20)
            Form {
                Section("菜单栏布局") {
                    ForEach(Position.allCases, id: \.self) { position in
                        Picker(position.title, selection: Binding(get: { preferences.layout[position] }, set: { preferences.select($0, at: position) })) {
                            ForEach(Metric.allCases, id: \.self) { metric in
                                Text(metric.title).tag(metric)
                                    .disabled(metric == .hidden && preferences.layout[position] != .hidden && preferences.layout.visibleCount == 1)
                            }
                        }
                    }
                    Text("至少保留一个位置。四点表示占用档位；网络只表示连接状态。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    if reader.needsWiFiNameAccess {
                        Button("允许读取 Wi-Fi 名称", action: reader.requestWiFiNameAccess)
                            .help("macOS 要求定位权限才能读取当前 Wi-Fi 名称；不采集位置。")
                    }
                    Button("恢复默认布局") { preferences.reset() }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 440, height: 430)
    }
}
