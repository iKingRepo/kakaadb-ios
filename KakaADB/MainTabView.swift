//
//  MainTabView.swift
//  主导航（对标 Scarab 六 Tab）+ 全局路由 + Toast 中心
//
import SwiftUI
import Combine

// MARK: - Tab

enum AppTab: String, CaseIterable {
    case home, apps, files, commands, remote, settings

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .apps: return "square.grid.2x2.fill"
        case .files: return "folder.fill"
        case .commands: return "terminal.fill"
        case .remote: return "tv.fill"
        case .settings: return "gearshape.fill"
        }
    }
    var title: String {
        switch self {
        case .home: return L("tab.home")
        case .apps: return L("tab.apps")
        case .files: return L("tab.files")
        case .commands: return L("tab.commands")
        case .remote: return L("tab.remote")
        case .settings: return L("tab.settings")
        }
    }
}

// MARK: - 全局路由

final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var selectedTab: AppTab = .home
    @Published var showConnect = false
    @Published var showDeviceInfo = false
    @Published var showTerminal = false
    @Published var appsPickInstall = false
    @Published var showHistory = false
    @Published var showPro = false
}

// MARK: - Toast

final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published var message: String?
    private var task: DispatchWorkItem?

    func show(_ msg: String) {
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.25)) { self?.message = nil }
        }
        task?.cancel()
        task = work
        withAnimation(.easeIn(duration: 0.2)) { self.message = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }
}

struct ToastModifier: ViewModifier {
    @ObservedObject var center = ToastCenter.shared
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let msg = center.message {
                KakaToastView(message: msg)
                    .padding(.bottom, 30)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
}

extension View {
    func kakaToast() -> some View { modifier(ToastModifier()) }
}

// MARK: - 主界面

struct MainTabView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.icon) }
                .tag(AppTab.home)
            AppsView()
                .tabItem { Label(AppTab.apps.title, systemImage: AppTab.apps.icon) }
                .tag(AppTab.apps)
            FilesView()
                .tabItem { Label(AppTab.files.title, systemImage: AppTab.files.icon) }
                .tag(AppTab.files)
            CommandsView()
                .tabItem { Label(AppTab.commands.title, systemImage: AppTab.commands.icon) }
                .tag(AppTab.commands)
            RemoteView()
                .tabItem { Label(AppTab.remote.title, systemImage: AppTab.remote.icon) }
                .tag(AppTab.remote)
            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
        .tint(Color.kakaBlueDeep)
        .sheet(isPresented: $router.showConnect) { ConnectView() }
        .sheet(isPresented: $router.showDeviceInfo) { DeviceInfoView() }
        .sheet(isPresented: $router.showTerminal) { TerminalView() }
        .sheet(isPresented: $router.showHistory) { HistoryView() }
        .sheet(isPresented: $router.showPro) { ProView() }
        .kakaToast()
    }
}
