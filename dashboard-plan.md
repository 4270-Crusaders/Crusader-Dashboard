# Team Dashboard — Project Plan

Fork of [Gold872/elastic-dashboard](https://github.com/Gold872/elastic-dashboard) (MIT License)  
Stack: Flutter/Dart + audioplayers

---

## What We Get for Free (Elastic Core)

Do not rebuild these — they already work:

| Feature | Elastic Widget |
|---|---|
| Match countdown | `Match Time` (blue→green→yellow→red) |
| Hub active/inactive | `Boolean Box` (custom colors) |
| Field map (Rebuilt) | `Field` (Rebuilt is already default) |
| Auto chooser | `ComboBox Chooser` / `Split Button Chooser` |
| Auto winner chooser | same — maps to `LoggedDashboardChooser` |
| Alliance / FMS info | `FMSInfo` |
| Swerve visualization | `SwerveDrive` |
| Signal plotting | `Graph` |
| Camera feeds | `Camera Stream` |

---

## What We Build

### 1. Sound Engine
**Type:** Background service (not a widget)  
**Package:** `audioplayers`  
**File:** `lib/services/sound_engine.dart`

Singleton. Hooks into Elastic's existing NT subscription layer — no second NT4 connection.  
Sound mappings live in a config file (`assets/sounds/config.yaml`) so sounds can be swapped without recompiling.

**Events:**

| Event | NT Key | Trigger |
|---|---|---|
| Hub deactivates | `RobotState/HubActive` | false edge |
| Hub activates | `RobotState/HubActive` | true edge |
| Shift warning | `RobotState/MatchTimeSeconds` | hits 108 / 83 / 58 / 33 (3s before each shift) |
| Endgame | `RobotState/MatchTimeSeconds` | hits 30 |
| Jammed | `RobotState/Jammed` | true edge |
| Shooter ready | `RobotState/ShooterReady` | true edge |

**Config format:**
```yaml
sounds:
  hub_deactivate: hub_off.wav
  hub_activate: hub_on.wav
  shift_warning: beep.wav
  endgame: alarm.wav
  jammed: buzz.wav
  shooter_ready: chime.wav
volume: 1.0
enabled: true
```

**Settings:** mute toggle + volume slider in Elastic's existing settings screen.

---

### 2. Shift Timeline Widget
**Type:** New canvas widget  
**NT topics:**
- `RobotState/MatchTimeSeconds` (double)
- `RobotState/HubActive` (boolean)
- `RobotState/GamePhase` (String)

**Behavior:**  
Horizontal strip showing all 5 match segments. Current segment is highlighted. Hub-active segments green, hub-inactive segments red. Shows seconds remaining in current segment.

```
[TRANS][  SHIFT 1  ][  SHIFT 2  ][  SHIFT 3  ][  SHIFT 4  ][ ENDGAME ]
                      ^^^^ current (highlighted)
```

**Segment timing (match time remaining):**
| Segment | Range |
|---|---|
| Transition | > 130s |
| Shift 1 | 105–130s |
| Shift 2 | 80–105s |
| Shift 3 | 55–80s |
| Shift 4 | 30–55s |
| Endgame | 0–30s |

---

### 3. Hub Status Widget
**Type:** New canvas widget (extended Boolean Box)  
**NT topics:**
- `RobotState/HubActive` (boolean)
- `RobotState/MatchTimeSeconds` (double)

**Behavior:**  
Large colored card. Green = hub active, red = hub inactive.  
Pulses / flashes for 3s before each shift change to warn driver.  
Shows label: "HUB ACTIVE" or "HUB INACTIVE" + time until next flip.

**Properties (configurable in widget settings):**
- `active_color` (default: green)
- `inactive_color` (default: red)
- `warning_color` (default: orange — shown during 3s pulse)

---

### 4. Game Phase Badge
**Type:** Status bar addition (one edit to Elastic core UI)  
**File to modify:** Elastic's top status bar widget  
**NT topic:** `RobotState/GamePhase` (String)

Small pill/badge always visible in the top bar next to connection status.  
Values: `DISABLED` / `AUTO` / `TRANSITION` / `SHIFT 1` / `SHIFT 2` / `SHIFT 3` / `SHIFT 4` / `ENDGAME`  
Color-coded to match shift timeline widget.

---

## NT Topics Reference

All under `/AdvantageKit/` prefix:

| Key | Type | Owner |
|---|---|---|
| `RobotState/GamePhase` | String | RobotContainer.readInputs() |
| `RobotState/HubActive` | boolean | RobotContainer.readInputs() |
| `RobotState/MatchTimeSeconds` | double | RobotContainer.readInputs() |
| `RobotState/Jammed` | boolean | Indexer.update() |
| `RobotState/ShooterReady` | boolean | RobotState.log() |

---

## Build Order

1. **Fork** `Gold872/elastic-dashboard`, add upstream remote
2. **Run** Elastic locally, verify build
3. **Study** one existing widget (e.g. `BooleanBox`) to understand widget registration pattern
4. **Phase 1:** Sound Engine — highest match value, fully isolated, no widget canvas changes
5. **Phase 2:** Shift Timeline Widget
6. **Phase 3:** Hub Status Widget
7. **Phase 4:** Game Phase Badge — touches Elastic core, hardest to keep in sync with upstream

---

## Keeping in Sync with Upstream

- Keep `main` branch clean (only Elastic code)
- All additions live on `feat/team-extras` branch
- Periodically merge upstream `main` → `feat/team-extras`
- New widgets in new files only — minimizes merge conflicts
- Phase 4 (status bar edit) is the only core file touch — isolate it

---

## Dependencies to Add

```yaml
# pubspec.yaml additions
dependencies:
  audioplayers: ^6.0.0
  yaml: ^3.1.0        # for sounds config parsing (likely already in Elastic)
```
