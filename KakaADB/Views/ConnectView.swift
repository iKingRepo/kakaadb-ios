//
//  ConnectView.swift
//  连接设备：WiFi 经典模式 + Android 11+ 无线调试配对 + 连接历史 + 图文帮助（对标 Scarab）
//
import SwiftUI
import UIKit

struct ConnectView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Int = 0   // 0=WiFi, 1=无线调试
    @State private var ip = ""
    @State private var port = ""
    @State private var pairCode = ""
    @State private var showWifiHelp = false
    @State private var showWirelessHelp = false
    @State private var errorMessage: String?

    private let defaultPort = SettingsStore.shared.defaultPort

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("", selection: $mode) {
                        Text(L("connect.wifi.title")).tag(0)
                        Text(L("connect.wireless.title")).tag(1)
                    }
                    .pickerStyle(.segmented)

                    if mode == 0 {
                        wifiForm
                    } else {
                        wirelessForm
                    }

                    historySection
                }
                .padding(16)
            }
            .background(Color.kakaBackground)
            .navigationTitle(L("connect.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common.close")) { dismiss() }
                }
            }
            .overlay {
                if session.isConnecting {
                    KakaLoading(text: "common.please.wait")
                }
            }
            .alert("", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L("common.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - WiFi 表单

    private var wifiForm: some View {
        VStack(spacing: 14) {
            Text(L("connect.wifi.description"))
                .font(.system(size: 13))
                .foregroundStyle(Color.kakaTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            inputField(title: L("connect.pairing.ip"), text: $ip, placeholder: L("connect.ip.placeholder"),
                       keyboard: .numbersAndPunctuation)
            inputField(title: L("connect.port.placeholder"), text: $port, placeholder: "5555",
                       keyboard: .numberPad)

            Button {
                connect()
            } label: {
                Text(L("connect.button.connect"))
            }
            .buttonStyle(KakaPrimaryButtonStyle())
            .disabled(ip.isEmpty || session.isConnecting)

            Button {
                showWifiHelp = true
            } label: {
                Label(L("connect.wifi.help.title"), systemImage: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kakaBlueDeep)
            }
        }
        .padding(16)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
        .sheet(isPresented: $showWifiHelp) { HelpStepsView(title: L("connect.wifi.help.title"), content: L("help.wifi.content")) }
    }

    // MARK: - 无线调试表单

    private var wirelessForm: some View {
        VStack(spacing: 14) {
            Text(L("connect.wireless.description"))
                .font(.system(size: 13))
                .foregroundStyle(Color.kakaTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            inputField(title: L("connect.pairing.ip"), text: $ip, placeholder: L("connect.ip.placeholder"),
                       keyboard: .numbersAndPunctuation)
            inputField(title: L("connect.port.placeholder"), text: $port, placeholder: "5555",
                       keyboard: .numberPad)
            inputField(title: L("connect.pairing.code"), text: $pairCode, placeholder: "123456",
                       keyboard: .numberPad)

            Button {
                connect()
            } label: {
                Text(L("connect.button.pair"))
            }
            .buttonStyle(KakaPrimaryButtonStyle())
            .disabled(ip.isEmpty || pairCode.isEmpty || session.isConnecting)

            Button {
                showWirelessHelp = true
            } label: {
                Label(L("connect.wireless.help.title"), systemImage: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kakaBlueDeep)
            }
        }
        .padding(16)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
        .sheet(isPresented: $showWirelessHelp) { HelpStepsView(title: L("connect.wireless.help.title"), content: L("help.wireless.content")) }
    }

    private func inputField(title: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.kakaTextSecondary)
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.kakaBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - 连接历史

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("connect.history"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.kakaTextPrimary)
            if ConnectionHistoryStore.shared.profiles.isEmpty {
                Text(L("history.empty"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kakaTextSecondary)
            } else {
                ForEach(ConnectionHistoryStore.shared.profiles) { profile in
                    HStack {
                        Image(systemName: "iphone.gen3")
                            .foregroundStyle(Color.kakaBlueDeep)
                        Text("\(profile.ip):\(profile.port)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.kakaTextPrimary)
                        Spacer()
                        Button(L("connect.button.connect")) {
                            ip = profile.ip
                            port = String(profile.port)
                            mode = 0
                            connect()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.kakaBlueDeep)
                    }
                    .padding(.vertical, 6)
                    Divider().overlay(Color.kakaDivider)
                }
            }
        }
        .padding(16)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
    }

    // MARK: - 动作

    private func connect() {
        guard !ip.isEmpty else { return }
        let p = Int(port) ?? defaultPort
        session.connect(ip: ip, port: p, code: mode == 1 ? pairCode : nil) { ok, msg in
            if ok {
                ToastCenter.shared.show(L("connect.success"))
                dismiss()
            } else {
                errorMessage = msg
            }
        }
    }
}

// MARK: - 帮助步骤页

struct HelpStepsView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.kakaTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(Color.kakaBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }
}
