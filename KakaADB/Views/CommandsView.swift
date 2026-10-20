//
//  CommandsView.swift
//  命令中心：四大分类快捷命令 + 自定义命令 + 输出查看 + 截图/录屏（对标 Scarab）
//
import SwiftUI
import UIKit
import AVKit

struct CommandsView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var router: AppRouter

    @State private var outputText = ""
    @State private var outputTitle = ""
    @State private var showOutput = false
    @State private var busy = false
    @State private var customCommand = ""
    @State private var showParamInput = false
    @State private var paramCommand: QuickCommand?
    @State private var paramText = ""
    @State private var pendingConfirm: QuickCommand?
    @State private var showConfirm = false

    @State private var screenshotResult: ScreenshotService.CaptureResult?
    @State private var showScreenshot = false
    @State private var recordResult: ScreenshotService.CaptureResult?
    @State private var showRecord = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    quickCommandSection
                    customSection
                    ForEach(CommandCategory.allCases, id: \.self) { category in
                        categorySection(category)
                    }
                }
                .padding(16)
            }
            .background(Color.kakaBackground)
            .navigationTitle(L("commands.title"))
            .overlay {
                if busy { KakaLoading(text: "commands.executing") }
            }
            .sheet(isPresented: $showOutput) {
                CommandOutputView(title: outputTitle, text: outputText)
            }
            .sheet(isPresented: $showScreenshot) {
                if let result = screenshotResult {
                    ScreenshotPreviewView(result: result)
                }
            }
            .sheet(isPresented: $showRecord) {
                if let result = recordResult {
                    ScreenRecordPreviewView(result: result)
                }
            }
            .alert(L("commands.custom.command"), isPresented: $showParamInput) {
                TextField(L("commands.input.placeholder"), text: $paramText)
                Button(L("commands.execute")) {
                    if let cmd = paramCommand {
                        paramText = paramText.trimmingCharacters(in: .whitespaces)
                        run(cmd, param: paramText)
                    }
                }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("commands.input.description"))
            }
            .confirmationDialog("", isPresented: $showConfirm, titleVisibility: .visible) {
                if let cmd = pendingConfirm {
                    Button(L("commands.confirm.execute"), role: .destructive) {
                        run(cmd, param: "")
                    }
                    Button(L("common.cancel"), role: .cancel) {}
                }
            } message: {
                Text(pendingConfirm?.confirmKey.map { L($0) } ?? "")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KakaRunScreenshot"))) { _ in
                takeScreenshot()
            }
        }
    }

    // MARK: - 快捷命令

    private var quickCommandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("commands.quick.commands"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.kakaTextPrimary)
            HStack(spacing: 10) {
                Button {
                    takeScreenshot()
                } label: {
                    quickTile(icon: "camera.viewfinder", title: L("commands.screenshot"))
                }
                .disabled(!session.connected)
                Button {
                    router.showTerminal = true
                } label: {
                    quickTile(icon: "terminal.fill", title: L("commands.shell.terminal"))
                }
                .disabled(!session.connected)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quickTile(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color.kakaBlueDeep)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.kakaTextPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.smallRadius, style: .continuous))
    }

    // MARK: - 自定义命令

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("commands.custom.command"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.kakaTextPrimary)
            HStack(spacing: 10) {
                TextField(L("commands.shell.description"), text: $customCommand)
                    .font(.system(size: 14, weight: .medium))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.kakaBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .submitLabel(.go)
                    .onSubmit { runCustom() }
                Button {
                    runCustom()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(KakaTheme.primaryGradient)
                        .clipShape(Circle())
                }
                .disabled(customCommand.isEmpty || !session.connected)
            }
        }
        .padding(16)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
    }

    // MARK: - 分类

    private func categorySection(_ category: CommandCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L(category.rawValue))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.kakaTextPrimary)
                .padding(.top, 4)
            VStack(spacing: 0) {
                ForEach(CommandCatalog.commands(in: category)) { cmd in
                    Button {
                        tap(cmd)
                    } label: {
                        HStack {
                            Text(L(cmd.titleKey))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.kakaTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.kakaTextSecondary.opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Color.kakaCard)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.connected)
                    .opacity(session.connected ? 1 : 0.5)
                    if cmd.id != CommandCatalog.commands(in: category).last?.id {
                        Divider().padding(.leading, 14).overlay(Color.kakaDivider)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: KakaTheme.smallRadius, style: .continuous))
        }
    }

    // MARK: - 逻辑

    private func tap(_ cmd: QuickCommand) {
        guard session.connected else { return }
        if CommandExecutor.shared.isSpecial(cmd) {
            if cmd.id == "screenshot" { takeScreenshot() }
            else { takeScreenRecord() }
            return
        }
        if let confirm = cmd.confirmKey {
            pendingConfirm = cmd
            showConfirm = true
            return
        }
        if cmd.parameterKey != nil {
            paramCommand = cmd
            paramText = ""
            showParamInput = true
            return
        }
        run(cmd, param: "")
    }

    private func run(_ cmd: QuickCommand, param: String) {
        guard let serial = session.serial else { return }
        busy = true
        let item = history.add(type: .shell, title: L(cmd.titleKey), detail: serial, status: .running)
        CommandExecutor.shared.run(cmd, serial: serial, param: param) { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let out):
                    history.updateStatus(id: item.id, status: .success)
                    outputTitle = L(cmd.titleKey)
                    outputText = out
                    showOutput = true
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    outputTitle = L(cmd.titleKey)
                    outputText = err
                    showOutput = true
                }
            }
        }
    }

    private func runCustom() {
        guard let serial = session.serial else { return }
        let cmd = customCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        busy = true
        let item = history.add(type: .shell, title: cmd, detail: serial, status: .running)
        CommandExecutor.shared.runCustom(cmd, serial: serial) { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let out):
                    history.updateStatus(id: item.id, status: .success)
                    outputTitle = cmd
                    outputText = out
                    showOutput = true
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    outputTitle = cmd
                    outputText = err
                    showOutput = true
                }
            }
        }
    }

    // MARK: - 截图 / 录屏

    private func takeScreenshot() {
        guard let serial = session.serial else { return }
        busy = true
        let item = history.add(type: .screenshot, title: L("commands.screenshot"), detail: serial, status: .running)
        ScreenshotService.shared.captureScreenshot(serial: serial) { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let r):
                    history.updateStatus(id: item.id, status: .success)
                    screenshotResult = r
                    showScreenshot = true
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    ToastCenter.shared.show(err)
                }
            }
        }
    }

    private func takeScreenRecord() {
        guard let serial = session.serial else { return }
        busy = true
        let item = history.add(type: .screenRecord, title: L("commands.screen.record"), detail: serial, status: .running)
        ScreenshotService.shared.captureScreenRecord(serial: serial) { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let r):
                    history.updateStatus(id: item.id, status: .success)
                    recordResult = r
                    showRecord = true
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    ToastCenter.shared.show(err)
                }
            }
        }
    }
}

// MARK: - 输出查看

struct CommandOutputView: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(ADBEngine.truncate(text, limit: 4000))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.kakaTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(16)
            }
            .background(Color(red: 0.97, green: 0.98, blue: 0.99))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = text
                        ToastCenter.shared.show(L("toast.copied"))
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(Color.kakaBlueDeep)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - 截图预览

struct ScreenshotPreviewView: View {
    let result: ScreenshotService.CaptureResult
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image = result.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.kakaDanger)
                        Text(L("commands.screenshot.read.failed"))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.kakaTextSecondary)
                    }
                }
                HStack(spacing: 12) {
                    Button {
                        saveToPhotos()
                    } label: {
                        Label(L("commands.screenshot.save.photos"), systemImage: "photo.on.rectangle.angled")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(KakaTheme.primaryGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(saving || result.image == nil)

                    Button {
                        UIPasteboard.general.string = result.remotePath
                        ToastCenter.shared.show(L("toast.copied"))
                    } label: {
                        Label(L("commands.screenshot.copy.path"), systemImage: "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.kakaBackground)
                            .foregroundStyle(Color.kakaBlueDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        deleteDeviceFile()
                    } label: {
                        Label(L("commands.screenshot.delete"), systemImage: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.kakaDanger.opacity(0.12))
                            .foregroundStyle(Color.kakaDanger)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                Text(L("commands.screenshot.saved.device") + " " + result.remotePath)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.kakaTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .navigationTitle(L("commands.screenshot"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }

    private func saveToPhotos() {
        guard let image = result.image else { return }
        saving = true
        ScreenshotService.saveImageToPhotos(image) { ok, err in
            DispatchQueue.main.async {
                saving = false
                ToastCenter.shared.show(ok ? L("commands.screenshot.saved.photos") : err)
            }
        }
    }

    private func deleteDeviceFile() {
        if let serial = session.serial {
            ScreenshotService.deleteDeviceFile(serial: serial, remote: result.remotePath)
        }
        ToastCenter.shared.show(L("commands.screenshot.deleted"))
        dismiss()
    }
}

// MARK: - 录屏预览

struct ScreenRecordPreviewView: View {
    let result: ScreenshotService.CaptureResult
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let url = result.videoURL {
                    VideoPlayer(player: AVPlayer(url: url))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(maxHeight: 420)
                }
                Button {
                    saveToPhotos()
                } label: {
                    Label(L("commands.screenshot.save.photos"), systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(KakaTheme.primaryGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(saving)
                Text(result.remotePath)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.kakaTextSecondary)
                    .lineLimit(2)
            }
            .padding(20)
            .navigationTitle(L("commands.screen.record"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }

    private func saveToPhotos() {
        guard let url = result.videoURL else { return }
        saving = true
        ScreenshotService.saveVideoToPhotos(url) { ok, err in
            DispatchQueue.main.async {
                saving = false
                ToastCenter.shared.show(ok ? L("commands.screenshot.saved.photos") : err)
            }
        }
    }
}
