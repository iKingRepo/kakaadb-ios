//
//  FilesView.swift
//  文件管理：路径导航 + 快捷入口 + 上传/下载/重命名/删除/新建文件夹/保存到相册（对标 Scarab）
//
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Photos

struct FilesView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var history: HistoryStore

    @State private var path = "/sdcard"
    @State private var items: [FileItem] = []
    @State private var loading = false
    @State private var loadError: String?
    @State private var busyText = ""
    @State private var showBusy = false

    @State private var pickUpload = false
    @State private var showNewFolder = false
    @State private var folderName = ""
    @State private var renameTarget: FileItem?
    @State private var renameText = ""
    @State private var showRename = false
    @State private var deleteTarget: FileItem?
    @State private var showDelete = false
    @State private var shareURL: URL?
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            Group {
                if !session.connected {
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.kakaBlue.opacity(0.6))
                        Text(L("error.no.device"))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.kakaTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.kakaDanger)
                        Text(loadError)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.kakaTextSecondary)
                        Button(L("common.refresh")) { load() }
                            .buttonStyle(KakaOutlineButtonStyle())
                            .frame(maxWidth: 200)
                    }
                } else {
                    fileContent
                }
            }
            .navigationTitle(L("files.title"))
            .background(Color.kakaBackground)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        pickUpload = true
                    } label: {
                        Image(systemName: "square.and.arrow.up.fill")
                            .foregroundStyle(Color.kakaBlueDeep)
                    }
                    .disabled(!session.connected)
                    Button {
                        showNewFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(Color.kakaBlueDeep)
                    }
                    .disabled(!session.connected)
                }
            }
            .fileImporter(isPresented: $pickUpload, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    uploadFiles(urls)
                }
            }
            .overlay {
                if showBusy {
                    KakaLoading(text: busyText)
                }
            }
            .alert(L("files.new.folder.title"), isPresented: $showNewFolder) {
                TextField(L("files.folder.name"), text: $folderName)
                Button(L("common.create")) { createFolder() }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("files.create.description"))
            }
            .alert(L("files.rename.title"), isPresented: $showRename) {
                TextField(L("files.name.placeholder"), text: $renameText)
                Button(L("common.save")) { doRename() }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("files.rename.description"))
            }
            .confirmationDialog(L("files.delete.confirm.title"), isPresented: $showDelete, titleVisibility: .visible) {
                Button(L("files.action.delete"), role: .destructive) { doDelete() }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("files.delete.confirm.message"))
            }
            .onChange(of: session.connected) { _, connected in
                if connected { load() }
            }
            .onAppear {
                if session.connected && items.isEmpty { load() }
            }
            .sheet(isPresented: $showShare) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - 内容

    private var fileContent: some View {
        VStack(spacing: 0) {
            quickEntries
            pathBar
            ScrollView {
                LazyVStack(spacing: 8) {
                    if items.isEmpty {
                        Text(L("files.empty"))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.kakaTextSecondary)
                            .padding(.top, 60)
                    }
                    ForEach(items) { item in
                        FileRowView(item: item, onOpen: {
                            if item.isDirectory { path = item.path; load() }
                        }, onDownload: {
                            download(item)
                        }, onSaveToPhotos: {
                            if isImage(item) { saveImageToPhotos(item) }
                        }, onRename: {
                            renameTarget = item
                            renameText = item.name
                            showRename = true
                        }, onDelete: {
                            deleteTarget = item
                            showDelete = true
                        })
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
            .refreshable { load() }
        }
        .background(Color.kakaBackground)
    }

    private var quickEntries: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FileService.quickPaths, id: \.path) { entry in
                    Button {
                        path = entry.path
                        load()
                    } label: {
                        Text(L(entry.key))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(path == entry.path ? .white : Color.kakaBlueDeep)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(path == entry.path ? Color.kakaBlueDeep : Color.kakaCard)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var pathBar: some View {
        HStack(spacing: 10) {
            Button {
                path = (path as NSString).deletingLastPathComponent
                if !path.hasPrefix("/") { path = "/" }
                load()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.kakaBlueDeep)
                    .frame(width: 34, height: 34)
                    .background(Color.kakaCard)
                    .clipShape(Circle())
            }
            .disabled(path == "/")
            Text(path)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.kakaTextPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if loading {
                ProgressView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - 数据

    private func load() {
        guard let serial = session.serial else { return }
        loading = true
        loadError = nil
        FileService.shared.list(serial: serial, path: path) { result in
            DispatchQueue.main.async {
                loading = false
                switch result {
                case .success(let list): items = list
                case .failure(let err): loadError = err
                }
            }
        }
    }

    private func uploadFiles(_ urls: [URL]) {
        guard let serial = session.serial else { return }
        busyText = L("files.uploading")
        showBusy = true
        var remaining = urls
        let item = history.add(type: .file, title: L("files.message.upload", urls.first?.lastPathComponent ?? ""), detail: serial, status: .running)
        func next() {
            guard let url = remaining.first else {
                DispatchQueue.main.async {
                    showBusy = false
                    history.updateStatus(id: item.id, status: .success)
                    ToastCenter.shared.show(L("files.upload.success"))
                    load()
                }
                return
            }
            remaining.removeFirst()
            let name = url.lastPathComponent
            let local = FileService.uploadsDir().appendingPathComponent(name)
            do {
                if FileManager.default.fileExists(atPath: local.path) {
                    try FileManager.default.removeItem(at: local)
                }
                try FileManager.default.copyItem(at: url, to: local)
            } catch {
                next()
                return
            }
            let remote = (path == "/" ? "" : path) + "/" + name
            FileService.shared.upload(serial: serial, localPath: local.path, remotePath: remote) { result in
                if case .failure(let err) = result {
                    DispatchQueue.main.async {
                        history.updateStatus(id: item.id, status: .failed)
                        showBusy = false
                        ToastCenter.shared.show(err)
                    }
                    return
                }
                next()
            }
        }
        next()
    }

    private func download(_ item: FileItem) {
        guard let serial = session.serial else { return }
        busyText = L("files.downloading")
        showBusy = true
        let itemHistory = history.add(type: .file, title: L("files.message.download", item.name), detail: serial, status: .running)
        let local = FileService.downloadsDir().appendingPathComponent(item.name)
        FileService.shared.download(serial: serial, remotePath: item.path, localPath: local.path) { result in
            DispatchQueue.main.async {
                showBusy = false
                switch result {
                case .success:
                    history.updateStatus(id: itemHistory.id, status: .success)
                    ToastCenter.shared.show(L("files.message.saved.to", local.path))
                    if !isImage(item) && !isVideo(item) {
                        shareURL = local
                        showShare = true
                    } else if isImage(item) {
                        saveToPhotosFromDisk(local)
                    }
                case .failure(let err):
                    history.updateStatus(id: itemHistory.id, status: .failed)
                    ToastCenter.shared.show(err)
                }
            }
        }
    }

    private func saveImageToPhotos(_ item: FileItem) {
        guard let serial = session.serial else { return }
        busyText = L("files.downloading")
        showBusy = true
        let local = FileService.downloadsDir().appendingPathComponent(item.name)
        FileService.shared.download(serial: serial, remotePath: item.path, localPath: local.path) { result in
            DispatchQueue.main.async {
                showBusy = false
                if case .success = result {
                    saveToPhotosFromDisk(local)
                }
            }
        }
    }

    private func saveToPhotosFromDisk(_ url: URL) {
        guard let image = UIImage(contentsOfFile: url.path) else {
            ToastCenter.shared.show(L("commands.screenshot.read.failed"))
            return
        }
        ScreenshotService.saveImageToPhotos(image) { ok, err in
            DispatchQueue.main.async {
                ToastCenter.shared.show(ok ? L("commands.screenshot.saved.photos") : err)
            }
        }
    }

    private func doRename() {
        guard let target = renameTarget, let serial = session.serial else { return }
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { return }
        let newPath = (target.path as NSString).deletingLastPathComponent + "/" + newName
        busyText = L("toast.loading")
        showBusy = true
        let item = history.add(type: .file, title: L("files.message.rename", target.name, newName), detail: serial, status: .running)
        FileService.shared.rename(serial: serial, from: target.path, to: newPath) { result in
            DispatchQueue.main.async {
                showBusy = false
                switch result {
                case .success(let msg):
                    history.updateStatus(id: item.id, status: .success)
                    ToastCenter.shared.show(msg)
                    load()
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    ToastCenter.shared.show(err)
                }
            }
        }
    }

    private func createFolder() {
        guard let serial = session.serial else { return }
        let name = folderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let newPath = (path == "/" ? "" : path) + "/" + name
        busyText = L("toast.loading")
        showBusy = true
        let item = history.add(type: .file, title: L("files.message.create.folder", name), detail: serial, status: .running)
        FileService.shared.makeFolder(serial: serial, path: newPath) { result in
            DispatchQueue.main.async {
                showBusy = false
                switch result {
                case .success(let msg):
                    history.updateStatus(id: item.id, status: .success)
                    ToastCenter.shared.show(msg)
                    folderName = ""
                    load()
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    ToastCenter.shared.show(err)
                }
            }
        }
    }

    private func doDelete() {
        guard let target = deleteTarget, let serial = session.serial else { return }
        busyText = L("toast.loading")
        showBusy = true
        let item = history.add(type: .file, title: L("files.message.delete", target.name), detail: serial, status: .running)
        FileService.shared.delete(serial: serial, path: target.path) { result in
            DispatchQueue.main.async {
                showBusy = false
                switch result {
                case .success(let msg):
                    history.updateStatus(id: item.id, status: .success)
                    ToastCenter.shared.show(msg)
                    load()
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    ToastCenter.shared.show(err)
                }
            }
        }
    }

    private func isImage(_ item: FileItem) -> Bool {
        ["png", "jpg", "jpeg", "webp", "gif"].contains((item.name as NSString).pathExtension.lowercased())
    }
    private func isVideo(_ item: FileItem) -> Bool {
        ["mp4", "mkv", "webm", "3gp"].contains((item.name as NSString).pathExtension.lowercased())
    }
}

// MARK: - 文件行

struct FileRowView: View {
    let item: FileItem
    var onOpen: () -> Void = {}
    var onDownload: () -> Void = {}
    var onSaveToPhotos: () -> Void = {}
    var onRename: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : fileIcon)
                .font(.system(size: 22))
                .foregroundStyle(item.isDirectory ? Color.kakaBlueDeep : Color.kakaTextSecondary)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.kakaTextPrimary)
                    .lineLimit(1)
                if !item.isDirectory {
                    Text(sizeText(item.size))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.kakaTextSecondary)
                }
            }
            Spacer()
            Menu {
                if item.isDirectory {
                    Button { onOpen() } label: { Label(L("common.open"), systemImage: "arrow.down.right") }
                } else {
                    Button { onDownload() } label: { Label(L("files.action.download"), systemImage: "arrow.down.circle") }
                    if isImageFile {
                        Button { onSaveToPhotos() } label: { Label(L("commands.screenshot.save.photos"), systemImage: "photo") }
                    }
                }
                Button { onRename() } label: { Label(L("files.action.rename"), systemImage: "pencil") }
                Button(role: .destructive) { onDelete() } label: { Label(L("files.action.delete"), systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.kakaBlueDeep)
            }
        }
        .padding(12)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.smallRadius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if item.isDirectory { onOpen() }
        }
    }

    private var fileIcon: String {
        switch (item.name as NSString).pathExtension.lowercased() {
        case "apk": return "square.and.arrow.down.fill"
        case "png", "jpg", "jpeg", "webp", "gif": return "photo.fill"
        case "mp4", "mkv", "3gp": return "video.fill"
        case "mp3", "wav", "flac", "aac": return "music.note"
        case "zip", "rar", "7z", "tar": return "archivebox.fill"
        case "txt", "log", "json", "xml", "md": return "doc.text.fill"
        default: return "doc.fill"
        }
    }

    private var isImageFile: Bool {
        ["png", "jpg", "jpeg", "webp", "gif"].contains((item.name as NSString).pathExtension.lowercased())
    }

    private func sizeText(_ size: Int64) -> String {
        let kb = Double(size) / 1024
        if kb < 1 { return "\(size) B" }
        let mb = kb / 1024
        if mb < 1 { return String(format: "%.1f KB", kb) }
        let gb = mb / 1024
        if gb < 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.2f GB", gb)
    }
}

// MARK: - 分享面板

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
