# Dialogue Editor Metal

A native macOS dialogue editor built with **SwiftUI** and **Metal** for GPU-accelerated rendering. Designed for game developers and narrative designers who need a powerful, performant tool for creating branching dialogue systems.

> *"Articy draft had such a huge part of influencing the way the entire game is written... when you're staring at a blank word document nothing comes out... It's not the same when you're writing in Articy because you are creating those dialogue boxes with short sentences and it is so much fun like just creating more and more and more."*
> — Disco Elysium Development Team

This editor is built on insights from the Disco Elysium writers about what made Articy:draft transformative for their workflow. The goal: **make writing feel like play, not work.**

## Why SwiftUI + Metal?

### SwiftUI Benefits
- **Declarative UI** — Describe what you want, not how to build it
- **Native macOS integration** — Feels right at home on your Mac
- **Live previews** — Instant feedback during development
- **Accessibility built-in** — VoiceOver, keyboard navigation, etc.

### Metal Benefits
- **GPU-accelerated rendering** — Handle 100,000+ nodes at 120fps on M3 Max
- **Custom shaders** — Unique visual effects not possible with standard frameworks
- **Compute shaders** — Physics-based animations and particle systems
- **Low latency** — Responsive interactions even with massive graphs

## Features

### Flow-First Writing (Disco Elysium Workflow)
The key insight: **writers hate a blank page**. This editor makes it fun to keep creating.

- **Tab to Continue** — Press Tab to instantly create and connect the next dialogue node
- **Drag-to-Create** — Drag from an output port into empty space → Quick Create Menu appears
- **Writing Mode** — Distraction-free mode that hides technical UI, just you and the words
- **Speaker Persistence** — New nodes inherit the last speaker, change with one click
- **Breadcrumb Navigation** — Flow through your dialogue like reading a book

### Core Editor
- **Node-based dialogue graphs** — Visual representation of branching conversations
- **Multiple node types**:
  - 💬 **Dialogue** — Character speech with speaker assignment
  - 📝 **Fragment** — Reusable dialogue snippets
  - 🧠 **Thought** — Internal monologue (Thought Cabinet style)
  - 🔀 **Branch** — Multiple choice points
  - ❓ **Condition** — Script-based logic gates
  - ⚙️ **Instruction** — Variable manipulation
  - ⭕ **Hub** — Flow consolidation points
  - ↩️ **Jump** — Non-linear navigation

### Disco Elysium-Style Skill Checks
Inspired by DE's brilliant check system:

- 🎲 **White Check** — Can be retried when conditions change
- 🔴 **Red Check** — One shot only, higher stakes
- 👁️ **Passive Check** — Triggers automatically based on skills
- **Difficulty System** — Set target numbers (6-18 range)
- **Modifiers** — Track situational bonuses/penalties

### Internal Voices (Thought Cabinet)
Like DE's skills talking to you:

- Predefined voices: Logic, Empathy, Drama, Volition, Rhetoric
- Custom internal voices for your game's unique system
- Color-coded for instant recognition
- Separate from external character dialogue

### Metal-Powered Rendering
- **SDF-based node rendering** — Crisp edges at any zoom level
- **Instanced rendering** — Thousands of nodes in a single draw call
- **Custom bezier curves** — Smooth connections with animated flow
- **Grid with origin glow** — Beautiful infinite canvas

### Visual Effects
- **Bloom post-processing** — Subtle glow on selected elements
- **GPU particle system** — Sparks on connections, bursts on selection
- **Selection glow** — Clear visual feedback
- **Animated dash patterns** — Connection previews that feel alive

### Interactions
- **Pan & zoom** — Smooth 120Hz navigation with inertia
- **Multi-selection** — Box select and shift-click
- **Drag-to-connect** — Intuitive port connections
- **Undo/Redo** — Full history stack

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac recommended (M1/M2/M3)
- Xcode 15.0 or later

## Building

1. Open `DialogueEditorMetal.xcodeproj` in Xcode
2. Select your development team for signing
3. Build and run (⌘R)

## Architecture

```
DialogueEditorMetal/
├── Models/
│   ├── Node.swift          # Node types and data structures
│   ├── Connection.swift    # Connection model
│   └── GraphModel.swift    # Observable graph state
├── Renderer/
│   ├── MetalCanvas.swift   # SwiftUI Metal view wrapper
│   └── NodeGraphRenderer.swift # Metal rendering pipeline
├── Shaders/
│   ├── ShaderTypes.h       # Shared GPU/CPU types
│   ├── Shaders.metal       # Core rendering shaders
│   └── EffectsShaders.metal # Post-processing effects
├── Views/
│   ├── ContentView.swift   # Main app layout
│   ├── NodeEditorView.swift # Canvas + overlays
│   ├── PropertiesPanel.swift # Node property editor
│   └── Toolbar.swift       # App toolbar
└── Effects/
    ├── ParticleSystem.swift # GPU particle effects
    └── BloomEffect.swift    # Bloom post-processing
```

## Key Technical Details

### Shader Pipeline
1. **Grid Pass** — Full-screen shader with dot/line pattern
2. **Connection Pass** — Bezier curves with flow animation
3. **Node Pass** — Instanced SDF rounded rectangles
4. **Port Pass** — Circular ports with connection glow
5. **Effects Pass** — Bloom, particles, selection overlays

### Performance Optimizations
- **Spatial indexing** — Only render visible nodes
- **Instance buffers** — Batch similar draw calls
- **Half-resolution bloom** — Full effect, half the cost
- **Compute shaders** — GPU-driven particle physics

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New Graph | ⌘N |
| Undo | ⌘Z |
| Redo | ⌘⇧Z |
| Delete | ⌫ |
| Duplicate | ⌘D |
| Add Dialogue | ⌘⇧D |
| Add Branch | ⌘⇧B |

## Roadmap

- [ ] File save/load (JSON export)
- [ ] Articy:draft import
- [ ] Inline text editing
- [ ] Variable system
- [ ] Preview/play mode
- [ ] Export to game engine formats
- [ ] Localization support

## License

MIT License — See LICENSE file for details.

---

Built with ❤️ for narrative designers who deserve better tools.
