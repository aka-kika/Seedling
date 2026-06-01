import SwiftUI

// MARK: - Section Header

struct KikaSectionHeader: View {
    let title: String
    @Environment(\.kikaTheme) private var theme

    var body: some View {
        Text(title)
            .font(KikaFont.title)
            .foregroundStyle(theme.textPrimary)
            .accessibilityAddTraits(.isHeader)  // VoiceOver rotor: Headings
            .accessibilityLabel(title)          // Stable label regardless of styling
    }
}

// MARK: - Divider

struct KikaDivider: View {
    @Environment(\.kikaTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.divider)
            .frame(height: 1)
    }
}

// MARK: - Row (icon + label + trailing control)

struct KikaRow<Control: View>: View {
    let icon: String
    let label: String
    @ViewBuilder var control: () -> Control

    @Environment(\.kikaTheme) private var theme

    var body: some View {
        HStack(spacing: KikaSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 18)
            Text(label)
                .font(KikaFont.body)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            control()
        }
        .frame(minHeight: 32)
    }
}

// MARK: - Button styles

struct KikaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.kikaTheme) private var theme
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(scheme == .dark ? Color(hex: 0x0C1A17) : .white)
            .padding(.vertical, 7)
            .padding(.horizontal, 18)
            .glassEffect(.regular.tint(theme.accent).interactive(), in: .rect(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct KikaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.kikaTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(theme.textSecondary)
            .padding(.vertical, 5)
            .padding(.horizontal, 12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - File row (custom: icon + label + subtitle-free toggle)

struct KikaFileToggleRow: View {
    let file: SeedFile
    @Binding var isSelected: Bool

    @Environment(\.kikaTheme) private var theme

    var body: some View {
        HStack(spacing: KikaSpacing.md) {
            Image(systemName: file.icon)
                .font(.system(size: 14))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(KikaFont.body)
                    .foregroundStyle(theme.textPrimary)
                if file.source == .userFolder {
                    Text("From templates")
                        .font(KikaFont.caption)
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            Toggle("", isOn: $isSelected)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .frame(minHeight: 32)
    }
}

// MARK: - Sidebar item (icon + label, used inside NavigationSplitView)

struct KikaSidebarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let badge: Int?

    @Environment(\.kikaTheme) private var theme

    var body: some View {
        HStack(spacing: KikaSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                .frame(width: 18)
            Text(label)
                .font(KikaFont.body)
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
            Spacer(minLength: 0)
            if let badge, badge > 0 {
                Text("\(badge)")
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(theme.elevated)
                    )
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, KikaSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? theme.elevated : .clear)
        )
        .contentShape(Rectangle())
    }
}
