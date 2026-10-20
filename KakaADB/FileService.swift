//
//  FileService.swift
//  文件管理服务：浏览/上传/下载/删除/重命名/新建文件夹（ls / push / pull / shell 命令族）
//
import Foundation

final class FileService {

    static let shared = FileService()

    /// 快捷入口（Scarab 同款）
    static let quickPaths: [(key: String, path: String)] = [
        ("files.quick.root", "/"),
        ("files.quick.storage", "/sdcard"),
        ("files.quick.download", "/sdcard/Download"),
        ("files.quick.music", "/sdcard/Music"),
        ("files.quick.photos", "/sdcard/Pictures"),
    ]

    // MARK: 列表

    func list(serial: String, path: String, completion: @escaping (Result<[FileItem], String>) -> Void) {
        let quoted = shellQuote(path)
        let cmd = "ls -lA --color=never \(quoted) 2>/dev/null || ls -a \(quoted)"
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: cmd)) { result in
            guard result.succeeded else {
                completion(.failure(result.output.trimmed.isEmpty ? L("error.operation.failed") : result.output.trimmed))
                return
            }
            let items = Self.parseListing(result.output, basePath: path)
            completion(.success(items))
        }
    }

    /// 解析 ls -lA 输出（toybox 兼容：权限|链接|属主|组|大小|日期|名称）
    static func parseListing(_ raw: String, basePath: String) -> [FileItem] {
        var items: [FileItem] = []
        for line in raw.split(separator: "\n").map(String.init) {
            guard let first = line.first, line.count >= 10 else { continue }
            let mode = line.prefix(10)
            guard "dlcbs-".contains(first) else { continue }
            let parts = line.split(separator: " ").map(String.init)
            let isDir = mode.hasPrefix("d")
            var size: Int64 = 0
            var name: String
            if parts.count >= 8, let sz = Int64(parts[4]) {
                size = sz
                name = parts.dropFirst(7).joined(separator: " ")
            } else {
                name = parts.dropFirst(6).joined(separator: " ")
            }
            guard !name.isEmpty, name != "." && name != ".." else { continue }
            let fullPath = basePath == "/" ? "/\(name)" : "\(basePath)/\(name)"
            items.append(FileItem(name: name, path: fullPath, isDirectory: isDir, size: size))
        }
        return items.sorted { ($0.isDirectory ? 0 : 1, $0.name) < ($1.isDirectory ? 0 : 1, $1.name) }
    }

    // MARK: 传输

    /// 上传（push）：localPath 必须可读（App 沙盒内）
    func upload(serial: String, localPath: String, remotePath: String, completion: @escaping (Result<String, String>) -> Void) {
        ADBEngine.shared.run(["-s", serial, "push", localPath, remotePath]) { result in
            let out = result.output.trimmed
            if result.succeeded {
                completion(.success(L("files.upload.success")))
            } else {
                completion(.failure(out.isEmpty ? L("files.upload.failed") : out))
            }
        }
    }

    /// 下载（pull）：localPath 为 App 沙盒内目标路径
    func download(serial: String, remotePath: String, localPath: String, completion: @escaping (Result<String, String>) -> Void) {
        ADBEngine.shared.run(["-s", serial, "pull", remotePath, localPath]) { result in
            let out = result.output.trimmed
            if result.succeeded {
                completion(.success(L("files.download.success")))
            } else {
                completion(.failure(out.isEmpty ? L("files.download.failed") : out))
            }
        }
    }

    // MARK: 常规操作

    func delete(serial: String, path: String, completion: @escaping (Result<String, String>) -> Void) {
        let cmd = "rm -rf \(shellQuote(path))"
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: cmd)) { result in
            if result.succeeded {
                completion(.success(L("files.message.deleted", path)))
            } else {
                completion(.failure(result.output.trimmed.isEmpty ? L("files.message.delete.failed", path) : result.output.trimmed))
            }
        }
    }

    func rename(serial: String, from: String, to: String, completion: @escaping (Result<String, String>) -> Void) {
        let cmd = "mv \(shellQuote(from)) \(shellQuote(to))"
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: cmd)) { result in
            if result.succeeded {
                completion(.success(L("files.message.renamed", to)))
            } else {
                completion(.failure(result.output.trimmed.isEmpty ? L("files.message.rename.failed", from) : result.output.trimmed))
            }
        }
    }

    func makeFolder(serial: String, path: String, completion: @escaping (Result<String, String>) -> Void) {
        let cmd = "mkdir -p \(shellQuote(path))"
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: cmd)) { result in
            if result.succeeded {
                completion(.success(L("files.message.folder.created", path)))
            } else {
                completion(.failure(result.output.trimmed.isEmpty ? L("files.message.create.failed", path) : result.output.trimmed))
            }
        }
    }

    /// 是否为合法的绝对路径（防止越权跳转）
    static func sanitizePath(_ path: String) -> Bool {
        path.hasPrefix("/")
    }

    /// 路径加引号（shell 安全）
    private func shellQuote(_ path: String) -> String {
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    // MARK: - 沙盒目录

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static func downloadsDir() -> URL {
        let dir = documents.appendingPathComponent("kaka_downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func uploadsDir() -> URL {
        let dir = documents.appendingPathComponent("kaka_uploads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func shotsDir() -> URL {
        let dir = documents.appendingPathComponent("kaka_shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
