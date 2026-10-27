import XCTest
import AppKit
@testable import MacDuoBar

final class ReadingsTests: XCTestCase {
    func testBatteryUsesBoltForChargingAndFullExternalPower() {
        let charging = Reading.battery(fraction: 0.5, charging: true, externalPower: true)
        XCTAssertEqual(charging.batterySymbol, "battery.100percent.bolt")
        XCTAssertEqual(charging.detail, "50% · 正在充电")
        XCTAssertTrue(charging.isExternallyPowered)
        let full = Reading.battery(fraction: 1, charging: false, externalPower: true)
        XCTAssertEqual(full.batterySymbol, "battery.100percent.bolt")
        XCTAssertEqual(full.detail, "100% · 外接电源")
        for percent in [0, 25, 50, 75, 100] {
            let reading = Reading.battery(fraction: Double(percent) / 100, charging: false, externalPower: false)
            XCTAssertEqual(reading.batterySymbol, "battery.\(percent)percent")
            XCTAssertFalse(reading.isExternallyPowered)
        }
        XCTAssertNil(Reading.battery(fraction: .nan, charging: true, externalPower: true).fraction)
        XCTAssertEqual(Reading(nil, detail: "无内置电池", centerSymbol: "powerplug.fill").batterySymbol, "powerplug.fill")
    }

    @MainActor func testTypicalWiFiNameFitsNativeCardTextArea() {
        let columnWidth = (ControlCenterStyle.width - ControlCenterStyle.spacing) / 2
        let textWidth = columnWidth - 14 * 2 - 36 - 6
        let font = NSFont.systemFont(ofSize: ControlCenterStyle.secondaryFontSize, weight: .medium)
        XCTAssertLessThanOrEqual(("KUKA-Office" as NSString).size(withAttributes: [.font: font]).width, textWidth)
    }

    @MainActor func testPowerIndicatorOccupiesTopRingGapAndPreservesWiFi() throws {
        var snapshot = Snapshot(readings: [.battery: .battery(fraction: 1, charging: false, externalPower: false),
                                           .network: Reading(1, detail: "Wi-Fi", centerSymbol: "wifi")])
        func bitmap(_ layout: Layout) throws -> NSBitmapImageRep {
            let image = StatusGlyph.image(layout: layout, snapshot: snapshot)
            return NSBitmapImageRep(cgImage: try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
        }
        let indicatorLayout = Layout(ring: .hidden, center: .network, dots: .battery)
        let normal = try bitmap(indicatorLayout)
        let hiddenLayout = Layout(ring: .cpu, center: .network, dots: .memory)
        let hidden = try bitmap(hiddenLayout)
        snapshot.readings[.battery] = .battery(fraction: 1, charging: false, externalPower: true)
        let powered = try bitmap(indicatorLayout)
        XCTAssertEqual(normal.pixelsWide, powered.pixelsWide)
        var changed = NSRect.null
        for y in 0..<normal.pixelsHigh {
            for x in 0..<normal.pixelsWide {
                let before = try XCTUnwrap(normal.colorAt(x: x, y: y)).alphaComponent
                let after = try XCTUnwrap(powered.colorAt(x: x, y: y)).alphaComponent
                if abs(before - after) > 0.05 {
                    changed = changed.union(NSRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        XCTAssertFalse(changed.isNull)
        XCTAssertGreaterThanOrEqual(changed.minX / CGFloat(normal.pixelsWide), 0.35)
        XCTAssertLessThanOrEqual(changed.maxX / CGFloat(normal.pixelsWide), 0.65)
        XCTAssertTrue(changed.maxY / CGFloat(normal.pixelsHigh) <= 0.3 || changed.minY / CGFloat(normal.pixelsHigh) >= 0.7)
        XCTAssertEqual(hidden.representation(using: .png, properties: [:]), try bitmap(hiddenLayout).representation(using: .png, properties: [:]))

    }

    func testWiFiNameRequiresPermissionAndDoesNotKeepStaleSSID() {
        let connected = Reading.wifi(ssid: " Office Wi-Fi ", connected: true, nameAuthorized: true)
        XCTAssertEqual(connected.detail, " Office Wi-Fi ")
        XCTAssertEqual(connected.fraction, 1)
        XCTAssertEqual(connected.centerSymbol, "wifi")
        XCTAssertEqual(Reading.wifi(ssid: "Private", connected: true, nameAuthorized: false).detail, "需要定位权限")
        XCTAssertEqual(Reading.wifi(ssid: nil, connected: true, nameAuthorized: true).detail, "名称不可用")
        XCTAssertEqual(Reading.wifi(ssid: "", connected: true, nameAuthorized: true).detail, "名称不可用")
        let disconnected = Reading.wifi(ssid: "Previous", connected: false, nameAuthorized: true)
        XCTAssertEqual(disconnected.detail, "未连接")
        XCTAssertEqual(disconnected.fraction, 0)
    }

    func testCPUUsesIntervalAndNeedsBaseline() {
        let first = CPUTicks(user: 100, system: 50, idle: 800, nice: 0)
        let second = CPUTicks(user: 130, system: 60, idle: 860, nice: 0)
        XCTAssertNil(first.usage(since: nil))
        XCTAssertNil(first.usage(since: first))
        XCTAssertEqual(second.usage(since: first)!, 0.4, accuracy: 0.0001)
    }

    func testCPUHandlesUnsignedTickWrap() {
        let first = CPUTicks(user: .max - 4, system: 0, idle: 100, nice: 0)
        let second = CPUTicks(user: 5, system: 0, idle: 110, nice: 0)
        XCTAssertEqual(second.usage(since: first)!, 0.5, accuracy: 0.0001)
    }

    func testReadingRejectsNonfiniteAndClampsRatios() {
        for value in [Double.nan, .infinity, -.infinity] {
            XCTAssertNil(Reading(value, detail: "").fraction)
            XCTAssertEqual(Reading(value, detail: "").number, "–")
        }
        XCTAssertEqual(Reading(-1, detail: "").fraction, 0)
        XCTAssertEqual(Reading(2, detail: "").fraction, 1)
        XCTAssertEqual(Reading.unavailable.dotCount, 0)
    }

    func testDotBoundaries() {
        for (value, count) in [(0.0, 0), (0.01, 1), (0.25, 1), (0.251, 2), (0.5, 2), (0.75, 3), (0.751, 4), (1, 4)] {
            XCTAssertEqual(Reading(value, detail: "").dotCount, count, "fraction \(value)")
        }
    }

    func testLastVisiblePositionCannotBeHidden() {
        var layout = Layout()
        layout.select(.hidden, at: .ring)
        layout.select(.hidden, at: .center)
        layout.select(.hidden, at: .dots)
        XCTAssertEqual(layout.visibleCount, 1)
        XCTAssertEqual(layout.dots, .cpu)
        layout.select(.memory, at: .center)
        layout.select(.hidden, at: .dots)
        XCTAssertEqual(layout.center, .memory)
        XCTAssertEqual(layout.dots, .hidden)
    }

    func testPersistedLayoutRoundTripsAndRepairsInvalidValues() {
        let layout = Layout(ring: .disk, center: .cpu, dots: .hidden)
        XCTAssertEqual(Layout.restore(layout.stored), layout)
        XCTAssertEqual(Layout.restore(nil), Layout())
        XCTAssertEqual(Layout.restore(["ring": "invalid"]), Layout())
        XCTAssertEqual(Layout.restore(["ring": "hidden", "center": "hidden", "dots": "hidden"]), Layout())
    }

    @MainActor func testPreferencesSurviveNewInstance() {
        let name = "MacDuoBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        preferences.select(.memory, at: .ring)
        XCTAssertEqual(Preferences(defaults: defaults).layout.ring, .memory)
        preferences.reset()
        XCTAssertEqual(Preferences(defaults: defaults).layout, Layout())
    }

    @MainActor func testOfficialSymbolsAndNumbersShareRingCenter() throws {
        let layout = Layout(ring: .hidden, center: .network, dots: .hidden)
        let readings = ["wifi", "network", "network.slash", "cable.connector", "powerplug.fill", "battery.100percent.bolt", "bolt.fill"].map {
            Reading(1, detail: "", centerSymbol: $0)
        } + [nil, 0, 0.5, 1].map { Reading($0, detail: "") }
        for reading in readings {
            let image = StatusGlyph.image(layout: layout, snapshot: Snapshot(readings: [.network: reading]))
            let ink = try XCTUnwrap(StatusGlyph.inkBounds(of: image))
            XCTAssertEqual(ink.midX, StatusGlyph.center.x / 2, accuracy: 0.3, reading.centerSymbol ?? reading.number)
            XCTAssertEqual(ink.midY, StatusGlyph.center.y / 2, accuracy: 0.3, reading.centerSymbol ?? reading.number)
        }
    }

    @MainActor func testSymbolPlacementPreservesOriginalAspectRatio() {
        let size = NSSize(width: 23, height: 18)
        let ink = NSRect(x: 1.5, y: 2, width: 19, height: 14.5)
        let frame = StatusGlyph.centeredFrame(imageSize: size, ink: ink)
        XCTAssertEqual(frame.width / frame.height, size.width / size.height, accuracy: 0.0001)
        XCTAssertEqual(frame.minX + ink.midX * frame.width / size.width, StatusGlyph.center.x, accuracy: 0.0001)
        XCTAssertEqual(frame.minY + ink.midY * frame.height / size.height, StatusGlyph.center.y, accuracy: 0.0001)
    }
}
