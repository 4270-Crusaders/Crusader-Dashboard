# Sound Triggers

Crusader Dashboard can play a sound file when a NetworkTables value changes. Use it for things like "coral acquired", "climb ready", or "10 seconds left".

There are two ways to set up a sound. Both use the same conditions and the same sound files.

| | Sound Trigger widget | Background trigger |
|---|---|---|
| Where | On the dashboard canvas, like any other widget | Settings → **Sounds** tab |
| Saved in | The layout `.json` file | Dashboard settings (follows the app, not the layout) |
| Shows on screen | Yes — icon lights up while playing | No |
| Use when | You want a visible indicator, or the sound belongs to one layout | The sound should fire on every layout / every tab |

## Sound files

- Supported formats: **WAV, MP3, AAC, M4A**. OGG is not supported on Windows.
- Files are referenced by absolute path, not copied. Keep them somewhere permanent (for example `C:\CrusaderSounds\` or `~/CrusaderSounds/`). If the file moves, the trigger goes silent.
- The same path must exist on every driver station laptop that opens the layout.
- Keep clips short (under ~2 s) unless you use **Loop**.

## Conditions

| Condition | Topic type | Fires when |
|---|---|---|
| Bool: False → True | boolean | Value goes from `false` to `true` |
| Bool: True → False | boolean | Value goes from `true` to `false` |
| Number: Crosses Down | number | Value was above the threshold and is now at or below it |
| Number: Crosses Up | number | Value was below the threshold and is now at or above it |

A trigger only fires on the *change*. It will not fire on the first value received after connecting, and it will not repeat while the value stays on the same side.

**Loop until condition ends** (boolean conditions only): the sound repeats until the value flips back. For "Crosses" conditions, loop keeps playing until the trigger is disabled or the widget is removed.

## Option 1: Sound Trigger widget

1. Connect to the robot so topics show up in the **Add Widget** sidebar (or use the tree from a `.json` layout).
2. Drag a **boolean** or **number** topic onto the canvas.
3. Right-click the new widget → **Show As** → **Sound Trigger**.
4. Right-click → **Edit Properties**:
   - **Trigger Condition** — pick from the table above.
   - **Threshold** — only shown for number conditions.
   - **Browse** — pick the sound file.
   - **Loop Until Condition Ends** — optional.
5. Save the layout (**File → Save**).

The widget shows the topic name and condition. The icon turns to 🔊 and the tile highlights while the sound plays; a **LOOPING** badge appears when a looped sound is active.

## Option 2: Background trigger (Settings)

1. Open **Settings** (menu bar) → **Sounds** tab.
2. Make sure **Sounds Enabled** is on and set the **volume** slider.
3. Press **+** next to *Background Sound Triggers*.
4. Fill in the dialog:
   - **Label** — optional, shown in the list.
   - **NT Topic** — type the full topic path (for example `/SmartDashboard/HasCoral`) or press **Browse** to pick from the live topic tree.
   - **Condition**, **Threshold**, **Sound file**, **Loop** — same as above.
5. **Save**.

Background triggers start when the dashboard launches and run regardless of which tab or layout is open. Edit or delete them from the same list.

## Global controls

Settings → **Sounds**:

- **Sounds Enabled** — master mute. Turning it off stops any looping sound immediately. Turning it back on does not replay anything until the next real change.
- **Volume** — 0–100 %, applies to both widgets and background triggers on their next play.

## Robot code example

Any NT publisher works. With WPILib:

```java
// Java
SmartDashboard.putBoolean("HasCoral", intake.hasCoral());   // /SmartDashboard/HasCoral
SmartDashboard.putNumber("MatchTime", DriverStation.getMatchTime());
```

Then, for example:

- `/SmartDashboard/HasCoral`, **Bool: False → True**, `ding.wav`
- `/SmartDashboard/MatchTime`, **Number: Crosses Down**, threshold `30`, `endgame.wav`

## Troubleshooting

| Symptom | Check |
|---|---|
| Nothing plays | Settings → Sounds → **Sounds Enabled** on, volume up, OS volume up. |
| Plays once then never again | Expected — it fires on the edge only. The value must go back and cross again. |
| Plays on connect | The value changed after the first sample arrived. Not a bug; the first sample alone never fires. |
| "Sound engine unavailable" in Settings | Dashboard failed to start the audio backend. On Linux install GStreamer (`gstreamer1.0-plugins-base`, `-good`). |
| Works on one laptop, not another | The sound file path does not exist on the second laptop. Copy the file to the same path. |
| Wrong condition types in the dropdown | Bool conditions ignore number topics and vice versa. Match the condition to the topic type. |
| Widget missing from **Show As** | Sound Trigger only appears for boolean and number topics. |
