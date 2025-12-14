import Foundation
import SwiftUI

enum ConnectionType: String, Codable {
    case flow
    case data
}

struct Connection: Identifiable, Codable {
    let id: UUID
    var fromNodeId: UUID
    var fromPortIndex: Int
    var toNodeId: UUID
    var toPortIndex: Int
    var connectionType: ConnectionType
    var label: String?
    
    // Animation state (not persisted)
    var flowProgress: Float = 0.0
    var isSelected: Bool = false
    var isHovered: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, fromNodeId, fromPortIndex, toNodeId, toPortIndex, connectionType, label
    }
    
    init(from fromNodeId: UUID, fromPort: Int, to toNodeId: UUID, toPort: Int, type: ConnectionType = .flow) {
        self.id = UUID()
        self.fromNodeId = fromNodeId
        self.fromPortIndex = fromPort
        self.toNodeId = toNodeId
        self.toPortIndex = toPort
        self.connectionType = type
    }
}

struct ConnectionPreview {
    var fromPosition: CGPoint
    var toPosition: CGPoint
    var isValid: Bool
    var progress: Float // For animated dash effect
}
