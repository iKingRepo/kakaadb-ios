//
//  Theme.swift
//  设计语言：深度对标 Scarab（甲壳虫）——浅蓝底色 + 蓝色渐变主色 + 白色圆角卡片
//
import SwiftUI

extension Color {
    /// 主色渐变起点
    static let kakaBlue = Color(red: 0.357, green: 0.624, blue: 0.929)      // #5B9FED
    static let kakaBlueDeep = Color(red: 0.290, green: 0.561, blue: 0.906)  // #4A8FE7
    static let kakaBackground = Color(red: 0.937, green: 0.961, blue: 0.976) // #EFF5F9
    static let kakaCard = Color.white
    static let kakaTextPrimary = Color(red: 0.13, green: 0.16, blue: 0.21)
    static let kakaTextSecondary = Color(red: 0.45, green: 0.50, blue: 0.56)
    static let kakaSuccess = Color(red: 0.25, green: 0.72, blue: 0.47)
    static let kakaDanger = Color(red: 0.90, green: 0.31, blue: 0.29)
    static let kakaDivider = Color(red: 0.88, green: 0.91, blue: 0.94)
}

struct KakaTheme {
    /// 主按钮渐变
    static let primaryGradient = LinearGradient(
        colors: [Color.kakaBlue, Color.kakaBlueDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// 卡片圆角（Scarab：24 / 12pt）
    static let cardRadius: CGFloat = 24
    static let smallRadius: CGFloat = 12
    static let cardShadow = Color.black.opacity(0.05)
}

/// 统一的卡片容器
struct KakaCard<Content: View>: View {
    var radius: CGFloat = KakaTheme.cardRadius
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .background(Color.kakaCard)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: KakaTheme.cardShadow, radius: 10, x: 0, y: 4)
    }
}

/// 主按钮样式
struct KakaPrimaryButtonStyle: ButtonStyle {
    var disabled = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                disabled ? AnyShapeStyle(Color.gray.opacity(0.5))
                         : AnyShapeStyle(KakaTheme.primaryGradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: KakaTheme.smallRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 轻量按钮样式（白底描边）
struct KakaOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.kakaBlueDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: KakaTheme.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KakaTheme.smallRadius, style: .continuous)
                    .stroke(Color.kakaBlue.opacity(0.45), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// 通用加载框
struct KakaLoading: View {
    var text: String = "处理中..."
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.kakaBlueDeep)
            Text(L(text))
                .font(.system(size: 14))
                .foregroundStyle(Color.kakaTextSecondary)
        }
        .padding(28)
        .background(Color.kakaCard)
        .clipShape(RoundedRectangle(cornerRadius: KakaTheme.cardRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
    }
}

/// 统一 Toast 展示器
struct KakaToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.78))
            .clipShape(Capsule())
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
