import Foundation

enum Metric: String, CaseIterable {
    case battery, network, cpu, memory, disk, hidden

    var title: String {
        switch self {
        case .battery: "电量"
        case .network: "网络"
        case .cpu: "CPU"
        case .memory: "内存"
        case .disk: "启动磁盘"
        case .hidden: "隐藏"
        }
    }

    var symbol: String {
        switch self {
        case .battery: "battery.100percent"
        case .network: "network"
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .hidden: "eye.slash"
        }
    }
}

enum Position: String, CaseIterable {
    case ring, center, dots

    var title: String {
        switch self {
        case .ring: "外圈"
        case .center: "中间"
        case .dots: "底部四点"
        }
    }
}

struct Layout: Equatable {
    var ring: Metric = .battery
    var center: Metric = .network
    var dots: Metric = .cpu

    subscript(position: Position) -> Metric {
        get {
            switch position {
            case .ring: ring
            case .center: center
            case .dots: dots
            }
        }
        set {
            switch position {
            case .ring: ring = newValue
            case .center: center = newValue
            case .dots: dots = newValue
            }
        }
    }

    var visibleCount: Int { Position.allCases.filter { self[$0] != .hidden }.count }
    var stored: [String: String] {
        Dictionary(uniqueKeysWithValues: Position.allCases.map { ($0.rawValue, self[$0].rawValue) })
    }

    static func restore(_ values: [String: String]?) -> Layout {
        guard let values else { return Layout() }
        var result = Layout()
        for position in Position.allCases {
            guard let raw = values[position.rawValue], let metric = Metric(rawValue: raw) else { return Layout() }
            result[position] = metric
        }
        return result.visibleCount == 0 ? Layout() : result
    }

    mutating func select(_ metric: Metric, at position: Position) {
        guard metric != .hidden || self[position] == .hidden || visibleCount > 1 else { return }
        self[position] = metric
    }
}

struct Reading {
    let fraction: Double?
    let detail: String
    let centerSymbol: String?
    let isExternallyPowered: Bool

    init(_ fraction: Double?, detail: String, centerSymbol: String? = nil, isExternallyPowered: Bool = false) {
        self.fraction = fraction.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil }
        self.detail = detail
        self.centerSymbol = centerSymbol
        self.isExternallyPowered = isExternallyPowered
    }

    static let unavailable = Reading(nil, detail: "暂不可用")
    static func battery(fraction: Double, charging: Bool, externalPower: Bool) -> Reading {
        guard fraction.isFinite else { return .unavailable }
        let number = Reading(fraction, detail: "").number
        return Reading(fraction, detail: "\(number)% · \(charging ? "正在充电" : externalPower ? "外接电源" : "电池供电")",
                       isExternallyPowered: charging || externalPower)
    }

    var batterySymbol: String {
        if let centerSymbol { return centerSymbol }
        if isExternallyPowered { return "battery.100percent.bolt" }
        guard let fraction else { return "battery.0percent" }
        return "battery.\(Int((fraction * 4).rounded()) * 25)percent"
    }

    static func wifi(ssid: String?, connected: Bool, nameAuthorized: Bool) -> Reading {
        let detail: String
        if !connected {
            detail = "未连接"
        } else if !nameAuthorized {
            detail = "需要定位权限"
        } else {
            detail = ssid.flatMap { $0.isEmpty ? nil : $0 } ?? "名称不可用"
        }
        return Reading(connected ? 1 : 0, detail: detail, centerSymbol: "wifi")
    }
    var number: String { fraction.map { String(Int(($0 * 100).rounded())) } ?? "–" }
    var dotCount: Int { fraction.map { Int(ceil($0 * 4)) } ?? 0 }
}

struct Snapshot {
    var readings: [Metric: Reading] = [:]
    subscript(metric: Metric) -> Reading { readings[metric] ?? .unavailable }
}

struct CPUTicks {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    func usage(since previous: CPUTicks?) -> Double? {
        guard let previous else { return nil }
        let idleDelta = UInt64(idle &- previous.idle)
        let busyDelta = UInt64(user &- previous.user) + UInt64(system &- previous.system) + UInt64(nice &- previous.nice)
        let total = idleDelta + busyDelta
        return total > 0 ? Double(busyDelta) / Double(total) : nil
    }
}
