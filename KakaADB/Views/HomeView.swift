//
//  HomeView.swift
//  首页：设备状态卡 + 快捷操作 + 最近操作（对标 Scarab）
//
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var history: HistoryStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    deviceCard
                    quickActions
                    recentActions
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.kakaBackground)
            .navigationTitle(L("app.name"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Color.kakaBlueDeep)
                    }
                }
            }
            .onAppear {
                if let device = session.device, device.state == .device {
                    session.refreshDeviceInfo()
                }
            }
        }
    }

    // MARK: - 设备状态卡

    private var deviceCard: some View {
        Group {
            if let device = session.device {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.displayName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            Text("\(device.ip):\(device.port)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        batteryBadge(device)
                    }
                    Divider().background(.white.opacity(0.25))
                    HStack(spacing: 16) {
                        statusRow(icon: "antenna.radiowaves.left.and.right",
                                  text: stateText(device.state))
                        statusRow(icon: "iphone.gen3",
                                  text: device.androidVersion.isEmpty ? L("device.info.system.version") : "Android \(device.androidVersion)")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                }
                .padding(18)
                .background(KakaTheme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
                .shadow(color: Color.kakaBlueDeep.opacity(0.3), radius: 12, x: 0, y: 6)
                .overlay(alignment: .topTrailing) {
                    Button {
                        session.disconnect()
                        ToastCenter.shared.show(L("home.device.disconnected"))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(12)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.kakaBlue.opacity(0.6))
                    Text(L("home.no.device"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.kakaTextSecondary)
                    Button {
                        router.showConnect = true
                    } label: {
                        Label(L("home.connect.device"), systemImage: "link")
                    }
                    .buttonStyle(KakaPrimaryButtonStyle())
                    .frame(maxWidth: 260)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.kakaCard)
                .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
            }
        }
    }

    private func batteryBadge(_ device: ADBDevice) -> some View {
        HStack(spacing: 4) {
            if let level = device.batteryLevel {
                Image(systemName: level > 20 ? "battery.75" : "battery.25")
                Text("\(level)%")
            } else {
                Image(systemName: "battery.75")
                Text(L("common.not.available"))
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.18))
        .clipShape(Capsule())
    }

    private func statusRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
    }

    private func stateText(_ state: ADBConnectState) -> String {
        switch state {
        case .device: return L("home.device.connected")
        case .connecting: return "connecting"
        case .authorizing: return "authorizing"
        case .unauthorized: return "unauthorized"
        case .offline, .unknown: return L("home.device.disconnected")
        default: return state.rawValue
        }
    }

    // MARK: - 快捷操作

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("home.quick.actions"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.kakaTextPrimary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                actionTile(icon: "square.and.arrow.down.fill", title: L("home.action.install"),
                           desc: L("home.action.install.description"), enabled: session.connected) {
                    if session.connected { router.selectedTab = .apps; router.appsPickInstall = true }
                    else { router.showConnect = true }
                }
                actionTile(icon: "camera.viewfinder", title: L("home.action.screenshot"),
                           desc: L("commands.screenshot"), enabled: session.connected) {
                    router.selectedTab = .commands
                    NotificationCenter.default.post(name: Notification.Name("KakaRunScreenshot"), object: nil)
                }
                actionTile(icon: "terminal.fill", title: L("commands.shell.terminal"),
                           desc: L("commands.shell.description"), enabled: session.connected) {
                    router.showTerminal = true
                }
                actionTile(icon: "folder.fill", title: L("home.action.files"),
                           desc: L("home.action.files.description"), enabled: session.connected) {
                    router.selectedTab = .files
                }
                actionTile(icon: "info.circle.fill", title: L("commands.device.info"),
                           desc: L("device.info.description"), enabled: session.connected) {
                    router.showDeviceInfo = true
                }
                actionTile(icon: "tv.fill", title: L("tab.remote"),
                           desc: L("home.action.remote.description"), enabled: session.connected) {
                    router.selectedTab = .remote
                }
            }
        }
        .padding(16)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
    }

    private func actionTile(icon: String, title: String, desc: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.kakaBlueDeep)
                    Spacer()
                    if !enabled {
                        Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(Color.gray.opacity(0.5))
                    }
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.kakaTextPrimary)
                    .lineLimit(1)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.kakaTextSecondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(Color.kakaBackground.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: KakaTheme.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.75)
    }

    // MARK: - 最近操作

    private var recentActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("home.recent.actions"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.kakaTextPrimary)
                Spacer()
                Button {
                    router.showHistory = true
                } label: {
                    Text(L("home.view.all"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.kakaBlueDeep)
                }
            }
            if history.items.isEmpty {
                Text(L("history.empty"))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.kakaTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                ForEach(history.items.prefix(5)) { item in
                    HStack(spacing: 10) {
                        Image(systemName: iconFor(item.type))
                            .font(.system(size: 15))
                            .foregroundStyle(Color.kakaBlueDeep)
                            .frame(width: 30, height: 30)
                            .background(Color.kakaBackground)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.kakaTextPrimary)
                                .lineLimit(1)
                            Text(HistoryFactory.typeLabel(item.type) + " · " + timeText(item.date))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.kakaTextSecondary)
                        }
                        Spacer()
                        statusDot(item.status)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
    }

    private func iconFor(_ type: HistoryType) -> String {
        switch type {
        case .install: return "square.and.arrow.down.fill"
        case .uninstall: return "trash.fill"
        case .file: return "folder.fill"
        case .screenshot: return "camera.viewfinder"
        case .screenRecord: return "video.fill"
        case .logcat: return "doc.text.fill"
        case .shell: return "terminal.fill"
        case .other: return "circle.fill"
        }
    }

    private func statusDot(_ status: HistoryStatus) -> some View {
        Circle()
            .fill(status == .success ? Color.kakaSuccess : status == .failed ? Color.kakaDanger : Color.orange)
            .frame(width: 8, height: 8)
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
