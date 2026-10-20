//
//  SettingsView.swift
//  设置：连接/通用/数据/帮助/关于 + 设备信息 + 帮助中心 + Pro（对标 Scarab）
//
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var router: AppRouter

    @State private var showClearConfirm = false
    @State private var showResetConfirm = false
    @State private var helpItem: HelpItem?
    @State private var showAbout = false
    @State private var showShare = false

    enum HelpItem: String, CaseIterable, Identifiable {
        case quickStart = "help.quick.start.title"
        case faq = "help.faq.title"
        case security = "help.security.title"
        case features = "help.features.title"  // 占位（文案无此键，用内容兜底）

        var id: String { rawValue }

        var title: String {
            switch self {
            case .quickStart: return L("help.quick.start.title")
            case .faq: return L("help.faq.title")
            case .security: return L("help.security.title")
            case .features: return L("help.subtitle")
            }
        }
        var content: String {
            switch self {
            case .quickStart: return L("help.quick.start.content")
            case .faq: return L("help.faq.content")
            case .security: return L("help.security.content")
            case .features: return L("help.features.content")
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Pro
                Section {
                    Button {
                        router.showPro = true
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Color.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("settings.pro"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.kakaTextPrimary)
                                Text(settings.proUnlocked ? L("pro.header.subscribed") : L("pro.required.upgrade"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.kakaTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.kakaTextSecondary.opacity(0.6))
                        }
                    }
                }

                // 连接
                Section(L("settings.connection")) {
                    Toggle(L("settings.auto.connect"), isOn: $settings.autoConnect)
                    Toggle(L("settings.keep.alive"), isOn: $settings.keepAlive)
                        .onChange(of: settings.keepAlive) { _, _ in
                            session.startKeepAliveIfNeeded()
                        }
                    HStack {
                        Text(L("connect.port.placeholder"))
                        Spacer()
                        Picker("", selection: $settings.defaultPort) {
                            Text("5555").tag(5555)
                            Text("5556").tag(5556)
                            Text("5557").tag(5557)
                            Text("5037").tag(5037)
                        }
                        .pickerStyle(.menu)
                    }
                }

                // 通用
                Section(L("settings.general")) {
                    Picker(L("settings.theme"), selection: $settings.themeRaw) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                    Picker(L("settings.language"), selection: $settings.languageRaw) {
                        Text("跟随系统").tag("")
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }
                    .onChange(of: settings.languageRaw) { _, newValue in
                        guard !newValue.isEmpty else { return }
                        UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                        UserDefaults.standard.synchronize()
                        ToastCenter.shared.show("重启应用后生效")
                    }
                }

                // 数据
                Section(L("settings.data")) {
                    Button {
                        showClearConfirm = true
                    } label: {
                        HStack {
                            Text(L("settings.clear.history"))
                                .foregroundStyle(Color.kakaTextPrimary)
                            Spacer()
                            Text(L("settings.clear.history.description"))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.kakaTextSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                // 帮助
                Section(L("settings.help")) {
                    ForEach(HelpItem.allCases, id: \.self) { item in
                        Button {
                            helpItem = item
                        } label: {
                            HStack {
                                Text(item.title)
                                    .foregroundStyle(Color.kakaTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.kakaTextSecondary.opacity(0.6))
                            }
                        }
                    }
                }

                // 关于
                Section(L("settings.about")) {
                    HStack {
                        Text(L("settings.version"))
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(Color.kakaTextSecondary)
                    }
                    Button {
                        showShare = true
                    } label: {
                        HStack {
                            Text(L("settings.share"))
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.kakaTextSecondary.opacity(0.6))
                        }
                    }
                    Button {
                        // 侧载版无 App Store 评分，直接提示
                        ToastCenter.shared.show(L("alert.rate_message"))
                    } label: {
                        HStack {
                            Text(L("settings.rate"))
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundStyle(Color.orange)
                        }
                    }
                    Button {
                        showAbout = true
                    } label: {
                        HStack {
                            Text(L("settings.about"))
                            Spacer()
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.kakaTextSecondary.opacity(0.6))
                        }
                    }
                }

                // 恢复默认
                Section {
                    Button {
                        showResetConfirm = true
                    } label: {
                        Text(L("settings.reset.settings"))
                            .foregroundStyle(Color.kakaDanger)
                    }
                }
            }
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $helpItem) { item in
                HelpStepsView(title: item.title, content: item.content)
            }
            .sheet(isPresented: $showAbout) { AboutView() }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: ["\(L("app.name")) \(appVersion) - \(L("app.tagline"))"])
            }
            .confirmationDialog(L("settings.clear.history.confirm.title"), isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button(L("settings.clear.history.confirm.action"), role: .destructive) {
                    HistoryStore.shared.clearAll()
                    ToastCenter.shared.show(L("toast.success"))
                }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("settings.clear.history.confirm.message"))
            }
            .confirmationDialog(L("settings.reset.settings.confirm.title"), isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button(L("settings.reset.settings.confirm.action"), role: .destructive) {
                    settings.resetAll()
                    ToastCenter.shared.show(L("toast.success"))
                }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("settings.reset.settings.confirm.message"))
            }
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "3.0.0"
    }
}

// MARK: - 设备信息

struct DeviceInfoView: View {
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let d = session.device {
                        KakaCard {
                            VStack(spacing: 10) {
                                infoRow(key: L("device.info.model"), value: d.model.isEmpty ? L("common.not.available") : d.model)
                                Divider().overlay(Color.kakaDivider)
                                infoRow(key: L("device.info.brand"), value: d.brand.isEmpty ? L("common.not.available") : d.brand)
                                Divider().overlay(Color.kakaDivider)
                                infoRow(key: L("device.info.system.version"), value: d.androidVersion.isEmpty ? L("common.not.available") : "Android \(d.androidVersion)")
                                Divider().overlay(Color.kakaDivider)
                                infoRow(key: L("device.info.sdk.version"), value: d.sdkVersion.isEmpty ? L("common.not.available") : d.sdkVersion)
                                Divider().overlay(Color.kakaDivider)
                                infoRow(key: L("device.info.serial.number"), value: d.deviceSerial.isEmpty ? L("common.not.available") : d.deviceSerial)
                                Divider().overlay(Color.kakaDivider)
                                infoRow(key: L("device.info.cpu.architecture"), value: d.cpuAbi.isEmpty ? L("common.not.available") : d.cpuAbi)
                                Divider().overlay(Color.kakaDivider)
                                infoRow(key: L("device.info.screen.resolution"), value: d.resolution.isEmpty ? L("common.not.available") : d.resolution)
                                Divider().overlay(Color.kakaDivider)
                                infoRow(key: L("device.info.screen.density"), value: d.density.isEmpty ? L("common.not.available") : d.density)
                                Divider().overlay(Color.kakaDivider)
                                infoRow(key: L("common.battery"), value: d.batteryLevel.map { "\($0)%" } ?? L("common.not.available"))
                                Divider().overlay(Color.kakaDivider)
                                infoRow(key: L("device.info.connection.type"), value: "WiFi (ADB)")
                            }
                        }
                    } else {
                        Text(L("device.info.unavailable"))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.kakaTextSecondary)
                    }
                }
                .padding(16)
            }
            .background(Color.kakaBackground)
            .navigationTitle(L("commands.device.info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.refreshDeviceInfo()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.kakaBlueDeep)
                    }
                }
            }
        }
    }

    private func infoRow(key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 14))
                .foregroundStyle(Color.kakaTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.kakaTextPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - 关于

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(KakaTheme.primaryGradient)
                        .frame(width: 84, height: 84)
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
                Text(L("app.name"))
                    .font(.system(size: 22, weight: .bold))
                Text(L("app.tagline"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kakaTextSecondary)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0")")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.kakaTextSecondary)

                VStack(spacing: 8) {
                    Text("ADB 引擎：adb-mobile（AOSP adb 35.0.2 移植）")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.kakaTextSecondary)
                    Text("UI 深度对标 Scarab（甲壳虫）")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.kakaTextSecondary)
                }
                .padding(14)
                .background(Color.kakaCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()
            }
            .padding(.top, 40)
            .background(Color.kakaBackground)
            .navigationTitle(L("settings.about"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Pro（侧载版本地解锁）

struct ProView: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Hero
                    VStack(spacing: 10) {
                        Text(L("pro.header.title"))
                            .font(.system(size: 26, weight: .bold))
                        Text("\(L("pro.hero.headline.prefix"))\(L("pro.hero.headline.highlight"))\(L("pro.hero.headline.suffix"))")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.kakaTextSecondary)
                        Text(L("pro.hero.subtitle"))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.kakaTextSecondary)
                        if settings.proUnlocked {
                            Label(L("pro.badge.subscribed"), systemImage: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.kakaSuccess)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(KakaTheme.primaryGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))

                    // 功能列表
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L("pro.features.title"))
                            .font(.system(size: 17, weight: .bold))
                        featureRow(icon: "square.and.arrow.down.fill", title: L("pro.feature.apps"), desc: L("pro.feature.apps.desc"))
                        featureRow(icon: "folder.fill", title: L("pro.feature.files"), desc: L("pro.feature.files.desc"))
                        featureRow(icon: "terminal.fill", title: L("pro.feature.shell"), desc: L("pro.feature.shell.desc"))
                        featureRow(icon: "tv.fill", title: L("pro.feature.remote"), desc: L("pro.feature.remote"))
                        featureRow(icon: "sparkles", title: L("pro.feature.updates"), desc: L("pro.feature.updates.desc"))
                    }
                    .padding(16)
                    .background(Color.kakaCard)
                    .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))

                    // 方案
                    VStack(spacing: 10) {
                        planRow(icon: "clock.badge.checkmark", title: L("pro.plan.trial.title"), desc: L("pro.trial.description"))
                        planRow(icon: "calendar", title: L("pro.period.week"), desc: L("pro.period.week"))
                        planRow(icon: "calendar.circle", title: L("pro.period.year"), desc: L("pro.period.year"))
                        planRow(icon: "infinity", title: L("pro.plan.lifetime.title"), desc: L("pro.lifetime.description"))
                    }
                    .padding(16)
                    .background(Color.kakaCard)
                    .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))

                    // 说明
                    VStack(spacing: 6) {
                        Text(L("pro.terms.title"))
                            .font(.system(size: 13, weight: .bold))
                        Text(L("pro.terms.1"))
                            .font(.system(size: 11))
                        Text(L("pro.terms.2"))
                            .font(.system(size: 11))
                        Text(L("pro.terms.3"))
                            .font(.system(size: 11))
                        Text(L("pro.terms.4"))
                            .font(.system(size: 11))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.kakaTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.kakaCard)
                    .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
                }
                .padding(16)
            }
            .background(Color.kakaBackground)
            .navigationTitle(L("pro.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.kakaBlueDeep)
                .frame(width: 34, height: 34)
                .background(Color.kakaBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.kakaTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private func planRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.kakaBlueDeep)
                .frame(width: 30)
            Text(title)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Text(desc)
                .font(.system(size: 11))
                .foregroundStyle(Color.kakaTextSecondary)
        }
        .padding(.vertical, 4)
    }
}
