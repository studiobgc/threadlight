import SwiftUI

/// "Writers hate a blank page" - This menu appears when you drag from a port into empty space
/// It makes continuing dialogue as frictionless as possible
struct QuickCreateMenu: View {
    @EnvironmentObject var graphModel: GraphModel
    
    let position: CGPoint
    let sourceNodeId: UUID
    let sourcePortIndex: Int
    let onSelect: (NodeType, UUID?) -> Void  // NodeType + optional speakerId
    let onCancel: () -> Void
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.system(size: 12))
                
                TextField("Type to filter...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onSubmit {
                        selectCurrentItem()
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
            
            Divider().background(Color.white.opacity(0.1))
            
            // Quick actions based on context
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Continue with same speaker (if source was dialogue)
                    if let lastSpeaker = getLastSpeaker() {
                        QuickCreateSection(title: "CONTINUE") {
                            QuickCreateItem(
                                icon: "arrow.right",
                                title: "Continue as \(lastSpeaker.name)",
                                subtitle: "Tab or Enter",
                                color: Color(hex: lastSpeaker.color),
                                isSelected: selectedIndex == 0
                            ) {
                                onSelect(.dialogueFragment, lastSpeaker.id)
                            }
                        }
                    }
                    
                    // Character options
                    QuickCreateSection(title: "CHARACTERS") {
                        ForEach(Array(filteredCharacters.enumerated()), id: \.element.id) { index, character in
                            let itemIndex = (getLastSpeaker() != nil ? 1 : 0) + index
                            QuickCreateItem(
                                icon: "person.fill",
                                title: character.name,
                                subtitle: character.shortName,
                                color: Color(hex: character.color),
                                isSelected: selectedIndex == itemIndex
                            ) {
                                onSelect(.dialogueFragment, character.id)
                            }
                        }
                        
                        // Add new character
                        QuickCreateItem(
                            icon: "person.badge.plus",
                            title: "New Character...",
                            subtitle: nil,
                            color: .white.opacity(0.5),
                            isSelected: false
                        ) {
                            // TODO: Show character creation
                        }
                    }
                    
                    // Structure nodes
                    QuickCreateSection(title: "STRUCTURE") {
                        ForEach(structureNodeTypes, id: \.self) { type in
                            QuickCreateItem(
                                icon: type.icon,
                                title: type.rawValue.capitalized,
                                subtitle: type.shortcutKey,
                                color: type.color,
                                isSelected: false
                            ) {
                                onSelect(type, nil)
                            }
                        }
                    }
                    
                    // Disco-style checks
                    QuickCreateSection(title: "SKILL CHECKS") {
                        QuickCreateItem(
                            icon: "dice.fill",
                            title: "White Check",
                            subtitle: "W · Can retry",
                            color: Color(hex: "fafafa"),
                            isSelected: false
                        ) {
                            onSelect(.whiteCheck, nil)
                        }
                        
                        QuickCreateItem(
                            icon: "exclamationmark.triangle.fill",
                            title: "Red Check",
                            subtitle: "R · One shot",
                            color: Color(hex: "dc2626"),
                            isSelected: false
                        ) {
                            onSelect(.redCheck, nil)
                        }
                        
                        QuickCreateItem(
                            icon: "brain.head.profile",
                            title: "Thought",
                            subtitle: "T · Internal",
                            color: Color(hex: "c084fc"),
                            isSelected: false
                        ) {
                            onSelect(.thought, nil)
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "1a1a2e"))
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(selectedIndex + 1, totalItems - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
    }
    
    private var filteredCharacters: [Character] {
        if searchText.isEmpty {
            return graphModel.characters
        }
        return graphModel.characters.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var structureNodeTypes: [NodeType] {
        [.branch, .hub, .condition, .instruction]
    }
    
    private var totalItems: Int {
        (getLastSpeaker() != nil ? 1 : 0) + filteredCharacters.count + structureNodeTypes.count + 3
    }
    
    private func getLastSpeaker() -> Character? {
        guard let sourceNode = graphModel.getNode(sourceNodeId) else { return nil }
        
        switch sourceNode.data {
        case .dialogue(let data), .dialogueFragment(let data):
            if let speakerId = data.speakerId {
                return graphModel.characters.first { $0.id == speakerId }
            }
        default:
            break
        }
        return nil
    }
    
    private func selectCurrentItem() {
        if let speaker = getLastSpeaker(), selectedIndex == 0 {
            onSelect(.dialogueFragment, speaker.id)
        } else if selectedIndex < filteredCharacters.count + (getLastSpeaker() != nil ? 1 : 0) {
            let charIndex = selectedIndex - (getLastSpeaker() != nil ? 1 : 0)
            if charIndex >= 0 && charIndex < filteredCharacters.count {
                onSelect(.dialogueFragment, filteredCharacters[charIndex].id)
            }
        }
    }
}

struct QuickCreateSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.top, 8)
            
            content
        }
    }
}

struct QuickCreateItem: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon with color
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(color)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                // Subtitle / shortcut
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected || isHovered ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#if DEBUG
@available(macOS 14.0, *)
struct QuickCreateMenu_Preview: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(hex: "1e1e2e")
            
            QuickCreateMenu(
                position: CGPoint(x: 200, y: 200),
                sourceNodeId: UUID(),
                sourcePortIndex: 0,
                onSelect: { _, _ in },
                onCancel: { }
            )
            .environmentObject(GraphModel())
        }
        .frame(width: 400, height: 600)
    }
}
#endif
