//
//  AppsView.swift
//  应用管理：列表/搜索/系统应用徽标/安装/卸载/清除数据/强制停止（对标 Scarab）
//
import SwiftUI
import UniformTypeIdentifiers

struct AppsView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var history: HistoryStore

    @State private var apps: [InstalledApp] = []
    @State private var search = ""
    @State private var loading = true
    @State private var loadError: String?
    @State private var showSystem = false
    @State private var busyPkg: String?
    @State private var busyText = ""
    @State private var showBusy = false
    @State private var pickAPK = false
    @State private var installing = false

    @State private var pendingAction: PendingAppAction?
    @State private var showConfirm = false

    private var filtered: [InstalledApp] {
        var list = apps
        if !showSystem { list = list.filter { !$0.isSystem } }
        if !search.isEmpty {
            list = list.filter { $0.package.lowercased().contains(search.lowercased()) }
        }
        return list
    }

    private var hiddenCount: Int {
        showSystem ? 0 : apps.filter { $0.isSystem }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView(L("apps.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.kakaDanger)
                        Text(loadError)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.kakaTextSecondary)
                        Button(L("common.refresh")) { load() }
                            .buttonStyle(KakaOutlineButtonStyle())
                            .frame(maxWidth: 200)
                    }
                } else {
                    appList
                }
            }
            .navigationTitle(L("apps.title"))
            .background(Color.kakaBackground)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        router.appsPickInstall = false
                        pickAPK = true
                    } label: {
                        Image(systemName: "square.and.arrow.down.fill")
                            .foregroundStyle(Color.kakaBlueDeep)
                    }
                    .disabled(!session.connected)
                }
            }
            .fileImporter(isPresented: $pickAPK, allowedContentTypes: [.init(filenameExtension: "apk")!],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    installAPK(from: url)
                }
            }
            .onAppear { if apps.isEmpty { load() } }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KakaRunInstall"))) { _ in
                pickAPK = true
            }
            .onChange(of: router.appsPickInstall) { _, newValue in
                if newValue {
                    router.appsPickInstall = false
                    pickAPK = true
                }
            }
            .overlay {
                if showBusy {
                    KakaLoading(text: busyText)
                }
            }
            .confirmationDialog(pendingAction?.title ?? "", isPresented: $showConfirm, titleVisibility: .visible) {
                if let action = pendingAction {
                    Button(action.buttonLabel, role: .destructive) { execute(action) }
                    Button(L("common.cancel"), role: .cancel) {}
                }
            } message: {
                Text(pendingAction?.message ?? "")
            }
            .onDisappear { busyPkg = nil }
        }
    }

    // MARK: - 列表

    private var appList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.kakaTextSecondary)
                    TextField(L("apps.search.placeholder"), text: $search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.kakaCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    showSystem.toggle()
                } label: {
                    Text(L("apps.show.system"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(showSystem ? .white : Color.kakaBlueDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(showSystem ? Color.kakaBlueDeep : Color.kakaCard)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if hiddenCount > 0 {
                Text(L("apps.system.hidden.count", hiddenCount))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.kakaTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    if filtered.isEmpty {
                        Text(apps.isEmpty ? L("apps.empty") : L("apps.no.matches"))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.kakaTextSecondary)
                            .padding(.top, 60)
                    } else {
                        Text(L("apps.count", filtered.count))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.kakaTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        ForEach(filtered) { app in
                            AppRowView(app: app, busy: busyPkg == app.package) {
                                menu(for: app)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color.kakaBackground)
    }

    private func menu(for app: InstalledApp) -> [AppAction] {
        [
            AppAction(title: L("apps.action.uninstall"), icon: "trash", destructive: true) {
                pendingAction = PendingAppAction(type: .uninstall, app: app)
                showConfirm = true
            },
            AppAction(title: L("apps.action.clear.data"), icon: "broom") {
                pendingAction = PendingAppAction(type: .clear, app: app)
                showConfirm = true
            },
            AppAction(title: L("apps.action.force.stop"), icon: "stop.circle") {
                pendingAction = PendingAppAction(type: .forceStop, app: app)
                showConfirm = true
            },
        ]
    }

    // MARK: - 数据

    private func load() {
        guard let serial = session.serial else { return }
        loading = true
        loadError = nil
        AppManagerService.shared.loadApps(serial: serial) { result in
            DispatchQueue.main.async {
                loading = false
                switch result {
                case .success(let list): apps = list
                case .failure(let err): loadError = err
                }
            }
        }
    }

    // MARK: - 安装

    private func installAPK(from url: URL) {
        guard let serial = session.serial else { return }
        let name = url.lastPathComponent.isEmpty ? "app.apk" : url.lastPathComponent
        let dest = FileService.uploadsDir().appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            ToastCenter.shared.show(L("apps.install.failed"))
            return
        }
        installing = true
        busyText = L("apps.installing")
        showBusy = true
        let item = history.add(type: .install, title: name, detail: serial, status: .running)
        AppManagerService.shared.install(apkPath: dest.path, serial: serial) { result in
            DispatchQueue.main.async {
                installing = false
                showBusy = false
                switch result {
                case .success(let msg):
                    history.updateStatus(id: item.id, status: .success)
                    ToastCenter.shared.show(L("apps.installed", name))
                    load()
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    ToastCenter.shared.show(err)
                }
            }
        }
    }

    // MARK: - 操作

    private func execute(_ action: PendingAppAction) {
        guard let serial = session.serial else { return }
        busyPkg = action.app.package
        busyText = action.busyText
        showBusy = true
        let item = history.add(type: action.historyType, title: action.app.package, detail: serial, status: .running)
        let done: (Result<String, String>) -> Void = { result in
            DispatchQueue.main.async {
                busyPkg = nil
                showBusy = false
                switch result {
                case .success(let msg):
                    history.updateStatus(id: item.id, status: .success)
                    ToastCenter.shared.show(msg)
                    if action.type == .uninstall { load() }
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    ToastCenter.shared.show(err)
                }
            }
        }
        switch action.type {
        case .uninstall: AppManagerService.shared.uninstall(pkg: action.app.package, serial: serial, completion: done)
        case .clear: AppManagerService.shared.clearData(pkg: action.app.package, serial: serial, completion: done)
        case .forceStop: AppManagerService.shared.forceStop(pkg: action.app.package, serial: serial, completion: done)
        }
    }
}

// MARK: - 行视图

struct AppRowView: View {
    let app: InstalledApp
    let busy: Bool
    let actions: () -> [AppAction]

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.kakaBlue.opacity(0.7), Color.kakaBlueDeep.opacity(0.7)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(String(app.package.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(app.package)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.kakaTextPrimary)
                    .lineLimit(1)
                if app.isSystem {
                    Text(L("apps.system.badge"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.kakaBlueDeep)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.kakaBlue.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Spacer()
            if busy {
                ProgressView()
            } else {
                Menu {
                    ForEach(actions(), id: \.title) { action in
                        Button(role: action.destructive ? .destructive : nil) { action.handler() } label: {
                            Label(action.title, systemImage: action.icon)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.kakaBlueDeep)
                }
            }
        }
        .padding(12)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.smallRadius, style: .continuous))
    }
}

struct AppAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    var destructive = false
    let handler: () -> Void
}

struct PendingAppAction {
    enum Kind { case uninstall, clear, forceStop }
    let type: Kind
    let app: InstalledApp

    var title: String {
        switch type {
        case .uninstall: return L("apps.confirm.uninstall.title")
        case .clear: return L("apps.confirm.clear.title")
        case .forceStop: return L("apps.confirm.force.stop.title")
        }
    }
    var message: String {
        switch type {
        case .uninstall: return L("apps.confirm.uninstall.message", app.package)
        case .clear: return L("apps.confirm.clear.message", app.package)
        case .forceStop: return L("apps.confirm.force.stop.message", app.package)
        }
    }
    var buttonLabel: String {
        switch type {
        case .uninstall: return L("apps.confirm.uninstall.action")
        case .clear: return L("apps.confirm.clear.action")
        case .forceStop: return L("apps.confirm.force.stop.action")
        }
    }
    var busyText: String {
        switch type {
        case .uninstall: return L("toast.loading")
        default: return L("toast.loading")
        }
    }
    var historyType: HistoryType {
        switch type {
        case .uninstall: return .uninstall
        default: return .other
        }
    }
}
