//
//  TerminalView.swift
//  Shell 终端：自由命令执行 + 输出日志（对标 Scarab）
//
import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var lines: [TermLine] = []
    @State private var running = false

    struct TermLine: Identifiable {
        let id = UUID()
        let text: String
        let isCommand: Bool
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                outputArea
                inputBar
            }
            .navigationTitle(L("commands.shell.terminal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("terminal.welcome.title"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.kakaBlueDeep)
                    Text(L("terminal.welcome.description"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.kakaTextSecondary)
                    Text(L("terminal.welcome.example"))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.kakaTextSecondary.opacity(0.7))
                    if lines.isEmpty {
                        Text(L("terminal.ready"))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.kakaSuccess)
                    }
                    ForEach(lines) { line in
                        Text(line.text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(line.isCommand ? Color.kakaBlueDeep : Color.kakaTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(line.id)
                    }
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: lines) { _, _ in
                if let last = lines.last {
                    withAnimation(.none) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(L("commands.input.placeholder"), text: $input)
                .font(.system(size: 14, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.kakaBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .submitLabel(.send)
                .onSubmit { execute() }
                .disabled(running)
            Button {
                execute()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(running ? Color.gray : Color.kakaBlueDeep)
            }
            .disabled(running || input.isEmpty)
            Button {
                lines = []
                ToastCenter.shared.show(L("terminal.cleared"))
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.kakaTextSecondary)
            }
        }
        .padding(12)
        .background(Color.kakaCard)
    }

    private func execute() {
        guard !running else { return }
        let cmd = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        guard let serial = session.serial else {
            lines.append(TermLine(text: L("error.no.device"), isCommand: false))
            return
        }
        lines.append(TermLine(text: "adb shell \(cmd)", isCommand: true))
        input = ""
        running = true
        let item = history.add(type: .shell, title: cmd, detail: serial, status: .running)
        CommandExecutor.shared.runCustom(cmd, serial: serial) { result in
            // 显式命名参数避免 Xcode 16 下 DispatchWorkItem 重载歧义
            DispatchQueue.main.async(group: nil, qos: .default, flags: [], execute: {
                running = false
                switch result {
                case .success(let out):
                    history.updateStatus(id: item.id, status: .success)
                    lines.append(contentsOf: out.split(separator: "\n").map { TermLine(text: String($0), isCommand: false) })
                case .failure(let err):
                    history.updateStatus(id: item.id, status: .failed)
                    lines.append(TermLine(text: "\(L("commands.error.output", err))", isCommand: false))
                }
            })
        }
    }
}
