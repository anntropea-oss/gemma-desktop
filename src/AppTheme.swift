import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.075)
    static let panel = Color(red: 0.086, green: 0.098, blue: 0.118)
    static let panelRaised = Color(red: 0.115, green: 0.129, blue: 0.153)
    static let border = Color(red: 0.23, green: 0.25, blue: 0.29)
    static let text = Color(red: 0.91, green: 0.92, blue: 0.90)
    static let muted = Color(red: 0.58, green: 0.61, blue: 0.65)
    static let terminalGreen = Color(red: 0.38, green: 0.94, blue: 0.64)
    static let codexBlue = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let amber = Color(red: 0.96, green: 0.72, blue: 0.31)
    static let error = Color(red: 1.0, green: 0.36, blue: 0.43)
}

struct TerminalButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? AppTheme.background : accent)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? accent : accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(accent.opacity(configuration.isPressed ? 0.9 : 0.45))
            )
    }
}

struct StatusPill: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .foregroundStyle(accent)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(accent.opacity(0.35))
        )
    }
}

