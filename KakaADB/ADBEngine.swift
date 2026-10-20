//
//  ADBEngine.swift
//  核心引擎：Swift 封装 Scarab 同款原生 adb 客户端（adb-mobile / AOSP adb 35.0.2）
//  所有命令都通过 C API adb_commandline_porting() 执行，串行队列防止并发调用。
//
import Foundation

// MARK: - 执行结果

struct ADBResult {
    let exitCode: Int32
    let output: String
    var succeeded: Bool { exitCode == 0 }

    var trimmed: String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 引擎

final class ADBEngine {
    static let shared = ADBEngine()

    /// 串行执行队列：adb-mobile 内部有全局状态，禁止并发调用
    private let queue = DispatchQueue(label: "com.kaka.adb.engine", qos: .userInitiated)
    private var setupDone = false

    private init() {}

    /// 初始化（App 启动时调用一次）：HOME 指向 Documents（adb key 与拉取文件都在这），服务端口 5037
    func setup() {
        guard !setupDone else { return }
        setupDone = true
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        adb_set_home(docs.path)
        adb_set_server_port("5037")
        // 需要排查时打开全量 trace：adb_enable_trace()
    }

    // MARK: 同步核心（仅队列内调用）

    func runSync(_ args: [String]) -> ADBResult {
        var cstrs: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        cstrs.append(nil)   // argv 需要 NULL 结尾
        defer { cstrs.forEach { free($0) } }

        var out: UnsafeMutablePointer<CChar>? = nil
        var outSize: Int = 0
        let ret: Int32 = cstrs.withUnsafeBufferPointer { buf in
            // [UnsafeMutablePointer<CChar>?] -> UnsafePointer<UnsafePointer<CChar>?>（布局一致，直接内存绑定）
            let argv = UnsafeRawPointer(buf.baseAddress!)
                .assumingMemoryBound(to: UnsafePointer<CChar>?.self)
            return adb_commandline_porting(&out, &outSize, Int32(args.count), argv)
        }
        var text = ""
        if let out, outSize > 0 {
            text = String(cString: out)
        }
        if let out { free(out) }   // capture_printf 内部 realloc 分配，需释放
        return ADBResult(exitCode: ret, output: text)
    }

    // MARK: 异步执行（统一入口）

    @discardableResult
    func run(_ args: [String], completion: @escaping (ADBResult) -> Void) -> Void {
        queue.async {
            completion(self.runSync(args))
        }
    }

    // MARK: 便捷封装

    /// adb shell 一条命令（整条命令作为单个参数传入，保留内部引号语义；-s 全局选项前置）
    func shell(serial: String?, command: String) -> [String] {
        if let serial {
            return ["-s", serial, "shell", command]
        }
        return ["shell", command]
    }

    /// 输出截断显示（Scarab 同款行为）
    static func truncate(_ text: String, limit: Int = 2000) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + String(format: NSLocalizedString("commands.output.truncated", comment: ""), limit)
    }
}

// MARK: - 本地化辅助

/// 读取本地化文案，支持 %@/%d 参数（文案表来自 Scarab 447 条中英文）
func L(_ key: String, _ args: CVarArg...) -> String {
    let fmt = NSLocalizedString(key, comment: "")
    guard !args.isEmpty else { return fmt }
    return String(format: fmt, arguments: args)
}
