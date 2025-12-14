import SwiftUI

// MARK: - Figma-Inspired Micro-Interactions
// Key principles from Figma:
// 1. Spring physics for organic movement
// 2. Immediate feedback (no perceptible delay)
// 3. Subtle but noticeable state changes
// 4. Consistent timing across similar actions
// 5. Easing that matches user expectation

struct MicroInteractions {
    
    // MARK: - Animation Curves (Figma uses custom spring physics)
    struct Curves {
        // Quick, snappy response for immediate feedback
        static let quick = Animation.spring(response: 0.2, dampingFraction: 0.8)
        
        // Standard interaction response
        static let standard = Animation.spring(response: 0.3, dampingFraction: 0.7)
        
        // Smooth, flowing for larger movements
        static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.75)
        
        // Bouncy for playful feedback
        static let bouncy = Animation.spring(response: 0.35, dampingFraction: 0.5)
        
        // Zoom animations (slightly slower, more dramatic)
        static let zoom = Animation.spring(response: 0.45, dampingFraction: 0.8)
        
        // Ultra-fast for hover states
        static let hover = Animation.easeOut(duration: 0.12)
        
        // Instant (for things that shouldn't animate)
        static let instant = Animation.linear(duration: 0)
    }
    
    // MARK: - Timing Constants
    struct Timing {
        static let hoverDelay: Double = 0.05          // Delay before hover effect
        static let tooltipDelay: Double = 0.5         // Delay before tooltip appears
        static let feedbackDuration: Double = 0.15    // Quick feedback flash
        static let selectionDuration: Double = 0.2    // Selection state change
        static let panelTransition: Double = 0.25     // Panel open/close
    }
    
    // MARK: - Scale Effects
    struct Scale {
        static let pressed: CGFloat = 0.95            // Button pressed
        static let hover: CGFloat = 1.02              // Subtle hover lift
        static let selected: CGFloat = 1.0            // No scale for selection (use glow instead)
        static let dragging: CGFloat = 1.05           // Node being dragged
        static let dropped: CGFloat = 1.0             // Return to normal after drop
    }
    
    // MARK: - Opacity Effects
    struct Opacity {
        static let disabled: Double = 0.4
        static let secondary: Double = 0.6
        static let hover: Double = 0.8
        static let active: Double = 1.0
        static let ghostNode: Double = 0.5            // Node being dragged from palette
        static let connectionPreview: Double = 0.7
    }
    
    // MARK: - Glow & Shadow
    struct Effects {
        static let selectionGlowRadius: CGFloat = 8
        static let hoverGlowRadius: CGFloat = 4
        static let portGlowRadius: CGFloat = 6
        static let dragShadowRadius: CGFloat = 20
        static let dragShadowOpacity: Double = 0.3
    }
}

// MARK: - Animated View Modifiers

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? MicroInteractions.Scale.pressed : 1.0)
            .animation(MicroInteractions.Curves.quick, value: configuration.isPressed)
    }
}

struct HoverScaleEffect: ViewModifier {
    @State private var isHovered = false
    let scale: CGFloat
    
    init(scale: CGFloat = MicroInteractions.Scale.hover) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(MicroInteractions.Curves.hover, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct SelectionGlow: ViewModifier {
    let isSelected: Bool
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: isSelected ? color.opacity(0.6) : .clear,
                radius: isSelected ? MicroInteractions.Effects.selectionGlowRadius : 0
            )
            .animation(MicroInteractions.Curves.standard, value: isSelected)
    }
}

struct HoverGlow: ViewModifier {
    @State private var isHovered = false
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: isHovered ? color.opacity(0.3) : .clear,
                radius: isHovered ? MicroInteractions.Effects.hoverGlowRadius : 0
            )
            .animation(MicroInteractions.Curves.hover, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct DragShadow: ViewModifier {
    let isDragging: Bool
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: .black.opacity(isDragging ? MicroInteractions.Effects.dragShadowOpacity : 0),
                radius: isDragging ? MicroInteractions.Effects.dragShadowRadius : 0,
                y: isDragging ? 10 : 0
            )
            .scaleEffect(isDragging ? MicroInteractions.Scale.dragging : 1.0)
            .animation(MicroInteractions.Curves.standard, value: isDragging)
    }
}

struct ShakeEffect: ViewModifier {
    let trigger: Bool
    @State private var shake = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: shake ? -5 : 0)
            .animation(
                Animation.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true),
                value: shake
            )
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    shake = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shake = false
                    }
                }
            }
    }
}

struct PulseEffect: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                if isActive {
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        scale = 1.05
                    }
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        scale = 1.05
                    }
                } else {
                    withAnimation(MicroInteractions.Curves.quick) {
                        scale = 1.0
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func pressableStyle() -> some View {
        buttonStyle(PressableStyle())
    }
    
    func hoverScale(_ scale: CGFloat = MicroInteractions.Scale.hover) -> some View {
        modifier(HoverScaleEffect(scale: scale))
    }
    
    func selectionGlow(isSelected: Bool, color: Color = Color(hex: "ff6633")) -> some View {
        modifier(SelectionGlow(isSelected: isSelected, color: color))
    }
    
    func hoverGlow(color: Color = .white) -> some View {
        modifier(HoverGlow(color: color))
    }
    
    func dragShadow(isDragging: Bool) -> some View {
        modifier(DragShadow(isDragging: isDragging))
    }
    
    func shakeOnError(trigger: Bool) -> some View {
        modifier(ShakeEffect(trigger: trigger))
    }
    
    func pulseWhenActive(_ isActive: Bool) -> some View {
        modifier(PulseEffect(isActive: isActive))
    }
}

// MARK: - Connection Animation

struct ConnectionFlow: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let isPreview: Bool
    
    @State private var progress: CGFloat = 0
    
    var body: some View {
        Canvas { context, size in
            let path = createBezierPath(from: from, to: to)
            
            // Draw base connection
            context.stroke(
                path,
                with: .color(color.opacity(isPreview ? 0.5 : 0.8)),
                lineWidth: isPreview ? 2 : 3
            )
            
            // Animated flow dots (Figma-style)
            if !isPreview {
                let dotCount = 5
                for i in 0..<dotCount {
                    let t = (progress + CGFloat(i) / CGFloat(dotCount)).truncatingRemainder(dividingBy: 1.0)
                    let point = pointOnBezier(t: t, from: from, to: to)
                    
                    context.fill(
                        Circle().path(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                        with: .color(color)
                    )
                }
            }
        }
        .onAppear {
            if !isPreview {
                withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                    progress = 1
                }
            }
        }
    }
    
    private func createBezierPath(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)
        
        let dx = to.x - from.x
        let controlOffset = min(abs(dx) * 0.5, 150)
        
        let cp1 = CGPoint(x: from.x + controlOffset, y: from.y)
        let cp2 = CGPoint(x: to.x - controlOffset, y: to.y)
        
        path.addCurve(to: to, control1: cp1, control2: cp2)
        return path
    }
    
    private func pointOnBezier(t: CGFloat, from: CGPoint, to: CGPoint) -> CGPoint {
        let dx = to.x - from.x
        let controlOffset = min(abs(dx) * 0.5, 150)
        
        let cp1 = CGPoint(x: from.x + controlOffset, y: from.y)
        let cp2 = CGPoint(x: to.x - controlOffset, y: to.y)
        
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t
        
        return CGPoint(
            x: mt3 * from.x + 3 * mt2 * t * cp1.x + 3 * mt * t2 * cp2.x + t3 * to.x,
            y: mt3 * from.y + 3 * mt2 * t * cp1.y + 3 * mt * t2 * cp2.y + t3 * to.y
        )
    }
}

// MARK: - Port Interaction Indicator

struct PortIndicator: View {
    let position: CGPoint
    let isInput: Bool
    let isConnected: Bool
    let isHovered: Bool
    let isValidTarget: Bool
    let color: Color
    
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer glow when hovered or valid target
            if isHovered || isValidTarget {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .scaleEffect(pulseScale)
            }
            
            // Main port circle
            Circle()
                .fill(isConnected ? color : Color(hex: "2a2a3d"))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: 2)
                )
            
            // Center dot when not connected
            if !isConnected {
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: 4, height: 4)
            }
        }
        .position(position)
        .animation(MicroInteractions.Curves.quick, value: isHovered)
        .onAppear {
            if isValidTarget {
                withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulseScale = 1.3
                }
            }
        }
    }
}

// MARK: - Selection Box

struct SelectionBox: View {
    let origin: CGPoint
    let current: CGPoint
    
    var body: some View {
        let minX = min(origin.x, current.x)
        let minY = min(origin.y, current.y)
        let width = abs(current.x - origin.x)
        let height = abs(current.y - origin.y)
        
        Rectangle()
            .fill(Color(hex: "ff6633").opacity(0.1))
            .overlay(
                Rectangle()
                    .stroke(Color(hex: "ff6633"), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            )
            .frame(width: width, height: height)
            .position(x: minX + width / 2, y: minY + height / 2)
    }
}

// MARK: - Keyboard Cursor (Figma-style)

struct KeyboardCursor: View {
    let position: CGPoint
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            // Crosshair
            Group {
                Rectangle()
                    .fill(Color(hex: "ec4899"))
                    .frame(width: 1, height: 20)
                
                Rectangle()
                    .fill(Color(hex: "ec4899"))
                    .frame(width: 20, height: 1)
            }
            
            // Center dot
            Circle()
                .fill(Color(hex: "ec4899"))
                .frame(width: 6, height: 6)
        }
        .position(position)
        .opacity(opacity)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                opacity = 0.5
            }
        }
    }
}

// MARK: - Toast Notification

struct Toast: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool
    
    enum ToastType {
        case info, success, warning, error
        
        var color: Color {
            switch self {
            case .info: return Color(hex: "3b82f6")
            case .success: return Color(hex: "4ade80")
            case .warning: return Color(hex: "f59e0b")
            case .error: return Color(hex: "ef4444")
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "101012"))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(MicroInteractions.Curves.standard) {
                    isShowing = false
                }
            }
        }
    }
}

// MARK: - Tooltip

struct Tooltip: View {
    let text: String
    let shortcut: String?
    
    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white)
            
            if let shortcut = shortcut {
                Text(shortcut)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "101012"))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        )
    }
}

// MARK: - Command Palette (Figma-style Quick Actions)

struct CommandPalette: View {
    @Binding var isShowing: Bool
    @State private var searchText = ""
    @EnvironmentObject var graphModel: GraphModel
    
    let commands: [Command] = [
        Command(name: "Add Dialogue Node", shortcut: "T", icon: "bubble.left.fill", action: .addNode(.dialogue)),
        Command(name: "Add Branch", shortcut: "B", icon: "arrow.triangle.branch", action: .addNode(.branch)),
        Command(name: "Add Condition", shortcut: nil, icon: "questionmark.diamond.fill", action: .addNode(.condition)),
        Command(name: "Add Hub", shortcut: nil, icon: "circle.hexagongrid.fill", action: .addNode(.hub)),
        Command(name: "Zoom to Fit", shortcut: "⌘1", icon: "arrow.up.left.and.arrow.down.right", action: .zoomToFit),
        Command(name: "Zoom to 100%", shortcut: "⌘0", icon: "1.magnifyingglass", action: .resetZoom),
        Command(name: "Select All", shortcut: "⌘A", icon: "selection.pin.in.out", action: .selectAll),
        Command(name: "Delete Selection", shortcut: "⌫", icon: "trash", action: .deleteSelection),
        Command(name: "Duplicate", shortcut: "⌘D", icon: "plus.square.on.square", action: .duplicate),
        Command(name: "Undo", shortcut: "⌘Z", icon: "arrow.uturn.backward", action: .undo),
        Command(name: "Redo", shortcut: "⇧⌘Z", icon: "arrow.uturn.forward", action: .redo),
    ]
    
    var filteredCommands: [Command] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                
                TextField("Search commands...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(Color(hex: "0e0e10"))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Commands list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCommands) { command in
                        CommandRow(command: command) {
                            executeCommand(command)
                            isShowing = false
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 350)
        .background(Color(hex: "101012"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func executeCommand(_ command: Command) {
        switch command.action {
        case .addNode(let type):
            graphModel.addNode(type: type, at: CGPoint(x: 400, y: 300))
        case .zoomToFit:
            // TODO: Implement
            break
        case .resetZoom:
            graphModel.viewportZoom = 1.0
            graphModel.viewportOffset = .zero
        case .selectAll:
            graphModel.selectAll()
        case .deleteSelection:
            graphModel.deleteSelection()
        case .duplicate:
            graphModel.duplicateSelection(offset: CGPoint(x: 20, y: 20))
        case .undo:
            graphModel.undo()
        case .redo:
            graphModel.redo()
        }
    }
}

struct Command: Identifiable {
    let id = UUID()
    let name: String
    let shortcut: String?
    let icon: String
    let action: CommandAction
    
    enum CommandAction {
        case addNode(NodeType)
        case zoomToFit
        case resetZoom
        case selectAll
        case deleteSelection
        case duplicate
        case undo
        case redo
    }
}

struct CommandRow: View {
    let command: Command
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: command.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24)
                
                Text(command.name)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
