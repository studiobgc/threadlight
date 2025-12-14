import Foundation
import SwiftUI

enum NodeType: String, CaseIterable, Codable {
    case dialogue
    case dialogueFragment
    case branch
    case condition
    case instruction
    case hub
    case jump
    case whiteCheck      // Disco-style: can retry, easier
    case redCheck         // Disco-style: one shot, harder
    case passiveCheck     // Disco-style: skill interjects automatically
    case thought          // Internal monologue / Thought Cabinet
    
    var defaultSize: CGSize {
        switch self {
        case .dialogue, .dialogueFragment:
            return CGSize(width: 300, height: 100)  // Wider for text
        case .branch:
            return CGSize(width: 220, height: 90)
        case .condition:
            return CGSize(width: 200, height: 70)
        case .instruction:
            return CGSize(width: 200, height: 70)
        case .hub:
            return CGSize(width: 180, height: 80)
        case .jump:
            return CGSize(width: 140, height: 50)
        case .whiteCheck:
            return CGSize(width: 260, height: 90)
        case .redCheck:
            return CGSize(width: 260, height: 90)
        case .passiveCheck:
            return CGSize(width: 280, height: 80)
        case .thought:
            return CGSize(width: 320, height: 110)
        }
    }
    
    var color: Color {
        switch self {
        case .dialogue:
            return Color(hex: "3b82f6")   // Blue - main dialogue
        case .dialogueFragment:
            return Color(hex: "60a5fa")   // Lighter blue - fragments
        case .branch:
            return Color(hex: "f59e0b")   // Amber - choices
        case .condition:
            return Color(hex: "10b981")   // Emerald - logic
        case .instruction:
            return Color(hex: "8b5cf6")   // Purple - scripts
        case .hub:
            return Color(hex: "475569")   // Slate - structure
        case .jump:
            return Color(hex: "f43f5e")   // Rose - navigation
        case .whiteCheck:
            return Color(hex: "fafafa")   // White - retryable checks
        case .redCheck:
            return Color(hex: "dc2626")   // Red - one-shot checks
        case .passiveCheck:
            return Color(hex: "a3a3a3")   // Gray - passive interjections
        case .thought:
            return Color(hex: "c084fc")   // Light purple - internal
        }
    }
    
    var icon: String {
        switch self {
        case .dialogue:
            return "bubble.left.fill"
        case .dialogueFragment:
            return "text.bubble.fill"
        case .branch:
            return "arrow.triangle.branch"
        case .condition:
            return "questionmark.diamond.fill"
        case .instruction:
            return "gearshape.fill"
        case .hub:
            return "circle.hexagongrid.fill"
        case .jump:
            return "arrow.uturn.right"
        case .whiteCheck:
            return "dice.fill"              // Can retry
        case .redCheck:
            return "exclamationmark.triangle.fill"  // One shot
        case .passiveCheck:
            return "eye.fill"               // Passive observation
        case .thought:
            return "brain.head.profile"     // Internal thought
        }
    }
    
    var shortcutKey: String? {
        switch self {
        case .dialogue: return "D"
        case .dialogueFragment: return "F"
        case .branch: return "B"
        case .condition: return "C"
        case .whiteCheck: return "W"
        case .redCheck: return "R"
        case .thought: return "T"
        default: return nil
        }
    }
    
    var keyboardShortcut: String? {
        shortcutKey
    }
    
    /// Short description shown inline on hover
    var description: String {
        switch self {
        case .dialogue:
            return "A character speaks. Connect to choices or other dialogue."
        case .dialogueFragment:
            return "Continue dialogue from same speaker without a new node."
        case .branch:
            return "Player choice point. Each output = one option."
        case .condition:
            return "Check a variable. True→top output, False→bottom."
        case .instruction:
            return "Run script code. Set variables, trigger events."
        case .hub:
            return "Merge multiple paths into one. Good for convergent stories."
        case .jump:
            return "Jump to another node anywhere in the graph."
        case .whiteCheck:
            return "Skill check (retryable). Player can try again later."
        case .redCheck:
            return "Skill check (one-shot). Fail = locked forever."
        case .passiveCheck:
            return "Auto-triggers when conditions met. No player action."
        case .thought:
            return "Internal voice. Like Disco Elysium's skill thoughts."
        }
    }
    
    /// Full description for native macOS tooltip
    var fullDescription: String {
        switch self {
        case .dialogue:
            return "Dialogue Node — A character speaks a line. Assign a speaker, write text, and connect to the next beat. The foundation of all conversations."
        case .dialogueFragment:
            return "Fragment — Continues dialogue from the same speaker. Use for long speeches or when you want to add pauses/choices mid-sentence."
        case .branch:
            return "Branch — Presents player choices. Each output port is a different option. The player picks one path forward."
        case .condition:
            return "Condition — Evaluates an expression. Routes to 'True' (top) or 'False' (bottom) based on game variables or flags."
        case .instruction:
            return "Instruction — Executes code when reached. Set variables, unlock achievements, trigger events. No visible dialogue."
        case .hub:
            return "Hub — Collects multiple incoming paths into one exit. Use when different choices lead to the same outcome."
        case .jump:
            return "Jump — Teleports flow to another node. Useful for callbacks, loops, or organizing complex graphs."
        case .whiteCheck:
            return "White Check (Disco Elysium style) — A skill check the player can retry later if they fail. Difficulty shown, dice rolled."
        case .redCheck:
            return "Red Check (Disco Elysium style) — A one-shot skill check. If you fail, it's locked forever. High stakes."
        case .passiveCheck:
            return "Passive Check — Triggers automatically when the player's skill is high enough. The skill 'speaks up' without prompting."
        case .thought:
            return "Thought — Internal monologue from one of the player's mental 'voices' (Logic, Empathy, Drama, etc). Like Disco Elysium's skill interjections."
        }
    }
    
    var isDialogueType: Bool {
        switch self {
        case .dialogue, .dialogueFragment, .thought:
            return true
        default:
            return false
        }
    }
    
    var isCheckType: Bool {
        switch self {
        case .whiteCheck, .redCheck, .passiveCheck:
            return true
        default:
            return false
        }
    }
    
    var minInputPorts: Int {
        switch self {
        case .dialogue, .dialogueFragment, .condition, .instruction, .hub, .jump, .thought:
            return 1
        case .branch:
            return 1
        case .whiteCheck, .redCheck:
            return 1
        case .passiveCheck:
            return 0  // Passive checks can trigger without explicit input
        }
    }
    
    var minOutputPorts: Int {
        switch self {
        case .dialogue, .dialogueFragment, .instruction, .hub, .jump, .thought:
            return 1
        case .branch:
            return 2
        case .condition:
            return 2
        case .whiteCheck, .redCheck:  // Success / Failure
            return 2
        case .passiveCheck:
            return 1  // Just continues if triggered
        }
    }
}

struct Port: Identifiable, Codable {
    let id: UUID
    var nodeId: UUID
    var type: PortType
    var index: Int
    var label: String?
    
    enum PortType: String, Codable {
        case input
        case output
    }
    
    init(nodeId: UUID, type: PortType, index: Int, label: String? = nil) {
        self.id = UUID()
        self.nodeId = nodeId
        self.type = type
        self.index = index
        self.label = label
    }
}

struct DialogueData: Codable {
    var speaker: String?
    var speakerId: UUID?
    var text: String
    var menuText: String?        // Short text shown in choice menus
    var stageDirections: String? // Director notes, not shown to player
    var autoTransition: Bool     // Auto-advance without player input
    var voiceClip: String?       // Audio file reference
    var emotion: String?         // Character emotion for portrait
    
    init() {
        self.text = ""
        self.autoTransition = false
    }
}

// Disco Elysium-style skill check
struct SkillCheckData: Codable {
    var skillName: String        // e.g., "Rhetoric", "Drama", "Logic"
    var difficulty: Int          // Target number (typically 6-18)
    var modifiers: [String]      // Situational modifiers
    var successText: String      // What happens on success
    var failureText: String      // What happens on failure
    var isPassive: Bool          // Does it trigger automatically?
    var canRetry: Bool           // White check = true, Red check = false
    
    init(skillName: String = "", difficulty: Int = 10) {
        self.skillName = skillName
        self.difficulty = difficulty
        self.modifiers = []
        self.successText = ""
        self.failureText = ""
        self.isPassive = false
        self.canRetry = true
    }
}

// Internal thought / Thought Cabinet style
struct ThoughtData: Codable {
    var text: String
    var internalVoice: String?   // Which "voice" is speaking (like DE's skills)
    var isInternalized: Bool     // Has this thought been "completed"?
    
    init() {
        self.text = ""
        self.isInternalized = false
    }
}

struct BranchData: Codable {
    // Branch nodes primarily use multiple outputs
}

struct ConditionData: Codable {
    var expression: String
    
    init() {
        self.expression = ""
    }
}

struct InstructionData: Codable {
    var script: String
    
    init() {
        self.script = ""
    }
}

struct HubData: Codable {
    var displayName: String?
}

struct JumpData: Codable {
    var targetNodeId: UUID?
}

enum NodeData: Codable {
    case dialogue(DialogueData)
    case dialogueFragment(DialogueData)
    case branch(BranchData)
    case condition(ConditionData)
    case instruction(InstructionData)
    case hub(HubData)
    case jump(JumpData)
    case skillCheck(SkillCheckData)
    case thought(ThoughtData)
    
    // Quick access to text content for any node type
    var displayText: String? {
        switch self {
        case .dialogue(let d), .dialogueFragment(let d):
            return d.text
        case .thought(let t):
            return t.text
        case .skillCheck(let s):
            return "[\(s.skillName) \(s.difficulty)]"
        case .hub(let h):
            return h.displayName
        default:
            return nil
        }
    }
}

class DialogueNode: Identifiable, ObservableObject, Codable {
    let id: UUID
    var technicalName: String
    var nodeType: NodeType
    @Published var position: CGPoint
    @Published var size: CGSize
    @Published var inputPorts: [Port]
    @Published var outputPorts: [Port]
    @Published var data: NodeData
    @Published var color: Color?
    var parentId: UUID?
    
    // Animation state (not persisted)
    @Published var isSelected: Bool = false
    @Published var isHovered: Bool = false
    @Published var glowIntensity: Float = 0.0
    
    enum CodingKeys: String, CodingKey {
        case id, technicalName, nodeType, position, size, inputPorts, outputPorts, data, colorHex, parentId
    }
    
    init(type: NodeType, position: CGPoint, name: String? = nil) {
        let nodeId = UUID()
        self.id = nodeId
        self.technicalName = name ?? "\(type.rawValue)_\(UUID().uuidString.prefix(8))"
        self.nodeType = type
        self.position = position
        self.size = type.defaultSize
        self.color = nil
        
        // Create default data first (required before using self)
        switch type {
        case .dialogue:
            self.data = .dialogue(DialogueData())
        case .dialogueFragment:
            self.data = .dialogueFragment(DialogueData())
        case .branch:
            self.data = .branch(BranchData())
        case .condition:
            self.data = .condition(ConditionData())
        case .instruction:
            self.data = .instruction(InstructionData())
        case .hub:
            self.data = .hub(HubData())
        case .jump:
            self.data = .jump(JumpData())
        case .whiteCheck:
            self.data = .skillCheck(SkillCheckData(skillName: "", difficulty: 10))
        case .redCheck:
            var checkData = SkillCheckData(skillName: "", difficulty: 12)
            checkData.canRetry = false
            self.data = .skillCheck(checkData)
        case .passiveCheck:
            var checkData = SkillCheckData(skillName: "", difficulty: 8)
            checkData.isPassive = true
            self.data = .skillCheck(checkData)
        case .thought:
            self.data = .thought(ThoughtData())
        }
        
        // Create default ports (using nodeId, not self.id)
        var inputs: [Port] = []
        var outputs: [Port] = []
        
        for i in 0..<type.minInputPorts {
            inputs.append(Port(nodeId: nodeId, type: .input, index: i))
        }
        for i in 0..<type.minOutputPorts {
            let label: String?
            if type == .condition {
                label = i == 0 ? "True" : "False"
            } else if type == .branch && type.minOutputPorts > 1 {
                label = "Out \(i + 1)"
            } else if type.isCheckType && i < 2 {
                label = i == 0 ? "Success" : "Failure"
            } else {
                label = nil
            }
            outputs.append(Port(nodeId: nodeId, type: .output, index: i, label: label))
        }
        
        self.inputPorts = inputs
        self.outputPorts = outputs
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        technicalName = try container.decode(String.self, forKey: .technicalName)
        nodeType = try container.decode(NodeType.self, forKey: .nodeType)
        let posArray = try container.decode([CGFloat].self, forKey: .position)
        position = CGPoint(x: posArray[0], y: posArray[1])
        let sizeArray = try container.decode([CGFloat].self, forKey: .size)
        size = CGSize(width: sizeArray[0], height: sizeArray[1])
        inputPorts = try container.decode([Port].self, forKey: .inputPorts)
        outputPorts = try container.decode([Port].self, forKey: .outputPorts)
        data = try container.decode(NodeData.self, forKey: .data)
        if let hex = try container.decodeIfPresent(String.self, forKey: .colorHex) {
            color = Color(hex: hex)
        }
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(technicalName, forKey: .technicalName)
        try container.encode(nodeType, forKey: .nodeType)
        try container.encode([position.x, position.y], forKey: .position)
        try container.encode([size.width, size.height], forKey: .size)
        try container.encode(inputPorts, forKey: .inputPorts)
        try container.encode(outputPorts, forKey: .outputPorts)
        try container.encode(data, forKey: .data)
        // Note: Color encoding simplified - would need proper hex conversion
        try container.encodeIfPresent(parentId, forKey: .parentId)
    }
    
    func addOutputPort(label: String? = nil) {
        let port = Port(nodeId: id, type: .output, index: outputPorts.count, label: label)
        outputPorts.append(port)
    }
    
    func getPortPosition(type: Port.PortType, index: Int) -> CGPoint {
        let ports = type == .input ? inputPorts : outputPorts
        guard index < ports.count else { return position }
        
        let portCount = ports.count
        let spacing = size.height / CGFloat(portCount + 1)
        let portY = position.y + spacing * CGFloat(index + 1)
        let portX = type == .input ? position.x : position.x + size.width
        
        return CGPoint(x: portX, y: portY)
    }
}
