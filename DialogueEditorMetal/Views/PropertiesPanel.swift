import SwiftUI

struct PropertiesPanel: View {
    @EnvironmentObject var graphModel: GraphModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("PROPERTIES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            ScrollView {
                if let selectedNode = graphModel.getSelectedNodes().first {
                    NodePropertiesView(node: selectedNode)
                } else if graphModel.selectedNodeIds.count > 1 {
                    MultipleSelectionView(count: graphModel.selectedNodeIds.count)
                } else {
                    EmptyPropertiesView()
                }
            }
        }
        .background(Color(hex: "0e0e10"))
    }
}

struct NodePropertiesView: View {
    @ObservedObject var node: DialogueNode
    @EnvironmentObject var graphModel: GraphModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Node type header
            HStack(spacing: 10) {
                Image(systemName: node.nodeType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(node.nodeType.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.nodeType.rawValue.capitalized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(node.technicalName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
            
            // Node-specific content
            switch node.data {
            case .dialogue(let data), .dialogueFragment(let data):
                DialoguePropertiesView(node: node, data: data)
            case .condition(let data):
                ConditionPropertiesView(node: node, data: data)
            case .instruction(let data):
                InstructionPropertiesView(node: node, data: data)
            case .branch:
                BranchPropertiesView(node: node)
            case .hub(let data):
                HubPropertiesView(node: node, data: data)
            case .jump(let data):
                JumpPropertiesView(node: node, data: data)
            case .skillCheck(let data):
                SkillCheckPropertiesView(node: node, data: data)
            case .thought(let data):
                ThoughtPropertiesView(node: node, data: data)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Position
            PropertySection(title: "Position") {
                HStack(spacing: 8) {
                    PropertyField(label: "X", value: Binding(
                        get: { String(format: "%.0f", node.position.x) },
                        set: { if let val = Double($0) { node.position.x = val } }
                    ))
                    
                    PropertyField(label: "Y", value: Binding(
                        get: { String(format: "%.0f", node.position.y) },
                        set: { if let val = Double($0) { node.position.y = val } }
                    ))
                }
            }
            
            // Size
            PropertySection(title: "Size") {
                HStack(spacing: 8) {
                    PropertyField(label: "W", value: Binding(
                        get: { String(format: "%.0f", node.size.width) },
                        set: { if let val = Double($0) { node.size.width = max(100, val) } }
                    ))
                    
                    PropertyField(label: "H", value: Binding(
                        get: { String(format: "%.0f", node.size.height) },
                        set: { if let val = Double($0) { node.size.height = max(60, val) } }
                    ))
                }
            }
            
            Spacer()
        }
        .padding(16)
    }
}

struct DialoguePropertiesView: View {
    @ObservedObject var node: DialogueNode
    let data: DialogueData
    @EnvironmentObject var graphModel: GraphModel
    @State private var text: String = ""
    @State private var speaker: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Speaker
            PropertySection(title: "Speaker") {
                Picker("Speaker", selection: $speaker) {
                    Text("None").tag("")
                    ForEach(graphModel.characters) { character in
                        Text(character.name).tag(character.id.uuidString)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            // Dialogue text
            PropertySection(title: "Text") {
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            // Menu text (optional)
            PropertySection(title: "Menu Text (Optional)") {
                TextField("Short text for dialogue choices...", text: .constant(""))
                    .textFieldStyle(PropertyTextFieldStyle())
            }
            
            // Auto-transition toggle
            Toggle(isOn: .constant(data.autoTransition)) {
                Text("Auto-transition")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "ff6633")))
        }
        .onAppear {
            text = data.text
            speaker = data.speaker ?? ""
        }
    }
}

struct ConditionPropertiesView: View {
    @ObservedObject var node: DialogueNode
    let data: ConditionData
    @State private var expression: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertySection(title: "Condition Expression") {
                TextEditor(text: $expression)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "4ade80").opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Output ports info
            VStack(alignment: .leading, spacing: 4) {
                Label("True → First output", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "4ade80"))
                
                Label("False → Second output", systemImage: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "ef4444"))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.03))
            )
        }
        .onAppear {
            expression = data.expression
        }
    }
}

struct InstructionPropertiesView: View {
    @ObservedObject var node: DialogueNode
    let data: InstructionData
    @State private var script: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertySection(title: "Script") {
                TextEditor(text: $script)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "8b5cf6").opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .onAppear {
            script = data.script
        }
    }
}

struct BranchPropertiesView: View {
    @ObservedObject var node: DialogueNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertySection(title: "Output Ports") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(node.outputPorts.enumerated()), id: \.offset) { index, port in
                        HStack {
                            Circle()
                                .fill(Color(hex: "7ed321"))
                                .frame(width: 8, height: 8)
                            
                            TextField("Label", text: .constant(port.label ?? "Out \(index + 1)"))
                                .textFieldStyle(PropertyTextFieldStyle())
                        }
                    }
                    
                    Button {
                        node.addOutputPort(label: "Out \(node.outputPorts.count + 1)")
                    } label: {
                        Label("Add Output", systemImage: "plus.circle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color(hex: "f59e0b"))
                }
            }
        }
    }
}

struct HubPropertiesView: View {
    @ObservedObject var node: DialogueNode
    let data: HubData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertySection(title: "Display Name") {
                TextField("Hub name...", text: .constant(data.displayName ?? ""))
                    .textFieldStyle(PropertyTextFieldStyle())
            }
            
            Text("Hubs collect multiple inputs and route to a single output.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.03))
                )
        }
    }
}

struct JumpPropertiesView: View {
    @ObservedObject var node: DialogueNode
    let data: JumpData
    @EnvironmentObject var graphModel: GraphModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertySection(title: "Jump Target") {
                Picker("Target", selection: .constant(data.targetNodeId?.uuidString ?? "")) {
                    Text("Select target...").tag("")
                    ForEach(graphModel.nodes.filter { $0.id != node.id }) { targetNode in
                        Text(targetNode.technicalName).tag(targetNode.id.uuidString)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            if data.targetNodeId != nil {
                Button {
                    // TODO: Navigate to target
                } label: {
                    Label("Go to Target", systemImage: "arrow.right.circle")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(hex: "ef4444"))
            }
        }
    }
}

struct SkillCheckPropertiesView: View {
    @ObservedObject var node: DialogueNode
    let data: SkillCheckData
    @State private var skillName: String = ""
    @State private var difficulty: Int = 10
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertySection(title: "Skill") {
                TextField("e.g., Rhetoric, Logic, Drama...", text: $skillName)
                    .textFieldStyle(PropertyTextFieldStyle())
            }
            
            PropertySection(title: "Difficulty") {
                HStack {
                    Slider(value: Binding(
                        get: { Double(difficulty) },
                        set: { difficulty = Int($0) }
                    ), in: 6...18, step: 1)
                    
                    Text("\(difficulty)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(difficultyColor)
                        .frame(width: 30)
                }
            }
            
            // Check type indicator
            HStack(spacing: 8) {
                Image(systemName: data.canRetry ? "dice.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(data.canRetry ? .white : Color(hex: "dc2626"))
                
                Text(data.canRetry ? "White Check (can retry)" : "Red Check (one shot)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
        }
        .onAppear {
            skillName = data.skillName
            difficulty = data.difficulty
        }
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case 6...8: return Color(hex: "4ade80")
        case 9...12: return Color(hex: "f59e0b")
        case 13...15: return Color(hex: "ef4444")
        default: return Color(hex: "dc2626")
        }
    }
}

struct ThoughtPropertiesView: View {
    @ObservedObject var node: DialogueNode
    let data: ThoughtData
    @State private var text: String = ""
    @State private var internalVoice: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertySection(title: "Internal Voice") {
                TextField("e.g., Logic, Empathy, Drama...", text: $internalVoice)
                    .textFieldStyle(PropertyTextFieldStyle())
            }
            
            PropertySection(title: "Thought") {
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.3)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "c084fc").opacity(0.3), lineWidth: 1))
            }
            
            Text("Internal thoughts appear as if your mind is speaking to you.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
        }
        .onAppear {
            text = data.text
            internalVoice = data.internalVoice ?? ""
        }
    }
}

struct MultipleSelectionView: View {
    let count: Int
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.3))
            
            Text("\(count) nodes selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Select a single node to edit its properties")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

struct EmptyPropertiesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Getting Started")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Quick actions to build your dialogue")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            // Quick actions
            VStack(alignment: .leading, spacing: 12) {
                QuickActionHint(
                    icon: "cursorarrow.click.2",
                    action: "Double-click canvas",
                    result: "Create dialogue node"
                )
                
                QuickActionHint(
                    icon: "arrow.right.circle",
                    action: "Drag from port",
                    result: "Connect nodes"
                )
                
                QuickActionHint(
                    icon: "keyboard",
                    action: "D key",
                    result: "Quick dialogue"
                )
                
                QuickActionHint(
                    icon: "hand.draw",
                    action: "Space + drag",
                    result: "Pan canvas"
                )
                
                QuickActionHint(
                    icon: "arrow.up.left.and.arrow.down.right",
                    action: "Scroll / pinch",
                    result: "Zoom"
                )
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Keyboard shortcuts
            VStack(alignment: .leading, spacing: 8) {
                Text("SHORTCUTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                
                ShortcutHint(keys: "⌘Z", action: "Undo")
                ShortcutHint(keys: "⌘⇧Z", action: "Redo")
                ShortcutHint(keys: "⌘D", action: "Duplicate")
                ShortcutHint(keys: "⌫", action: "Delete")
                ShortcutHint(keys: "⌘A", action: "Select all")
            }
        }
        .padding(16)
    }
}

struct QuickActionHint: View {
    let icon: String
    let action: String
    let result: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "ff6633"))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(action)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(result)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

struct ShortcutHint: View {
    let keys: String
    let action: String
    
    var body: some View {
        HStack {
            Text(keys)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 44, alignment: .leading)
            
            Text(action)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Helper Views

struct PropertySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            
            content
        }
    }
}

struct PropertyField: View {
    let label: String
    @Binding var value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 14)
            
            TextField("", text: $value)
                .textFieldStyle(PropertyTextFieldStyle())
        }
    }
}

struct PropertyTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

#if DEBUG
struct PropertiesPanel_Previews: PreviewProvider {
    static var previews: some View {
        PropertiesPanel()
            .environmentObject(GraphModel())
            .frame(width: 300, height: 600)
    }
}
#endif
