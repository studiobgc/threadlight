import SwiftUI

@main
struct DialogueEditorMetalApp: App {
    @StateObject private var graphModel = GraphModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(graphModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Graph") {
                    graphModel.newGraph()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandMenu("Node") {
                Button("Add Dialogue Node") {
                    graphModel.addNode(type: .dialogue, at: CGPoint(x: 200, y: 200))
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                
                Button("Add Branch Node") {
                    graphModel.addNode(type: .branch, at: CGPoint(x: 200, y: 200))
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Delete Selected") {
                    graphModel.deleteSelectedNodes()
                }
                .keyboardShortcut(.delete, modifiers: [])
            }
        }
    }
}
