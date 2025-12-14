# Threadlight Feature Roadmap

## Vision
Threadlight is the evolution of articy:draft for macOS — a native, Metal-powered dialogue editor that makes writing branching narratives addictive. Inspired by how ZA/UM used articy:draft to write Disco Elysium's 1.2 million words.

---

## Core Insights from Disco Elysium Development

From the documentary transcript:
- "articy:draft had such a huge part influencing the way the entire game is written"
- "It's not the same when you're writing in articy because you are creating those dialogue boxes with short sentences and it is so much fun"
- "The problem became that we were writing too much"
- Training a new writer took 4-6 months: lore lectures, tool methodology, writing independently

### Key Workflow Elements
1. **Node-based visual programming** with dialogue fragments linked up
2. **Global variables and Booleans** for reactivity
3. **Hub-based dialogue structure** (greeting → hub → fragments)
4. **Skill checks**: White (retry), Red (one-shot), Passive (automatic)
5. **Conditions and instructions** for game logic
6. **Simulation mode** to test flow before export

---

## Feature Parity with articy:draft

### ✅ Implemented
- [x] Flow canvas with infinite pan/zoom
- [x] Node types: Dialogue, Fragment, Branch, Condition, Instruction, Hub, Jump
- [x] Skill checks (White, Red, Passive) - Disco Elysium style
- [x] Bezier curve connections
- [x] Undo/Redo system
- [x] Properties panel
- [x] Character system
- [x] Figma-style cursor-centered zoom
- [x] Quick node creation (drag from port, Ctrl+Shift+Click)

### 🚧 In Progress
- [ ] Variables UI (model exists, needs panel)
- [ ] Context menu (stub exists)

### ❌ Missing (Priority Order)

#### P0 - Essential
1. **File Save/Load** - JSON serialization
2. **Simulation Mode** - Play through dialogue, test conditions
3. **Variables Panel** - Create/edit global variables
4. **Quick Create Menu** - articy-style multi-fragment creation

#### P1 - Core Workflow
5. **Command Palette** (⌘K) - Quick actions, search nodes
6. **Nested Flow** - Dialogues contain fragments (double-click to enter)
7. **Document View** - Screenplay-style text view
8. **Convert Document to Flow** - Paste screenplay, get nodes

#### P2 - Polish
9. **Spellchecker**
10. **Conflict Search** - Find broken references
11. **Property Inspector** - Live variable monitoring
12. **Attachments** - Link assets to nodes
13. **Templates** - Custom node types

#### P3 - Export/Integration
14. **Export to JSON** (Unreal/Unity compatible)
15. **Export to articy XML format**
16. **Unreal Plugin** - Direct import
17. **Unity Importer**

---

## UX Improvements (Figma-Inspired)

### ✅ Implemented
- [x] Cursor-centered zoom (zoom towards mouse, not center)
- [x] Smooth panning with natural scroll
- [x] Trackpad pinch-to-zoom with cursor centering
- [x] No layout shift on hover
- [x] Onboarding hints in empty state

### 🚧 Needed
- [ ] Zoom levels snapping (10%, 25%, 50%, 100%, 200%)
- [ ] Fit to selection (⌘1)
- [ ] Zoom to fit all (⌘0)
- [ ] Mini-map click-to-navigate
- [ ] Zoom indicator with click-to-reset
- [ ] Smooth animated transitions
- [ ] Grid snapping (optional)

---

## Keyboard Shortcuts (Target)

| Shortcut | Action |
|----------|--------|
| `D` | Quick dialogue node |
| `B` | Branch node |
| `C` | Condition node |
| `H` | Hub node |
| `J` | Jump node |
| `⌘K` | Command palette |
| `⌘S` | Save |
| `⌘Z` | Undo |
| `⌘⇧Z` | Redo |
| `⌘D` | Duplicate |
| `⌫` | Delete |
| `⌘A` | Select all |
| `⌘0` | Zoom to fit |
| `⌘1` | Zoom to selection |
| `⌘+` | Zoom in |
| `⌘-` | Zoom out |
| `Space+drag` | Pan |
| `⌃⇧Click` | Quick create at cursor |
| `Enter` | Edit selected node |
| `Tab` | Next node in flow |
| `⇧Tab` | Previous node |

---

## Technical Architecture

### Current Stack
- **SwiftUI** - UI framework
- **Metal** - GPU-accelerated rendering (120fps ProMotion)
- **Combine** - Reactive state management

### Rendering Pipeline
1. Triple-buffered command queue
2. MSAA 4x anti-aliasing
3. Custom bezier curve renderer
4. Bloom/glow effects
5. Particle system for polish

### Performance Targets
- 120fps on ProMotion displays
- <16ms frame time
- 10,000+ nodes without lag
- Instant response to input

---

## Development Phases

### Phase 1: Core Workflow (Current)
- File I/O
- Variables panel
- Simulation mode
- Command palette

### Phase 2: Writing Experience
- Nested dialogues
- Document view
- Inline editing improvements
- Speaker quick-switch

### Phase 3: Collaboration
- Project management
- Git-friendly format
- Conflict resolution
- Team features

### Phase 4: Integration
- Unreal plugin
- Unity importer
- Custom export formats
- API for extensions

---

## Design Philosophy

1. **Writing should be addictive** - Like articy made Disco Elysium writers "write too much"
2. **Keyboard-first** - Every action accessible without mouse
3. **Visual clarity** - Node types instantly recognizable
4. **Performance** - Native Metal, never wait for the tool
5. **No friction** - Quick create, auto-connect, smart defaults
