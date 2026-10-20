//
//  AppManager.swift
//  应用管理服务：列表/安装/卸载/清除数据/强制停止（pm / am 命令族）
//
import Foundation

final class AppManagerService {

    static let shared = AppManagerService()

    func loadApps(serial: String, completion: @escaping (Result<[InstalledApp], String>) -> Void) {
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: "pm list packages -f")) { result in
            guard result.succeeded else {
                completion(.failure(result.output.trimmed.isEmpty ? L("apps.load.failed", "") : result.output.trimmed))
                return
            }
            var apps: [InstalledApp] = []
            for line in result.output.split(separator: "\n").map(String.init) {
                // package:/data/app/xxx/base.apk=com.foo
                guard line.hasPrefix("package:") else { continue }
                let body = line.dropFirst("package:".count)
                guard let eq = body.firstIndex(of: "=") else { continue }
                let path = String(body[body.startIndex..<eq])
                let pkg = String(body[body.index(after: eq)...])
                guard !pkg.isEmpty else { continue }
                apps.append(InstalledApp(package: pkg, path: path))
            }
            completion(.success(apps.sorted { $0.package < $1.package }))
        }
    }

    /// 安装 APK（本地路径）
    func install(apkPath: String, serial: String?, completion: @escaping (Result<String, String>) -> Void) {
        let args: [String] = serial.map { ["-s", $0, "install", "-r", apkPath] } ?? ["install", "-r", apkPath]
        ADBEngine.shared.run(args) { result in
            let out = result.output.trimmed
            if result.succeeded && out.contains("Success") {
                completion(.success(L("apps.install.success")))
            } else {
                let reason = out.contains("Failure") ? out : (out.isEmpty ? L("apps.install.failed") : out)
                completion(.failure(reason))
            }
        }
    }

    func uninstall(pkg: String, serial: String, completion: @escaping (Result<String, String>) -> Void) {
        ADBEngine.shared.run(["-s", serial, "uninstall", pkg]) { result in
            let out = result.output.trimmed
            if result.succeeded && out.contains("Success") {
                completion(.success(L("apps.uninstall.success")))
            } else {
                completion(.failure(out.isEmpty ? L("apps.uninstall.failed") : out))
            }
        }
    }

    func clearData(pkg: String, serial: String, completion: @escaping (Result<String, String>) -> Void) {
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: "pm clear \(pkg)")) { result in
            let out = result.output.trimmed
            if out == "Success" || result.succeeded && out.contains("Success") {
                completion(.success(L("apps.clear.data.success")))
            } else {
                completion(.failure(out.isEmpty ? L("apps.clear.failed.reason", "") : out))
            }
        }
    }

    func forceStop(pkg: String, serial: String, completion: @escaping (Result<String, String>) -> Void) {
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: "am force-stop \(pkg)")) { result in
            if result.succeeded {
                completion(.success(L("apps.force.stop.success")))
            } else {
                completion(.failure(result.output.trimmed.isEmpty ? L("apps.force.stop.failed.reason", "") : result.output.trimmed))
            }
        }
    }
}
