import AppKit
import CoreLocation
import CoreWLAN
import IOKit.ps
import Network

@MainActor
final class SystemReader: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var snapshot = Snapshot()
    private let network = NWPathMonitor()
    private let wifi = CWWiFiClient.shared()
    private let location = CLLocationManager()
    private let host = mach_host_self()
    private var timer: Timer?
    private var previousCPU: CPUTicks?

    var needsWiFiNameAccess: Bool {
        location.authorizationStatus != .authorizedAlways
            || !CLLocationManager.locationServicesEnabled()
    }

    func requestWiFiNameAccess() {
        NSApp.activate(ignoringOtherApps: true)
        if location.authorizationStatus == .notDetermined {
            location.requestWhenInUseAuthorization()
        } else if needsWiFiNameAccess {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
            if !NSWorkspace.shared.open(url) {
                let alert = NSAlert()
                alert.messageText = "请在系统设置的隐私与安全性中允许 MacDuoBar 使用定位服务，以读取 Wi-Fi 名称。"
                alert.runModal()
            }
        }
        refresh()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    func start() {
        location.delegate = self
        refresh()
        network.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        network.start(queue: DispatchQueue(label: "dev.drs.MacDuoBar.path"))
        timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        network.cancel()
        location.delegate = nil
        mach_port_deallocate(mach_task_self_, host)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func woke() {
        previousCPU = nil
        refresh()
    }

    @objc private func refresh() {
        var next = snapshot
        next.readings[.battery] = battery()
        next.readings[.network] = networkReading()
        let ticks = cpuTicks()
        let cpu = ticks?.usage(since: previousCPU)
        previousCPU = ticks
        next.readings[.cpu] = percentage(cpu, suffix: "占用")
        next.readings[.memory] = percentage(memory(), suffix: "占用估算")
        next.readings[.disk] = percentage(disk(), suffix: "已用")
        snapshot = next
    }

    private func networkReading() -> Reading {
        let path = network.currentPath
        if let interface = wifi.interface() {
            let ssid = needsWiFiNameAccess ? nil : interface.ssid()
            let connected = ssid != nil || interface.interfaceMode() == .station || path.usesInterfaceType(.wifi)
            if connected {
                return .wifi(ssid: ssid, connected: true, nameAuthorized: !needsWiFiNameAccess)
            }
            if path.status != .satisfied {
                return Reading(0, detail: interface.powerOn() ? "未连接" : "关闭", centerSymbol: "wifi")
            }
        }
        let available = path.status == .satisfied
        let ethernet = path.usesInterfaceType(.wiredEthernet)
        return Reading(available ? 1 : 0, detail: available ? "已连接" : "未连接", centerSymbol: !available ? "network.slash" : ethernet ? "cable.connector" : "network")
    }

    private func percentage(_ fraction: Double?, suffix: String) -> Reading {
        guard let fraction, fraction.isFinite else { return .unavailable }
        let reading = Reading(fraction, detail: "")
        return Reading(fraction, detail: "\(reading.number)% · \(suffix)")
    }

    private func battery() -> Reading {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return .unavailable }
        for source in sources {
            guard let values = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let type = values[kIOPSTypeKey] as? String else { return .unavailable }
            guard type == kIOPSInternalBatteryType else { continue }
            guard let current = values[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = values[kIOPSMaxCapacityKey] as? Int,
                  let charging = values[kIOPSIsChargingKey] as? Bool,
                  let state = values[kIOPSPowerSourceStateKey] as? String,
                  maximum > 0, current >= 0 else { return .unavailable }
            let plugged = state == kIOPSACPowerValue
            let ratio = Double(current) / Double(maximum)
            return .battery(fraction: ratio, charging: charging, externalPower: plugged)
        }
        return Reading(nil, detail: "外接电源 · 无内置电池", centerSymbol: "powerplug.fill")
    }

    private func cpuTicks() -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }

    private func memory() -> Double? {
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        let pages = UInt64(info.active_count) + UInt64(info.wire_count) + UInt64(info.compressor_page_count)
        return Double(pages) * Double(pageSize) / Double(ProcessInfo.processInfo.physicalMemory)
    }

    private func disk() -> Double? {
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
              let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity,
              total > 0, available >= 0 else { return nil }
        return 1 - Double(available) / Double(total)
    }
}
