//
//  Compat.swift
//  编译兼容层
//
//  上游这套源码大量使用 `Result<T, String>`（16 处）与 `String.trimmed`（19 处），
//  但既没给 String 加 Error 一致性，也没定义 trimmed —— 这正是它 6 次 Actions
//  全部失败的主因。这里一次性补齐，避免逐个文件改动引入回归。
//
import Foundation

/// 让 String 可以直接当 Error 用（`Result<T, String>` / `throw "xxx"`）
extension String: Error {}

extension String {
    /// 去掉首尾空白与换行
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
