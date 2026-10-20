//
//  Services.swift
//  会话与设备信息服务（连接/断开/状态回调/设备信息聚合）
//
import Foundation
import Combine

final class Session: ObservableObject {

    static let shared = Session()

    @Published private(set) var device: ADBDevice?
    @Published private(set) var isConnecting = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    /// 全局操作计数（用于进度指示）
    @Published private(set) var busyCount = 0

    var connected: Bool { device != nil }
    var serial: String? { device?.serial }

    private var keepAliveTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    private init() {
        observers.append(
            NotificationCenter.default.addObserver(forName: NSNotification.Name("ADBConnectStatusChanged"),
                                                   object: nil, queue: .main) { [weak self] note in
                guard let info = note.userInfo,
                      let serial = info["serial"] as? String,
                      let status = info["status"] as? String else { return }
                self?.handleStatus(serial: serial, status: status)
            }
        )
    }

    // MARK: - 状态回调

    private func handleStatus(serial: String, status: String) {
        // adb 传输状态变化：device/offline/connecting/authorizing/unauthorized
        guard let d = device, d.serial == serial else { return }
        let state = ADBConnectState(raw: status)
        var updated = d
        updated.state = state
        device = updated
        if state == .offline || state == .unauthorized || state == .noPermissions {
            // 保持 device 卡片但标记断开语义：offline 时视为不可用
        }
        if state == .device {
            // 已就绪，静默刷新一次信息
            refreshDeviceInfoIfNeeded()
        }
    }

    // MARK: - 连接

    func connect(ip: String, port: Int, code: String? = nil, completion: ((Bool, String) -> Void)? = nil) {
        let cleanIP = ip.trimmingCharacters(in: .whitespaces)
        guard !cleanIP.isEmpty else { return }
        guard !isConnecting else { return }

        isConnecting = true
        lastError = nil
        busyCount += 1

        let endpoint = "\(cleanIP):\(port)"
        let pairTask: [String]?
        if let code, !code.isEmpty {
            pairTask = ["pair", endpoint, code]
        } else {
            pairTask = nil
        }

        func finish(_ ok: Bool, _ msg: String) {
            DispatchQueue.main.async {
                self.isConnecting = false
                self.busyCount -= 1
                completion?(ok, msg)
            }
        }

        ADBEngine.shared.run(pairTask ?? ["connect", endpoint]) { pairResult in
            // 配对模式：先 pair，成功后再 connect
            if let _ = pairTask {
                let pairOut = pairResult.output.trimmed
                let pairOK = pairResult.succeeded && (pairOut.contains("Successfully paired") || pairOut.lowercased().contains("success"))
                guard pairOK else {
                    finish(false, pairOut.isEmpty ? L("connect.failed") : pairOut)
                    return
                }
                ADBEngine.shared.run(["connect", endpoint]) { result in
                    self.handleConnectResult(result, endpoint: endpoint, ip: cleanIP, port: port, finish: finish)
                }
            } else {
                self.handleConnectResult(pairResult, endpoint: endpoint, ip: cleanIP, port: port, finish: finish)
            }
        }
    }

    private func handleConnectResult(_ result: ADBResult, endpoint: String, ip: String, port: Int,
                                     finish: @escaping (Bool, String) -> Void) {
        let out = result.output
        let lowered = out.lowercased()
        if result.succeeded && (lowered.contains("connected") || lowered.contains("already")) {
            // 连接成功 → 用 get-state 确认真正 device 状态
            ADBEngine.shared.run(["-s", endpoint, "get-state"]) { st in
                let state = st.output.trimmed
                if state == "device" {
                    self.device = ADBDevice(serial: endpoint, ip: ip, port: port, state: .device)
                    self.refreshDeviceInfo()
                    ConnectionHistoryStore.shared.record(ip: ip, port: port)
                    finish(true, L("connect.success"))
                } else {
                    finish(false, "\(L("connect.failed")): \(state.isEmpty ? out : state)")
                }
            }
        } else {
            let msg = out.isEmpty ? L("connect.failed") : out.trimmed
            finish(false, msg)
        }
    }

    func disconnect() {
        guard let d = device else { return }
        busyCount += 1
        ADBEngine.shared.run(["disconnect", d.serial]) { _ in
            DispatchQueue.main.async {
                self.busyCount -= 1
                self.device = nil
            }
        }
    }

    // MARK: - 设备信息

    func refreshDeviceInfo() {
        guard let serial = serial else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        busyCount += 1

        let script = """
        getprop ro.product.model; getprop ro.product.brand; getprop ro.product.manufacturer; \
        getprop ro.build.version.release; getprop ro.build.version.sdk; getprop ro.product.cpu.abi; \
        getprop ro.serialno; dumpsys battery; wm size; wm density
        """
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: script)) { result in
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.busyCount -= 1
                guard var d = self.device else { return }
                let parsed = DeviceService.parseInfo(result.output)
                d.model = parsed["model"] ?? d.model
                d.brand = parsed["brand"] ?? d.brand
                d.manufacturer = parsed["manufacturer"] ?? d.manufacturer
                d.androidVersion = parsed["android"] ?? d.androidVersion
                d.sdkVersion = parsed["sdk"] ?? d.sdkVersion
                d.cpuAbi = parsed["abi"] ?? d.cpuAbi
                d.deviceSerial = parsed["serialno"] ?? d.deviceSerial
                if let lvl = parsed["batteryLevel"].flatMap(Int.init) { d.batteryLevel = lvl }
                if let st = parsed["batteryStatus"] { d.batteryStatus = st }
                if let r = parsed["resolution"] { d.resolution = r }
                if let dd = parsed["density"] { d.density = dd }
                self.device = d
            }
        }
    }

    private func refreshDeviceInfoIfNeeded() {
        guard let d = device, d.state == .device else { return }
        refreshDeviceInfo()
    }

    // MARK: - 自动连接 / 保持连接

    func autoConnectIfNeeded() {
        guard SettingsStore.shared.autoConnect, device == nil else { return }
        guard let profile = ConnectionHistoryStore.shared.mostRecent else { return }
        connect(ip: profile.ip, port: profile.port)
    }

    func setupKeepAlive() {
        keepAliveTimer?.invalidate()
        guard SettingsStore.shared.keepAlive else { return }
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self, let serial = self.serial else { return }
            if self.device?.state == .offline || self.device?.state == .unknown {
                // 重连尝试
                if let d = self.device {
                    self.connect(ip: d.ip, port: d.port)
                }
            } else {
                ADBEngine.shared.run(["-s", serial, "get-state"]) { st in
                    DispatchQueue.main.async {
                        if st.output.trimmed != "device" {
                            if var d = self.device { d.state = .offline; self.device = d }
                        }
                    }
                }
            }
        }
        keepAliveTimer?.tolerance = 5
    }

    func startKeepAliveIfNeeded() {
        setupKeepAlive()
    }
}

// MARK: - 设备信息服务

enum DeviceService {

    /// 解析设备信息脚本输出
    static func parseInfo(_ raw: String) -> [String: String] {
        var out: [String: String] = [:]
        for line in raw.split(separator: "\n").map(String.init) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("[ro.product.model]") { out["model"] = extractProp(t) }
            else if t.hasPrefix("[ro.product.brand]") { out["brand"] = extractProp(t) }
            else if t.hasPrefix("[ro.product.manufacturer]") { out["manufacturer"] = extractProp(t) }
            else if t.hasPrefix("[ro.build.version.release]") { out["android"] = extractProp(t) }
            else if t.hasPrefix("[ro.build.version.sdk]") { out["sdk"] = extractProp(t) }
            else if t.hasPrefix("[ro.product.cpu.abi]") { out["abi"] = extractProp(t) }
            else if t.hasPrefix("[ro.serialno]") { out["serialno"] = extractProp(t) }
            else if t.hasPrefix("Physical size") { out["resolution"] = t.replacingOccurrences(of: "Physical size:", with: "").trimmingCharacters(in: .whitespaces) }
            else if t.hasPrefix("Override size") { out["resolution"] = t.replacingOccurrences(of: "Override size:", with: "").trimmingCharacters(in: .whitespaces) }
            else if t.hasPrefix("Physical density") { out["density"] = t.replacingOccurrences(of: "Physical density:", with: "").trimmingCharacters(in: .whitespaces) }
            else if t.hasPrefix("Override density") { out["density"] = t.replacingOccurrences(of: "Override density:", with: "").trimmingCharacters(in: .whitespaces) }
            else if t.hasPrefix("level:") { out["batteryLevel"] = t.replacingOccurrences(of: "level:", with: "").trimmingCharacters(in: .whitespaces) }
            else if t.hasPrefix("status:") {
                let code = t.replacingOccurrences(of: "status:", with: "").trimmingCharacters(in: .whitespaces)
                out["batteryStatus"] = batteryStatusText(code)
            }
        }
        return out
    }

    private static func extractProp(_ line: String) -> String {
        // [ro.product.model]: [Pixel 7]
        guard let range = line.range(of: "]: [") else { return "" }
        var v = String(line[range.upperBound...])
        if v.hasSuffix("]") { v.removeLast() }
        return v
    }

    private static func batteryStatusText(_ code: String) -> String {
        switch code {
        case "1": return "unknown"
        case "2": return "charging"
        case "3": return "discharging"
        case "4": return "not charging"
        case "5": return "full"
        default: return code
        }
    }
}

// MARK: - 连接历史

final class ConnectionHistoryStore: ObservableObject {
    static let shared = ConnectionHistoryStore()
    @Published private(set) var profiles: [ConnectionProfile] = []

    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        .appendingPathComponent("kaka_connections.json")

    private init() { load() }

    var mostRecent: ConnectionProfile? { profiles.first }

    func record(ip: String, port: Int) {
        var list = profiles.filter { $0.ip != ip || $0.port != port }
        list.insert(ConnectionProfile(ip: ip, port: port, lastConnected: Date()), at: 0)
        if list.count > 20 { list = Array(list.prefix(20)) }
        profiles = list
        save()
    }

    func remove(_ profile: ConnectionProfile) {
        profiles.removeAll { $0.id == profile.id }
        save()
    }

    func clear() {
        profiles = []
        save()
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([ConnectionProfile].self, from: data) {
            profiles = list
        }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
