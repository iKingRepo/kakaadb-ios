//
//  RemoteView.swift
//  电视遥控：ADB 键码遥控智能电视/盒子（对标 Scarab 遥控面板）
//
import SwiftUI
import UIKit

struct RemoteView: View {
    @EnvironmentObject var session: Session

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if !session.connected {
                        VStack(spacing: 12) {
                            Image(systemName: "tv.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.kakaBlue.opacity(0.6))
                            Text(L("error.no.device"))
                                .font(.system(size: 14))
                                .foregroundStyle(Color.kakaTextSecondary)
                        }
                        .padding(.top, 60)
                    } else {
                        powerRow
                        mainRow
                        volumeChannelRow
                        numberPad
                    }
                }
                .padding(20)
            }
            .background(Color.kakaBackground)
            .navigationTitle(L("remote.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 电源行

    private var powerRow: some View {
        HStack(spacing: 24) {
            remoteButton(icon: "power", keycode: RemoteKey.power, isPower: true)
            remoteButton(icon: "house.fill", keycode: RemoteKey.home)
            remoteButton(icon: "arrow.uturn.backward", keycode: RemoteKey.back)
            remoteButton(icon: "line.3.horizontal", keycode: RemoteKey.menu)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 方向 + 功能

    private var mainRow: some View {
        HStack(alignment: .center, spacing: 24) {
            // 方向键
            VStack(spacing: 8) {
                remoteButton(icon: "chevron.up", keycode: RemoteKey.up)
                HStack(spacing: 8) {
                    remoteButton(icon: "chevron.left", keycode: RemoteKey.left)
                    remoteButton(icon: "circle.fill", keycode: RemoteKey.ok, size: 56)
                    remoteButton(icon: "chevron.right", keycode: RemoteKey.right)
                }
                remoteButton(icon: "chevron.down", keycode: RemoteKey.down)
            }
            .padding(12)
            .background(Color.kakaCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 功能列
            VStack(spacing: 12) {
                remoteButton(icon: "info.circle", keycode: RemoteKey.info)
                remoteButton(icon: "playpause.fill", keycode: RemoteKey.playPause)
                remoteButton(icon: "speaker.slash.fill", keycode: RemoteKey.mute)
                remoteButton(icon: "delete.left.fill", keycode: RemoteKey.delete)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 音量/频道

    private var volumeChannelRow: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(L("remote.volume"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.kakaTextSecondary)
                HStack(spacing: 20) {
                    remoteButton(icon: "speaker.fill", keycode: RemoteKey.volumeUp)
                    remoteButton(icon: "speaker.wave.1.fill", keycode: RemoteKey.volumeDown)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.kakaCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 8) {
                Text(L("remote.channel"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.kakaTextSecondary)
                HStack(spacing: 20) {
                    remoteButton(icon: "plus", keycode: RemoteKey.channelUp)
                    remoteButton(icon: "minus", keycode: RemoteKey.channelDown)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.kakaCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - 数字键盘

    private var numberPad: some View {
        VStack(spacing: 10) {
            Text(L("remote.number.pad"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.kakaTextSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(0..<10, id: \.self) { digit in
                    Button {
                        sendKey(RemoteKey.digits[digit])
                    } label: {
                        Text("\(digit)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.kakaTextPrimary)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.kakaCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }

    // MARK: - 按钮

    private func remoteButton(icon: String, keycode: Int, isPower: Bool = false, size: CGFloat = 48) -> some View {
        Button {
            sendKey(keycode)
        } label: {
            Image(systemName: icon)
                .font(.system(size: size > 48 ? 22 : 18, weight: .semibold))
                .foregroundStyle(isPower ? Color.kakaDanger : Color.kakaTextPrimary)
                .frame(width: size, height: size)
                .background(Color.kakaCard)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func sendKey(_ keycode: Int) {
        guard let serial = session.serial else { return }
        RemoteService.shared.sendKey(serial: serial, keycode: keycode)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
