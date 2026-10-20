//
//  CommandCenter.swift
//  命令中心（快捷命令目录+执行）+ 截图/录屏 + 电视遥控
//
import Foundation
import UIKit
import Photos

// MARK: - 命令目录

enum CommandCatalog {

    static let all: [QuickCommand] = [
        // ---- 系统控制 ----
        QuickCommand(id: "reboot", titleKey: "commands.item.reboot", category: .system,
                     confirmKey: "commands.confirm.reboot", parameterKey: nil) { _ in ["reboot"] },
        QuickCommand(id: "power_off", titleKey: "commands.item.power.off", category: .system,
                     confirmKey: "commands.confirm.power.off", parameterKey: nil) { _ in ["reboot", "-p"] },
        QuickCommand(id: "recovery", titleKey: "commands.item.recovery", category: .system,
                     confirmKey: "commands.confirm.recovery", parameterKey: nil) { _ in ["reboot", "recovery"] },
        QuickCommand(id: "fastboot", titleKey: "commands.item.fastboot", category: .system,
                     confirmKey: "commands.confirm.fastboot", parameterKey: nil) { _ in ["reboot", "bootloader"] },
        QuickCommand(id: "bootloader", titleKey: "commands.item.bootloader", category: .system,
                     confirmKey: "commands.confirm.bootloader", parameterKey: nil) { _ in ["reboot", "bootloader"] },
        QuickCommand(id: "dark_on", titleKey: "commands.item.dark.mode.enable", category: .system,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "cmd uimode night yes"] },
        QuickCommand(id: "dark_off", titleKey: "commands.item.dark.mode.disable", category: .system,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "cmd uimode night no"] },
        QuickCommand(id: "wifi_on", titleKey: "commands.item.wifi.enable", category: .system,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "svc wifi enable"] },
        QuickCommand(id: "wifi_off", titleKey: "commands.item.wifi.disable", category: .system,
                     confirmKey: "commands.confirm.disable.wifi", parameterKey: nil) { _ in ["shell", "svc wifi disable"] },
        QuickCommand(id: "data_on", titleKey: "commands.item.mobile.data.enable", category: .system,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "svc data enable"] },
        QuickCommand(id: "data_off", titleKey: "commands.item.mobile.data.disable", category: .system,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "svc data disable"] },

        // ---- 网络工具 ----
        QuickCommand(id: "ip_addr", titleKey: "commands.item.ip.address", category: .network,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "ip addr show wlan0"] },
        QuickCommand(id: "wifi_info", titleKey: "commands.item.wifi.info", category: .network,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "dumpsys wifi | head -n 40"] },
        QuickCommand(id: "net_status", titleKey: "commands.item.network.status", category: .network,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "dumpsys connectivity | head -n 30"] },
        QuickCommand(id: "ping", titleKey: "commands.item.ping", category: .network,
                     confirmKey: nil, parameterKey: "commands.input.placeholder") { param in
            ["shell", "ping -c 4 \(param.isEmpty ? "127.0.0.1" : param)"]
        },
        QuickCommand(id: "res", titleKey: "commands.item.screen.resolution", category: .network,
                     confirmKey: nil, parameterKey: "commands.input.placeholder") { param in
            ["shell", "wm size \(param.isEmpty ? "1080x2400" : param)"]
        },
        QuickCommand(id: "res_reset", titleKey: "commands.item.reset.resolution", category: .network,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "wm size reset"] },
        QuickCommand(id: "dens", titleKey: "commands.item.screen.density", category: .network,
                     confirmKey: nil, parameterKey: "commands.input.placeholder") { param in
            ["shell", "wm density \(param.isEmpty ? "440" : param)"]
        },
        QuickCommand(id: "dens_reset", titleKey: "commands.item.reset.density", category: .network,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "wm density reset"] },

        // ---- 日志与监控 ----
        QuickCommand(id: "logcat", titleKey: "commands.item.view.logs", category: .logs,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "logcat -d -v time"] },
        QuickCommand(id: "logcat_clear", titleKey: "commands.item.clear.logs", category: .logs,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "logcat -c"] },
        QuickCommand(id: "cpu_usage", titleKey: "commands.item.cpu.usage", category: .logs,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "top -n 1 | head -n 20"] },
        QuickCommand(id: "cpu_info", titleKey: "commands.item.cpu.info", category: .logs,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "cat /proc/cpuinfo | head -n 30"] },
        QuickCommand(id: "mem_info", titleKey: "commands.item.memory.info", category: .logs,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "cat /proc/meminfo | head -n 20"] },
        QuickCommand(id: "mem_usage", titleKey: "commands.item.memory.usage", category: .logs,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "cat /proc/meminfo"] },
        QuickCommand(id: "battery", titleKey: "commands.item.battery.info", category: .logs,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "dumpsys battery"] },
        QuickCommand(id: "storage", titleKey: "commands.item.storage.info", category: .logs,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "df -h"] },

        // ---- 高级工具 ----
        QuickCommand(id: "model", titleKey: "commands.item.device.model", category: .advanced,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "getprop ro.product.model"] },
        QuickCommand(id: "sys_version", titleKey: "commands.item.system.version", category: .advanced,
                     confirmKey: nil, parameterKey: nil) { _ in ["shell", "getprop ro.build.version.release"] },
        QuickCommand(id: "screenshot", titleKey: "commands.item.screenshot", category: .advanced,
                     confirmKey: nil, parameterKey: nil) { _ in [] },   // 特殊流程
        QuickCommand(id: "screen_record", titleKey: "commands.screen.record", category: .advanced,
                     confirmKey: nil, parameterKey: nil) { _ in [] },   // 特殊流程
    ]

    static func commands(in category: CommandCategory) -> [QuickCommand] {
        all.filter { $0.category == category }
    }
}

// MARK: - 执行器

final class CommandExecutor {

    static let shared = CommandExecutor()

    /// 执行快捷命令；截图/录屏走特殊流程（由调用方处理 isSpecial）
    func isSpecial(_ cmd: QuickCommand) -> Bool {
        cmd.id == "screenshot" || cmd.id == "screen_record"
    }

    func run(_ cmd: QuickCommand, serial: String?, param: String = "",
             completion: @escaping (Result<String, String>) -> Void) {
        var args = cmd.buildArgs(param)
        guard !args.isEmpty else { return }
        // 全局选项 -s serial 必须放在命令名之前（adb 解析顺序）
        if let serial, !args.contains("-s") {
            args.insert(contentsOf: ["-s", serial], at: 0)
        }
        ADBEngine.shared.run(args) { result in
            let out = result.output.trimmed
            if result.succeeded {
                completion(.success(out.isEmpty ? L("commands.success") : out))
            } else {
                completion(.failure(out.isEmpty ? L("commands.failed") : out))
            }
        }
    }

    /// 自定义 shell 命令
    func runCustom(_ command: String, serial: String?, completion: @escaping (Result<String, String>) -> Void) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: trimmed)) { result in
            let out = result.output.trimmed
            if result.succeeded {
                completion(.success(out.isEmpty ? L("terminal.success.no.output") : out))
            } else {
                completion(.failure(out.isEmpty ? L("commands.failed") : out))
            }
        }
    }
}

// MARK: - 截图 / 录屏

final class ScreenshotService {

    static let shared = ScreenshotService()

    struct CaptureResult {
        let remotePath: String
        let localURL: URL
        let image: UIImage?
        let videoURL: URL?
    }

    /// 截图：设备端 screencap → pull 回本地（文本缓冲不支持二进制，必须走文件）
    func captureScreenshot(serial: String, completion: @escaping (Result<CaptureResult, String>) -> Void) {
        let ts = Int(Date().timeIntervalSince1970)
        let remote = "/sdcard/Download/kaka_shot_\(ts).png"
        let local = FileService.shotsDir().appendingPathComponent("kaka_shot_\(ts).png")

        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: "screencap -p \(remote)")) { r in
            guard r.succeeded else {
                completion(.failure(r.output.trimmed.isEmpty ? L("commands.screenshot.read.failed") : r.output.trimmed))
                return
            }
            ADBEngine.shared.run(["-s", serial, "pull", remote, local.path]) { p in
                guard p.succeeded else {
                    completion(.failure(p.output.trimmed.isEmpty ? L("files.download.failed") : p.output.trimmed))
                    return
                }
                let img = UIImage(contentsOfFile: local.path)
                completion(.success(CaptureResult(remotePath: remote, localURL: local, image: img, videoURL: nil)))
            }
        }
    }

    /// 录屏：screenrecord --time-limit N → pull 回本地
    func captureScreenRecord(serial: String, seconds: Int = 10, completion: @escaping (Result<CaptureResult, String>) -> Void) {
        let ts = Int(Date().timeIntervalSince1970)
        let remote = "/sdcard/Download/kaka_rec_\(ts).mp4"
        let local = FileService.shotsDir().appendingPathComponent("kaka_rec_\(ts).mp4")

        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: "screenrecord --time-limit \(seconds) \(remote)")) { r in
            guard r.succeeded else {
                completion(.failure(r.output.trimmed.isEmpty ? L("commands.failed") : r.output.trimmed))
                return
            }
            ADBEngine.shared.run(["-s", serial, "pull", remote, local.path]) { p in
                guard p.succeeded, FileManager.default.fileExists(atPath: local.path) else {
                    completion(.failure(p.output.trimmed.isEmpty ? L("files.download.failed") : p.output.trimmed))
                    return
                }
                completion(.success(CaptureResult(remotePath: remote, localURL: local, image: nil, videoURL: local)))
            }
        }
    }

    /// 保存到相册
    static func saveImageToPhotos(_ image: UIImage, completion: @escaping (Bool, String) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(false, L("error.permission.denied"))
                return
            }
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetChangeRequest.creationRequestForAsset(from: image)
                placeholder = req.placeholderForCreatedAsset
            }) { ok, err in
                completion(ok, err?.localizedDescription ?? "")
            }
        }
    }

    static func saveVideoToPhotos(_ url: URL, completion: @escaping (Bool, String) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(false, L("error.permission.denied"))
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { ok, err in
                completion(ok, err?.localizedDescription ?? "")
            }
        }
    }

    /// 删除设备端临时文件
    static func deleteDeviceFile(serial: String, remote: String, completion: (() -> Void)? = nil) {
        let cmd = "rm -f \(remote)"
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: cmd)) { _ in
            completion?()
        }
    }
}

// MARK: - 电视遥控（ADB 键码）

enum RemoteKey {
    static let power = 26       // KEYCODE_POWER
    static let home = 3         // KEYCODE_HOME
    static let back = 4         // KEYCODE_BACK
    static let menu = 82        // KEYCODE_MENU
    static let info = 165       // KEYCODE_INFO
    static let ok = 23          // KEYCODE_DPAD_CENTER
    static let up = 19, down = 20, left = 21, right = 22
    static let volumeUp = 24, volumeDown = 25
    static let mute = 91        // KEYCODE_MUTE
    static let channelUp = 166, channelDown = 167
    static let playPause = 85   // KEYCODE_MEDIA_PLAY_PAUSE
    static let delete = 67      // KEYCODE_DEL
    static let digits = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16] // KEYCODE_0..9
}

final class RemoteService {
    static let shared = RemoteService()

    func sendKey(serial: String, keycode: Int) {
        ADBEngine.shared.run(ADBEngine.shared.shell(serial: serial, command: "input keyevent \(keycode)")) { _ in }
    }
}
