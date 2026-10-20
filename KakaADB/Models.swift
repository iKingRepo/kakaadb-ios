//
//  Models.swift
//  数据模型（对标 Scarab 功能域：设备/应用/文件/命令/历史/连接档案）
//
import Foundation

// MARK: - 设备

/// adb 连接状态（对应 adb transport 状态字符串）
enum ADBConnectState: String {
    case offline, device, connecting, authorizing, unauthorized
    case host, recovery, sideload, bootloader, noPermissions
    case unknown
    init(raw: String) { self = ADBConnectState(rawValue: raw) ?? .unknown }
}

struct ADBDevice: Identifiable, Equatable {
    var id: String { serial }
    var serial: String        // ip:port
    var ip: String
    var port: Int
    var model: String = ""
    var brand: String = ""
    var manufacturer: String = ""
    var androidVersion: String = ""
    var sdkVersion: String = ""
    var cpuAbi: String = ""
    var deviceSerial: String = ""
    var batteryLevel: Int? = nil
    var batteryStatus: String = ""
    var resolution: String = ""
    var density: String = ""
    var state: ADBConnectState = .connecting
    var displayName: String { model.isEmpty ? ip : model }
}

// MARK: - 已安装应用

struct InstalledApp: Identifiable, Equatable {
    var id: String { package }
    let package: String
    let path: String
    var isSystem: Bool { path.hasPrefix("/system/") || path.hasPrefix("/product/") || path.hasPrefix("/vendor/") || path.hasPrefix("/apex/") || path.hasPrefix("/oem/") }
}

// MARK: - 文件

struct FileItem: Identifiable, Equatable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
}

// MARK: - 快捷命令

enum CommandCategory: String, CaseIterable {
    case system = "commands.category.system"
    case network = "commands.category.network"
    case logs = "commands.category.logs"
    case advanced = "commands.category.advanced"
}

struct QuickCommand: Identifiable {
    let id: String
    let titleKey: String
    let category: CommandCategory
    let confirmKey: String?
    let parameterKey: String?        // 需要用户输入的参数提示
    let buildArgs: (String) -> [String]  // 参数 -> adb argv
}

// MARK: - 历史

enum HistoryType: String, Codable {
    case shell, install, uninstall, file, screenshot, screenRecord, logcat, other
}

enum HistoryStatus: String, Codable {
    case running, success, failed
}

struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: HistoryType
    let title: String
    let detail: String
    let date: Date
    var status: HistoryStatus
}

// MARK: - 连接档案

struct ConnectionProfile: Identifiable, Codable, Equatable {
    var id: String { "\(ip):\(port)" }
    let ip: String
    let port: Int
    var lastConnected: Date
}
