//
//  KakaADBApp.swift
//  应用入口：初始化原生 ADB 引擎 + 全局会话 + 主界面
//
import SwiftUI

@main
struct KakaADBApp: App {
    @StateObject private var session = Session.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var router = AppRouter.shared

    init() {
        ADBEngine.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(session)
                .environmentObject(settings)
                .environmentObject(router)
                .environmentObject(HistoryStore.shared)
                .preferredColorScheme(settings.theme == .light ? .light : settings.theme == .dark ? .dark : nil)
                .onAppear {
                    session.autoConnectIfNeeded()
                    session.startKeepAliveIfNeeded()
                }
        }
    }
}
