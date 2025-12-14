import SwiftUI

// MARK: - Design System (Susan Kare 2030)
// Single source of truth for all design tokens
// Utilitarian, dense, monospace, functional

enum DS {
    
    // MARK: - Colors
    enum Colors {
        // Backgrounds (near-black, no blue tint)
        static let bg0 = Color(hex: "09090b")      // Deepest
        static let bg1 = Color(hex: "0f0f11")      // Panels
        static let bg2 = Color(hex: "18181b")      // Cards/inputs
        static let bg3 = Color(hex: "27272a")      // Hover states
        
        // Borders
        static let border0 = Color(hex: "27272a")  // Subtle
        static let border1 = Color(hex: "3f3f46")  // Default
        static let border2 = Color(hex: "52525b")  // Emphasis
        
        // Text
        static let text0 = Color(hex: "fafafa")    // Primary
        static let text1 = Color(hex: "a1a1aa")    // Secondary
        static let text2 = Color(hex: "71717a")    // Tertiary
        static let text3 = Color(hex: "52525b")    // Disabled
        
        // Accent (warm orange - functional, not decorative)
        static let accent = Color(hex: "f97316")   // Primary action
        static let accentMuted = Color(hex: "ea580c").opacity(0.15)
        
        // Semantic
        static let success = Color(hex: "22c55e")
        static let warning = Color(hex: "eab308")
        static let error = Color(hex: "ef4444")
        
        // Node type colors (muted, professional)
        static let nodeDialogue = Color(hex: "3b82f6")
        static let nodeBranch = Color(hex: "a855f7")
        static let nodeCondition = Color(hex: "22c55e")
        static let nodeHub = Color(hex: "f97316")
        static let nodeCheck = Color(hex: "ef4444")
    }
    
    // MARK: - Typography
    enum Font {
        // Font family
        static let mono = SwiftUI.Font.system(.body, design: .monospaced)
        
        // Sizes (compact, dense)
        static let xs: CGFloat = 9
        static let sm: CGFloat = 11
        static let base: CGFloat = 12
        static let md: CGFloat = 13
        static let lg: CGFloat = 14
        
        // Weights
        static let regular = SwiftUI.Font.Weight.regular
        static let medium = SwiftUI.Font.Weight.medium
        static let semibold = SwiftUI.Font.Weight.semibold
        static let bold = SwiftUI.Font.Weight.bold
        
        // Pre-built styles
        static let label = SwiftUI.Font.system(size: xs, weight: .semibold, design: .monospaced)
        static let body = SwiftUI.Font.system(size: base, weight: .regular, design: .monospaced)
        static let bodyMedium = SwiftUI.Font.system(size: base, weight: .medium, design: .monospaced)
        static let caption = SwiftUI.Font.system(size: sm, weight: .regular, design: .monospaced)
        static let heading = SwiftUI.Font.system(size: md, weight: .semibold, design: .monospaced)
        static let code = SwiftUI.Font.system(size: sm, weight: .regular, design: .monospaced)
    }
    
    // MARK: - Spacing (tight, utilitarian)
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Radii (minimal, sharp)
    enum Radius {
        static let none: CGFloat = 0
        static let xs: CGFloat = 2
        static let sm: CGFloat = 3
        static let md: CGFloat = 4
        static let lg: CGFloat = 6
    }
    
    // MARK: - Sizes
    enum Size {
        static let iconSm: CGFloat = 12
        static let iconMd: CGFloat = 14
        static let iconLg: CGFloat = 16
        
        static let buttonHeight: CGFloat = 24
        static let inputHeight: CGFloat = 24
        static let toolbarHeight: CGFloat = 32
        static let headerHeight: CGFloat = 28
        
        static let sidebarWidth: CGFloat = 160
        static let propertiesWidth: CGFloat = 240
    }
    
    // MARK: - Animation (subtle, fast)
    enum Anim {
        static let fast = Animation.easeOut(duration: 0.1)
        static let normal = Animation.easeOut(duration: 0.15)
        static let slow = Animation.easeOut(duration: 0.25)
    }
}

// MARK: - Reusable Components

struct DSButton: View {
    let label: String
    let icon: String?
    let style: Style
    let action: () -> Void
    
    @State private var isHovered = false
    
    enum Style { case primary, secondary, ghost }
    
    init(_ label: String, icon: String? = nil, style: Style = .secondary, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: DS.Size.iconSm))
                }
                Text(label)
                    .font(DS.Font.caption)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, DS.Space.md)
            .frame(height: DS.Size.buttonHeight)
            .background(backgroundColor)
            .cornerRadius(DS.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    var foregroundColor: Color {
        switch style {
        case .primary: return DS.Colors.bg0
        case .secondary, .ghost: return isHovered ? DS.Colors.text0 : DS.Colors.text1
        }
    }
    
    var backgroundColor: Color {
        switch style {
        case .primary: return isHovered ? DS.Colors.accent.opacity(0.9) : DS.Colors.accent
        case .secondary: return isHovered ? DS.Colors.bg3 : DS.Colors.bg2
        case .ghost: return isHovered ? DS.Colors.bg2 : .clear
        }
    }
    
    var borderColor: Color {
        switch style {
        case .primary: return .clear
        case .secondary: return DS.Colors.border0
        case .ghost: return .clear
        }
    }
}

struct DSInput: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(DS.Font.body)
            .foregroundColor(DS.Colors.text0)
            .padding(.horizontal, DS.Space.md)
            .frame(height: DS.Size.inputHeight)
            .background(DS.Colors.bg2)
            .cornerRadius(DS.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(DS.Colors.border0, lineWidth: 1)
            )
    }
}

struct DSLabel: View {
    let text: String
    
    var body: some View {
        Text(text.uppercased())
            .font(DS.Font.label)
            .foregroundColor(DS.Colors.text2)
            .tracking(0.5)
    }
}

struct DSDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.Colors.border0)
            .frame(height: 1)
    }
}

struct DSIconButton: View {
    let icon: String
    let action: () -> Void
    var isActive: Bool = false
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconMd))
                .foregroundColor(isActive ? DS.Colors.accent : (isHovered ? DS.Colors.text0 : DS.Colors.text1))
                .frame(width: DS.Size.buttonHeight, height: DS.Size.buttonHeight)
                .background(isActive ? DS.Colors.accentMuted : (isHovered ? DS.Colors.bg3 : .clear))
                .cornerRadius(DS.Radius.sm)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Color Extension (keep existing)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
