# Implementation Plan: Color Filters, Timing Cues, and Power-Up System

## Overview
This plan outlines the implementation of three major features:
1. **Color Filters (Saturation)** - Visual feedback for time states (Grey Mode, Power-Up Mode)
2. **Timing Cues** - 3-flash countdown system with sound
3. **Flexible Power-Up System** - Resource-based pickup system for coins, power-ups, and future items

---

## Phase 1: Color Filters (Saturation) 🌈

### Step 1.1: Add WorldEnvironment Node
- **Location**: `node_2d.tscn` (main scene)
- **Action**: 
  - Add `WorldEnvironment` node as child of root `MainScene (Node2D)`
  - In Inspector, create new `Environment` resource
  - Enable `Adjustments` section
  - Set initial `Saturation` to `1.0` (normal)

### Step 1.2: Create VisualEffectsManager
- **File**: `VisualEffectsManager.gd`
- **Type**: Autoload singleton (add to `project.godot` autoload section)
- **Responsibilities**:
  - Reference to `WorldEnvironment` node
  - Listen to `TimeStateManager.time_state_changed` signal
  - Update saturation based on state:
    - `SLOW`: `0.0` (greyscale)
    - `FAST`: `1.0` (normal)
    - `POWERUP`: `1.5` (high saturation)
- **Methods**:
  - `set_saturation(value: float)` - Direct saturation control
  - `update_saturation_for_state(state: TimeState)` - Auto-update based on state

### Step 1.3: Integration
- Connect `TimeStateManager.time_state_changed` signal to `VisualEffectsManager`
- Test saturation changes when switching time modes (J/K keys)

---

## Phase 2: Timing Cues (3-Flash Countdown) ⚡

### Step 2.1: Create UI Scene Structure
- **File**: `UI.tscn` (new scene)
- **Structure**:
  ```
  UI (CanvasLayer)
    ├── FlashRect (ColorRect)
    │   └── Layout: Full Rect
    │   └── Color: #ffffffff (white)
    │   └── Modulate Alpha: 0 (invisible)
    └── FlashSound (AudioStreamPlayer)
        └── Stream: [beep sound effect]
  ```

### Step 2.2: Create UIManager Script
- **File**: `UIManager.gd`
- **Attach to**: `UI` (CanvasLayer) node
- **Properties**:
  - `@onready var flash_rect: ColorRect`
  - `@onready var flash_sound: AudioStreamPlayer`
  - `@export var flash_opacity: float = 0.2`
  - `@export var flash_duration: float = 0.1`
  - `@export var time_between_flashes: float = 0.5`
- **Methods**:
  - `play_timing_cues()` - Plays 3 flashes with sound
  - `play_powerup_flicker()` - Flickers saturation during power-up transition

### Step 2.3: Add UI to Main Scene
- **Location**: `node_2d.tscn`
- **Action**: Instance `UI.tscn` as child of root `MainScene (Node2D)`
- **Access Path**: `get_node("/root/MainScene/UI")` or use groups

### Step 2.4: Power-Up Flicker Implementation
- In `UIManager.play_powerup_flicker()`:
  - Use `Tween` to animate `VisualEffectsManager.set_saturation()` between values
  - Flicker pattern: `1.0 → 0.0 → 1.5 → 0.0 → 1.5` (or similar)
  - Duration: ~1-2 seconds total
  - Return signal/awaitable for player script integration

---

## Phase 3: Flexible Power-Up System 🍄

### Step 3.1: Create Base PickupData Resource
- **File**: `PickupData.gd`
- **Type**: `extends Resource` with `class_name PickupData`
- **Properties**:
  - `@export var particle_effect: PackedScene` (optional)
  - `@export var texture: Texture2D` (for sprite)
- **Methods**:
  - `func apply_effect(player_node: Node) -> void` - Override in subclasses

### Step 3.2: Create CoinData Resource
- **File**: `CoinData.gd`
- **Type**: `extends PickupData` with `class_name CoinData`
- **Methods**:
  - Override `apply_effect()` to call `player_node.add_coin(1)` or global coin manager

### Step 3.3: Create DrugPowerupData Resource
- **File**: `DrugPowerupData.gd`
- **Type**: `extends PickupData` with `class_name DrugPowerupData`
- **Methods**:
  - Override `apply_effect()` to call `player_node.start_powerup_transition()`

### Step 3.4: Create Pickup Scene
- **File**: `Pickup.tscn`
- **Structure**:
  ```
  Pickup (Area2D)
    ├── Sprite2D
    └── CollisionShape2D
  ```
- **Script**: `Pickup.gd`
- **Properties**:
  - `@export var data: PickupData` (set in Inspector)
- **Signals**:
  - Connect `body_entered` to `_on_body_entered()`
- **Methods**:
  - `_ready()` - Set sprite texture from `data.texture`
  - `_on_body_entered(body)` - Check if player, apply effect, spawn particles, queue_free()

### Step 3.5: Create Resource Files (.tres)
- **Files**: 
  - `coin_data.tres` (from `CoinData`)
  - `drug_powerup_data.tres` (from `DrugPowerupData`)
- **Setup**: Assign textures and particle effects in Inspector

### Step 3.6: Player Integration
- **File**: `player.gd`
- **Add**:
  - `var coin_count: int = 0` (or use global manager)
  - `func add_coin(amount: int)` - Increment coin count
  - `func start_powerup_transition()` - Freeze player, call UI flicker, transition to POWERUP state

### Step 3.7: Global Coin Manager (Optional)
- **File**: `CoinManager.gd` (autoload singleton)
- **Purpose**: Centralized coin tracking
- **Methods**:
  - `add_coins(amount: int)`
  - `get_coin_count() -> int`
  - Signal: `coins_changed(new_total: int)`

---

## Phase 4: Integration & Testing 🔗

### Step 4.1: Connect TimeStateManager to VisualEffectsManager
- In `VisualEffectsManager._ready()`:
  - Get `TimeStateManager` reference
  - Connect `time_state_changed` signal
  - Set initial saturation based on current state

### Step 4.2: Connect Power-Up Flow
- When `DrugPowerupData.apply_effect()` is called:
  1. Player calls `start_powerup_transition()`
  2. Player freezes (`set_physics_process(false)`)
  3. Player calls `UIManager.play_powerup_flicker()` and awaits completion
  4. Player unfreezes (`set_physics_process(true)`)
  5. `TimeStateManager.set_state(TimeState.POWERUP)`
  6. `VisualEffectsManager` updates saturation to `1.5`

### Step 4.3: Testing Checklist
- [ ] Saturation changes when switching time modes (J/K keys)
- [ ] Timing cues play 3 flashes with sound
- [ ] Power-up flicker animates correctly
- [ ] Coins can be collected and tracked
- [ ] Power-ups trigger transition sequence
- [ ] All pickups can be instantiated in scene

---

## File Structure Summary

```
Antigame-Platformer/
├── VisualEffectsManager.gd          (NEW - Autoload)
├── UIManager.gd                     (NEW)
├── UI.tscn                          (NEW)
├── PickupData.gd                    (NEW - Resource base)
├── CoinData.gd                      (NEW - Resource)
├── DrugPowerupData.gd               (NEW - Resource)
├── Pickup.gd                        (NEW)
├── Pickup.tscn                      (NEW)
├── coin_data.tres                   (NEW - Resource file)
├── drug_powerup_data.tres           (NEW - Resource file)
├── CoinManager.gd                   (NEW - Optional autoload)
├── player.gd                        (MODIFY - Add power-up methods)
├── node_2d.tscn                     (MODIFY - Add WorldEnvironment, UI)
└── project.godot                    (MODIFY - Add autoloads)
```

---

## Implementation Order Recommendation

1. **Phase 1** (Color Filters) - Foundation, easiest to test
2. **Phase 2** (Timing Cues) - Visual/audio feedback system
3. **Phase 3** (Power-Up System) - Most complex, builds on previous phases
4. **Phase 4** (Integration) - Connect everything together

---

## Notes

- All new scripts should follow existing code style
- Use `@onready` for node references
- Use signals for decoupled communication
- Test each phase before moving to the next
- Keep resource files organized in a `resources/` folder (optional)

