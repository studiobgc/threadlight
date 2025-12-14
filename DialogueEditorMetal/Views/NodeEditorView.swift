import SwiftUI
import MetalKit

struct NodeEditorView: View {
    @EnvironmentObject var graphModel: GraphModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Metal canvas for GPU-accelerated rendering
                MetalCanvas()
                    .environmentObject(graphModel)
                
                // Minimap overlay (bottom-right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MinimapView()
                            .frame(width: 180, height: 120)
                            .padding(12)
                    }
                }
                
                // Zoom controls (bottom-left)
                VStack {
                    Spacer()
                    HStack {
                        ZoomControls()
                            .padding(12)
                        Spacer()
                    }
                }
            }
        }
        .background(Color(hex: "101012"))
    }
}

struct MinimapView: View {
    @EnvironmentObject var graphModel: GraphModel
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            // Nodes representation
            GeometryReader { geometry in
                let bounds = calculateBounds()
                let scale = calculateScale(bounds: bounds, size: geometry.size)
                
                ForEach(graphModel.nodes) { node in
                    let pos = transformPosition(node.position, bounds: bounds, scale: scale, size: geometry.size)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(node.nodeType.color.opacity(0.8))
                        .frame(width: max(4, node.size.width * scale), height: max(3, node.size.height * scale))
                        .position(pos)
                }
                
                // Viewport indicator
                let viewportRect = calculateViewportRect(bounds: bounds, scale: scale, size: geometry.size)
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .frame(width: viewportRect.width, height: viewportRect.height)
                    .position(x: viewportRect.midX, y: viewportRect.midY)
            }
            .padding(8)
        }
    }
    
    private func calculateBounds() -> CGRect {
        guard !graphModel.nodes.isEmpty else {
            return CGRect(x: -500, y: -500, width: 1000, height: 1000)
        }
        
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        for node in graphModel.nodes {
            minX = min(minX, node.position.x)
            minY = min(minY, node.position.y)
            maxX = max(maxX, node.position.x + node.size.width)
            maxY = max(maxY, node.position.y + node.size.height)
        }
        
        // Add padding
        let padding: CGFloat = 100
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + padding * 2,
            height: maxY - minY + padding * 2
        )
    }
    
    private func calculateScale(bounds: CGRect, size: CGSize) -> CGFloat {
        let scaleX = size.width / bounds.width
        let scaleY = size.height / bounds.height
        return min(scaleX, scaleY)
    }
    
    private func transformPosition(_ pos: CGPoint, bounds: CGRect, scale: CGFloat, size: CGSize) -> CGPoint {
        CGPoint(
            x: (pos.x - bounds.minX) * scale,
            y: (pos.y - bounds.minY) * scale
        )
    }
    
    private func calculateViewportRect(bounds: CGRect, scale: CGFloat, size: CGSize) -> CGRect {
        let viewportWidth = 800 / graphModel.viewportZoom
        let viewportHeight = 600 / graphModel.viewportZoom
        let viewportX = -graphModel.viewportOffset.x / graphModel.viewportZoom
        let viewportY = -graphModel.viewportOffset.y / graphModel.viewportZoom
        
        return CGRect(
            x: (viewportX - bounds.minX) * scale,
            y: (viewportY - bounds.minY) * scale,
            width: viewportWidth * scale,
            height: viewportHeight * scale
        )
    }
}

struct ZoomControls: View {
    @EnvironmentObject var graphModel: GraphModel
    
    var body: some View {
        VStack(spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    graphModel.viewportZoom = min(5.0, graphModel.viewportZoom * 1.25)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(ZoomButtonStyle())
            
            Text("\(Int(graphModel.viewportZoom * 100))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 44)
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    graphModel.viewportZoom = max(0.1, graphModel.viewportZoom / 1.25)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(ZoomButtonStyle())
            
            Divider()
                .frame(width: 24)
                .padding(.vertical, 4)
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    graphModel.viewportZoom = 1.0
                    graphModel.viewportOffset = .zero
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(ZoomButtonStyle())
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ZoomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.5 : 0.8))
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.15 : 0.1))
            )
    }
}

#if DEBUG
struct NodeEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NodeEditorView()
            .environmentObject(GraphModel())
            .frame(width: 800, height: 600)
    }
}
#endif
