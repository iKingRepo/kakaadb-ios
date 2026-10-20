//
//  Stores.swift
//  设置存储（@AppStorage）+ 操作历史存储（JSON 持久化）
//
import Foundation
import Combine
import SwiftUI

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("kaka.autoConnect") var autoConnect: Bool = true
    @AppStorage("kaka.keepAlive") var keepAlive: Bool = false
    @AppStorage("kaka.defaultPort") var defaultPort: Int = 5555
    @AppStorage("kaka.theme") var themeRaw: String = "system"   // system/light/dark
    @AppStorage("kaka.language") var languageRaw: String = ""   // ""跟随系统 / zh-Hans / en
    @AppStorage("kaka.proUnlocked") var proUnlocked: Bool = true  // 侧载版默认解锁全部功能
    @AppStorage("kaka.hideSystemApps") var hideSystemApps: Bool = true

    enum ThemeMode: String, CaseIterable {
        case system, light, dark
        var label: String {
            switch self {
            case .system: return L("settings.theme")
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }
    }

    var theme: ThemeMode { ThemeMode(rawValue: themeRaw) ?? .system }

    func resetAll() {
        autoConnect = true
        keepAlive = false
        defaultPort = 5555
        themeRaw = "system"
        languageRaw = ""
        hideSystemApps = true
        ConnectionHistoryStore.shared.clear()
        HistoryStore.shared.clearAll()
    }
}

// MARK: - 操作历史

final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    @Published private(set) var items: [HistoryItem] = []

    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        .appendingPathComponent("kaka_history.json")

    private init() { load() }

    @discardableResult
    func add(type: HistoryType, title: String, detail: String, status: HistoryStatus = .success) -> HistoryItem {
        let item = HistoryItem(id: UUID(), type: type, title: title, detail: detail, date: Date(), status: status)
        items.insert(item, at: 0)
        if items.count > 200 { items = Array(items.prefix(200)) }
        save()
        return item
    }

    func updateStatus(id: UUID, status: HistoryStatus) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].status = status
        save()
    }

    func clearAll() {
        items = []
        save()
    }

    /// 分组：今天 / 昨天 / 更早
    func sections() -> [(title: String, items: [HistoryItem])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        var todayItems: [HistoryItem] = []
        var yesterdayItems: [HistoryItem] = []
        var older: [HistoryItem] = []
        for item in items {
            let day = cal.startOfDay(for: item.date)
            if day == today { todayItems.append(item) }
            else if day == yesterday { yesterdayItems.append(item) }
            else { older.append(item) }
        }
        var result: [(title: String, items: [HistoryItem])] = []
        if !todayItems.isEmpty { result.append((L("history.today"), todayItems)) }
        if !yesterdayItems.isEmpty { result.append((L("history.yesterday"), yesterdayItems)) }
        if !older.isEmpty { result.append(("", older)) }
        return result
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = list
        }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

// MARK: - 通用工具

enum HistoryFactory {
    static func typeLabel(_ type: HistoryType) -> String {
        switch type {
        case .shell: return L("history.type.shell")
        case .install: return L("history.type.install")
        case .uninstall: return L("history.type.uninstall")
        case .file: return L("history.type.file")
        case .screenshot: return L("history.type.screenshot")
        case .screenRecord: return L("history.type.screen.record")
        case .logcat: return L("history.type.logcat")
        case .other: return L("history.type.other")
        }
    }
}
