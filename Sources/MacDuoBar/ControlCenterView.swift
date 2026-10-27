import SwiftUI

enum ControlCenterStyle {
    static let width: CGFloat = 292
    static let height: CGFloat = 64
    static let spacing: CGFloat = 12
    static let padding: CGFloat = 6
    static let secondaryFontSize: CGFloat = 11
}

@available(macOS 26, *)
struct ControlCenterView: View {
    @ObservedObject var reader: SystemReader
    let width: CGFloat
    let showSettings: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: ControlCenterStyle.spacing) {
                HStack(spacing: ControlCenterStyle.spacing) {
                    NetworkCard(reading: reader.snapshot[.network], requestNameAccess: reader.requestWiFiNameAccess)
                    BatteryCard(reading: reader.snapshot[.battery])
                }
                ForEach([Metric.cpu, .memory, .disk], id: \.self) { metric in
                    MeterCard(metric: metric, reading: reader.snapshot[metric])
                }
                DetailActions(showSettings: showSettings)
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.glass).buttonBorderShape(.capsule).controlSize(.small)
            }
        }
        .frame(width: width)
        .padding(ControlCenterStyle.padding)
        .environment(\.controlActiveState, .key)
    }
}

@available(macOS 26, *)
private struct ControlCenterSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let adaptive = reduceTransparency || contrast == .increased
        content
            .frame(maxWidth: .infinity)
            .frame(height: ControlCenterStyle.height)
            .foregroundStyle(adaptive ? Color.primary : .white)
            .glassEffect(.regular, in: .capsule)
    }
}

@available(macOS 26, *)
private struct NetworkCard: View {
    let reading: Reading
    let requestNameAccess: () -> Void

    private var connected: Bool { reading.fraction == 1 }
    private var title: String {
        switch reading.centerSymbol {
        case "wifi": "Wi-Fi"
        case "cable.connector": "以太网"
        default: "网络"
        }
    }

    var body: some View {
        Button(action: requestNameAccess) {
            HStack(spacing: 6) {
                Image(systemName: reading.centerSymbol ?? "network")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(connected ? Color.blue : .white)
                    .frame(width: 36, height: 36)
                    .background(connected ? Color.white : .white.opacity(0.15), in: .circle)
                    .drawingGroup()
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(reading.detail == "需要定位权限" ? "授权读取" : reading.detail)
                        .font(.system(size: ControlCenterStyle.secondaryFontSize, weight: .medium)).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .modifier(ControlCenterSurface())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("网络，\(reading.detail)")
        .help(reading.detail == "需要定位权限" ? "点击允许读取当前 Wi-Fi 名称；macOS 要求定位权限。" : reading.detail)
    }
}

@available(macOS 26, *)
private struct BatteryCard: View {
    let reading: Reading

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: reading.batterySymbol)
                .font(.system(size: 19, weight: .semibold))
            Text(reading.fraction == nil ? "–" : "\(reading.number)%")
                .font(.system(size: 13, weight: .semibold)).monospacedDigit()
        }
        .padding(.horizontal, 14)
        .modifier(ControlCenterSurface())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("电量，\(reading.detail)")
        .help(reading.detail)
    }
}

@available(macOS 26, *)
private struct MeterCard: View {
    let metric: Metric
    let reading: Reading

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(metric.title)
                Spacer()
                Text(reading.fraction == nil ? "–" : "\(reading.number)%").monospacedDigit()
            }
            .font(.system(size: 13, weight: .semibold))
            HStack(spacing: 12) {
                Image(systemName: metric.symbol).font(.system(size: 16, weight: .regular)).frame(width: 18)
                if let fraction = reading.fraction {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.2))
                            Capsule().fill(.white).frame(width: geometry.size.width * fraction)
                        }
                    }
                    .frame(height: 4)
                } else {
                    Text("暂不可用").font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 18)
        }
        .padding(.bottom, 2)
        .padding(.horizontal, 16)
        .modifier(ControlCenterSurface())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title)，\(reading.detail)")
        .help(reading.detail)
    }
}
