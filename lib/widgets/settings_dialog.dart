import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crusader_dashboard/models/sound_trigger.dart';
import 'package:crusader_dashboard/services/ip_address_util.dart';
import 'package:crusader_dashboard/services/nt_connection.dart';
import 'package:crusader_dashboard/services/settings.dart';
import 'package:crusader_dashboard/services/sound_engine.dart';
import 'package:crusader_dashboard/services/text_formatter_builder.dart';
import 'package:crusader_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:crusader_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:crusader_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:crusader_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:crusader_dashboard/widgets/dialog_widgets/nt_topic_picker_dialog.dart';

class SettingsDialog extends StatefulWidget {
  final NTConnection ntConnection;
  final SoundEngine? soundEngine;

  static final List<String> themeVariants =
      FlexSchemeVariant.values
          .whereNot((variant) => variant == Defaults.themeVariant)
          .map((variant) => variant.variantName)
          .toList()
        ..add(Defaults.defaultVariantName)
        ..sort();

  static final List<String> logLevelNames =
      Level.values
          .where((level) => level.value % 1000 == 0)
          .map((e) => e.levelName)
          .toList()
        ..insert(0, Defaults.defaultLogLevelName);

  final SharedPreferences preferences;

  final FutureOr<void> Function(String? data)? onIPAddressChanged;
  final FutureOr<void> Function(String? data)? onTeamNumberChanged;
  final void Function(IPAddressMode mode)? onIPAddressModeChanged;
  final FutureOr<void> Function(NTServerTarget mode)? onNTTargetServerChanged;
  final void Function(Color color)? onColorChanged;
  final void Function(bool value)? onGridToggle;
  final FutureOr<void> Function(String? gridSize)? onGridSizeChanged;
  final FutureOr<void> Function(String? radius)? onCornerRadiusChanged;
  final void Function(bool value)? onResizeToDSChanged;
  final void Function(bool value)? onRememberWindowPositionChanged;
  final void Function(bool value)? onLayoutLock;
  final FutureOr<void> Function(String? value)? onDefaultPeriodChanged;
  final FutureOr<void> Function(String? value)? onDefaultGraphPeriodChanged;
  final void Function(FlexSchemeVariant variant)? onThemeVariantChanged;
  final void Function(Level? level)? onLogLevelChanged;
  final FutureOr<void> Function(String? value)? onGridDPIChanged;
  final void Function()? onOpenAssetsFolderPressed;
  final FutureOr<void> Function(bool value)? onAutoSubmitButtonChanged;

  const SettingsDialog({
    super.key,
    required this.ntConnection,
    required this.preferences,
    this.soundEngine,
    this.onTeamNumberChanged,
    this.onIPAddressModeChanged,
    this.onNTTargetServerChanged,
    this.onIPAddressChanged,
    this.onColorChanged,
    this.onGridToggle,
    this.onGridSizeChanged,
    this.onCornerRadiusChanged,
    this.onResizeToDSChanged,
    this.onRememberWindowPositionChanged,
    this.onLayoutLock,
    this.onDefaultPeriodChanged,
    this.onDefaultGraphPeriodChanged,
    this.onThemeVariantChanged,
    this.onLogLevelChanged,
    this.onGridDPIChanged,
    this.onOpenAssetsFolderPressed,
    this.onAutoSubmitButtonChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Settings'),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
    content: DefaultTabController(
      length: 4,
      child: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(icon: Icon(Icons.wifi_outlined), child: Text('Network')),
                Tab(
                  icon: Icon(Icons.color_lens_outlined),
                  child: Text('Appearance'),
                ),
                Tab(
                  icon: Icon(Icons.volume_up_outlined),
                  child: Text('Sounds'),
                ),
                Tab(
                  icon: Icon(Icons.code),
                  child: Text('Advanced'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                children: [
                  // Network Tab
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            ..._ipAddressSettings(),
                            const Divider(),
                            ..._networkTablesSettings(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Style Preferences Tab
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: kIsWeb ? 360 : 415,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            ..._themeSettings(),
                            const Divider(),
                            ..._gridSettings(),
                            const Divider(),
                            ..._otherSettings(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Sounds Tab
                  _SoundsTab(
                    preferences: widget.preferences,
                    ntConnection: widget.ntConnection,
                    soundEngine: widget.soundEngine,
                  ),
                  // Advanced Settings Tab
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 205),
                        child: Column(children: [..._advancedSettings()]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );

  Widget _resizeToDSSwitch(BuildContext context) => DialogToggleSwitch(
    initialValue:
        widget.preferences.getBool(PrefKeys.autoResizeToDS) ??
        Defaults.autoResizeToDS,
    label: 'Resize to Driver Station Height',
    onToggle: (value) {
      setState(() {
        widget.onResizeToDSChanged?.call(value);
      });
    },
  );

  Widget _lockLayoutSwitch(BuildContext context) => DialogToggleSwitch(
    initialValue:
        widget.preferences.getBool(PrefKeys.layoutLocked) ??
        Defaults.layoutLocked,
    label: 'Lock Layout',
    onToggle: (value) {
      setState(() {
        widget.onLayoutLock?.call(value);
      });
    },
  );

  List<Widget> _themeSettings() {
    Color currentColor = Color(
      widget.preferences.getInt(PrefKeys.teamColor) ??
          Colors.blueAccent.toARGB32(),
    );

    // Safety feature to prevent theme variants dropdown from not rendering if the current selection doesn't exist
    List<String>? themeVariantsOverride;
    if (!SettingsDialog.themeVariants.contains(
          widget.preferences.getString(PrefKeys.themeVariant),
        ) &&
        widget.preferences.getString(PrefKeys.themeVariant) != null) {
      // Weird way of copying the list
      themeVariantsOverride = SettingsDialog.themeVariants.toList()
        ..add(widget.preferences.getString(PrefKeys.themeVariant)!)
        ..sort();
      themeVariantsOverride = Set.of(themeVariantsOverride).toList();
    }

    return [
      const Align(alignment: Alignment.topLeft, child: Text('Theme Settings')),
      IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: 140,
              child: UnconstrainedBox(
                constrainedAxis: Axis.horizontal,
                child: DialogColorPicker(
                  onColorPicked: (color) => widget.onColorChanged?.call(color),
                  label: 'Team Color',
                  initialColor: currentColor,
                  defaultColor: Colors.blueAccent,
                  rowSize: MainAxisSize.max,
                ),
              ),
            ),
            const VerticalDivider(),
            Flexible(
              child: Column(
                children: [
                  const Text('Theme Variant'),
                  DialogDropdownChooser<String>(
                    onSelectionChanged: (variantName) {
                      if (variantName == null) return;
                      FlexSchemeVariant variant =
                          FlexSchemeVariant.values.firstWhereOrNull(
                            (e) => e.variantName == variantName,
                          ) ??
                          FlexSchemeVariant.material3Legacy;

                      widget.onThemeVariantChanged?.call(variant);
                      setState(() {});
                    },
                    choices:
                        themeVariantsOverride ?? SettingsDialog.themeVariants,
                    initialValue:
                        widget.preferences.getString(PrefKeys.themeVariant) ??
                        Defaults.defaultVariantName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _ipAddressSettings() => [
    const Align(
      alignment: Alignment.topLeft,
      child: Text('Connection Settings'),
    ),
    const SizedBox(height: 5),
    Row(
      children: [
        Flexible(
          flex: 2,
          child: DialogTextInput(
            initialText:
                widget.preferences.getInt(PrefKeys.teamNumber)?.toString() ??
                '',
            label: 'Team Number',
            onSubmit: (data) async {
              await widget.onTeamNumberChanged?.call(data);
              setState(() {});
            },
            formatter: FilteringTextInputFormatter.digitsOnly,
          ),
        ),
        Flexible(
          flex: 3,
          child: ValueListenableBuilder(
            valueListenable: widget.ntConnection.dsConnected,
            builder: (context, connected, child) {
              int addressModeID =
                  widget.preferences.getInt(PrefKeys.ipAddressMode) ??
                  Defaults.ipAddressMode.id;
              bool canEditIP =
                  addressModeID == IPAddressMode.custom.id ||
                  (addressModeID == IPAddressMode.driverStation.id &&
                      !connected);
              return DialogTextInput(
                enabled: canEditIP,
                initialText:
                    widget.preferences.getString(PrefKeys.ipAddress) ??
                    Defaults.ipAddress,
                label: 'IP Address',
                onSubmit: (String? data) async {
                  await widget.onIPAddressChanged?.call(data);
                  setState(() {});
                },
              );
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      children: [
        const Text('IP Address Mode'),
        const SizedBox(width: 5),
        Flexible(
          child: DialogDropdownChooser<IPAddressMode>(
            onSelectionChanged: (mode) {
              if (mode == null) {
                return;
              }

              widget.onIPAddressModeChanged?.call(mode);

              setState(() {});
            },
            choices: IPAddressMode.values,
            initialValue: IPAddressMode.fromID(
              widget.preferences.getInt(PrefKeys.ipAddressMode),
            ),
          ),
        ),
      ],
    ),
  ];

  List<Widget> _gridSettings() => [
    const Align(alignment: Alignment.topLeft, child: Text('Grid Settings')),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: DialogToggleSwitch(
            initialValue:
                widget.preferences.getBool(PrefKeys.showGrid) ??
                Defaults.showGrid,
            label: 'Show Grid',
            onToggle: (value) {
              setState(() {
                widget.onGridToggle?.call(value);
              });
            },
          ),
        ),
        Flexible(
          child: DialogTextInput(
            initialText:
                widget.preferences.getInt(PrefKeys.gridSize)?.toString() ??
                Defaults.gridSize.toString(),
            label: 'Grid Size',
            onSubmit: (value) async {
              await widget.onGridSizeChanged?.call(value);
              setState(() {});
            },
            formatter: FilteringTextInputFormatter.digitsOnly,
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          flex: 2,
          child: DialogTextInput(
            initialText:
                (widget.preferences.getDouble(PrefKeys.cornerRadius) ??
                        Defaults.cornerRadius.toString())
                    .toString(),
            label: 'Corner Radius',
            onSubmit: (value) async {
              await widget.onCornerRadiusChanged?.call(value);
              setState(() {});
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(),
          ),
        ),
        Flexible(
          flex: 3,
          child: kIsWeb
              ? _lockLayoutSwitch(context)
              : _resizeToDSSwitch(context),
        ),
      ],
    ),
    if (!kIsWeb) ...[
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            flex: 5,
            child: DialogToggleSwitch(
              initialValue:
                  widget.preferences.getBool(
                    PrefKeys.rememberWindowPosition,
                  ) ??
                  false,
              label: 'Remember Window Position',
              onToggle: (value) {
                setState(() {
                  widget.onRememberWindowPositionChanged?.call(value);
                });
              },
            ),
          ),
          Flexible(flex: 4, child: _lockLayoutSwitch(context)),
        ],
      ),
    ],
  ];

  List<Widget> _otherSettings() => [
    const Align(alignment: Alignment.topLeft, child: Text('Other Settings')),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: DialogToggleSwitch(
            initialValue: false,
            label: 'Auto Show Text Submit Button',
            onToggle: (value) async {
              await widget.onAutoSubmitButtonChanged?.call(value);
              setState(() {});
            },
          ),
        ),
      ],
    ),
  ];

  List<Widget> _networkTablesSettings() => [
    const Align(
      alignment: Alignment.topLeft,
      child: Text('Network Tables Settings'),
    ),
    const SizedBox(height: 5),
    Row(
      children: [
        Tooltip(
          waitDuration: const Duration(milliseconds: 100),
          message: '''
There are 2 Network Tables servers on the SystemCore:

Robot Code - The Network Tables server displaying data from the robot code.
SystemCore Internal - The Network Tables server displaying internal data from the SystemCore (RAM, CPU, etc).''',
          child: Icon(Icons.help_outline),
        ),
        const SizedBox(width: 5),
        const Text('Target Server'),
        const SizedBox(width: 5),
        Flexible(
          child: DialogDropdownChooser<NTServerTarget>(
            onSelectionChanged: (mode) async {
              if (mode == null) {
                return;
              }

              await widget.onNTTargetServerChanged?.call(mode);

              setState(() {});
            },
            choices: NTServerTarget.values,
            initialValue:
                NTServerTarget.fromIndex(
                  widget.preferences.getInt(PrefKeys.ntTargetServer),
                ) ??
                Defaults.targetServer,
            nameMap: (e) => e.name,
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Flexible(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: DialogTextInput(
              initialText:
                  (widget.preferences.getDouble(PrefKeys.defaultPeriod) ??
                          Defaults.defaultPeriod)
                      .toString(),
              label: 'Default Period',
              onSubmit: (value) async {
                await widget.onDefaultPeriodChanged?.call(value);
                setState(() {});
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
            ),
          ),
          Flexible(
            child: DialogTextInput(
              initialText:
                  (widget.preferences.getDouble(
                            PrefKeys.defaultGraphPeriod,
                          ) ??
                          Defaults.defaultGraphPeriod)
                      .toString(),
              label: 'Default Graph Period',
              onSubmit: (value) async {
                widget.onDefaultGraphPeriodChanged?.call(value);
                setState(() {});
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
            ),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _advancedSettings() {
    String initialLogLevel =
        widget.preferences.getString(PrefKeys.logLevel) ??
        Defaults.defaultLogLevelName;
    if (!SettingsDialog.logLevelNames.contains(initialLogLevel)) {
      initialLogLevel = Defaults.defaultLogLevelName;
    }

    return [
      Row(
        children: [
          const Icon(Icons.warning, color: Colors.yellow),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'WARNING: These are advanced settings that could cause issues if changed incorrectly. It is advised to not change anything here unless if you know what you are doing.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.warning, color: Colors.yellow),
        ],
      ),
      const Divider(),
      Row(
        children: [
          const Text('Log Level'),
          const SizedBox(width: 5),
          Flexible(
            child: DialogDropdownChooser<String>(
              choices: SettingsDialog.logLevelNames,
              initialValue: initialLogLevel,
              onSelectionChanged: (value) {
                Level? selectedLevel = Settings.logLevels.firstWhereOrNull(
                  (level) => level.levelName == value,
                );
                widget.onLogLevelChanged?.call(selectedLevel);
                setState(() {});
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Row(
        children: [
          Flexible(
            child: DialogTextInput(
              initialText:
                  widget.preferences
                      .getDouble(PrefKeys.gridDpiOverride)
                      ?.toString() ??
                  '',
              label: 'Grid DPI',
              formatter: TextFormatterBuilder.decimalTextFormatter(),
              allowEmptySubmission: true,
              onSubmit: (value) async {
                await widget.onGridDPIChanged?.call(value);
                setState(() {});
              },
            ),
          ),
          if (!kIsWeb && !Platform.isMacOS)
            TextButton.icon(
              onPressed: () {
                widget.onOpenAssetsFolderPressed?.call();
              },
              icon: const Icon(Icons.folder_outlined),
              label: const Text('Open Assets Folder'),
            ),
        ],
      ),
    ];
  }
}

// ─── Sounds Tab ─────────────────────────────────────────────────────────────

class _SoundsTab extends StatefulWidget {
  final SharedPreferences preferences;
  final SoundEngine? soundEngine;
  final NTConnection ntConnection;

  const _SoundsTab({
    required this.preferences,
    required this.ntConnection,
    this.soundEngine,
  });

  @override
  State<_SoundsTab> createState() => _SoundsTabState();
}

class _SoundsTabState extends State<_SoundsTab> {
  late bool _enabled =
      widget.preferences.getBool(PrefKeys.soundEnabled) ?? true;
  late double _volume =
      widget.preferences.getDouble(PrefKeys.soundVolume) ?? 1.0;

  SoundEngine? get _engine => widget.soundEngine;

  List<SoundTrigger> get _triggers => _engine?.triggers ?? [];

  @override
  Widget build(BuildContext context) {
    final triggers = _triggers;
    return Column(
      children: [
        // Volume + enable row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Switch(
                value: _enabled,
                onChanged: (v) async {
                  await _engine?.setEnabled(v);
                  await widget.preferences.setBool(PrefKeys.soundEnabled, v);
                  setState(() => _enabled = v);
                },
              ),
              const Text('Sounds Enabled'),
              const SizedBox(width: 16),
              const Icon(Icons.volume_down, size: 18),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: (_volume * 100).round().toString(),
                  onChanged: (v) => setState(() => _volume = v),
                  onChangeEnd: (v) async {
                    await _engine?.setVolume(v);
                    await widget.preferences.setDouble(PrefKeys.soundVolume, v);
                  },
                ),
              ),
              const Icon(Icons.volume_up, size: 18),
            ],
          ),
        ),
        const Divider(height: 1),
        // Trigger list header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Background Sound Triggers',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add trigger',
                onPressed: _engine == null ? null : () => _openEditDialog(null),
              ),
            ],
          ),
        ),
        // Trigger list — Expanded fills remaining space
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: triggers.isEmpty
                ? Center(
                    child: Text(
                      _engine == null
                          ? 'Sound engine unavailable'
                          : 'No triggers — press + to add',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: triggers.length,
                    itemBuilder: (context, i) {
                      final t = triggers[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          t.label.isEmpty ? t.ntTopic : t.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${t.condition.label}${t.loop ? '  •  loop' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _openEditDialog(t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () async {
                                await _engine!.removeTrigger(t.id);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _openEditDialog(SoundTrigger? existing) async {
    final SoundTrigger? result = await showDialog<SoundTrigger>(
      context: context,
      builder: (ctx) => _TriggerEditDialog(
        trigger: existing,
        ntConnection: widget.ntConnection,
      ),
    );
    if (result == null) return;
    if (existing == null) {
      await _engine!.addTrigger(result);
    } else {
      await _engine!.updateTrigger(result);
    }
    setState(() {});
  }
}

// ─── Trigger Edit Dialog ─────────────────────────────────────────────────────

class _TriggerEditDialog extends StatefulWidget {
  final SoundTrigger? trigger;
  final NTConnection ntConnection;

  const _TriggerEditDialog({
    this.trigger,
    required this.ntConnection,
  });

  @override
  State<_TriggerEditDialog> createState() => _TriggerEditDialogState();
}

class _TriggerEditDialogState extends State<_TriggerEditDialog> {
  late String _label;
  late String _ntTopic;
  late TextEditingController _labelCtrl;
  late TextEditingController _ntTopicCtrl;
  late TextEditingController _thresholdCtrl;
  late SoundCondition _condition;
  late double _threshold;
  late String _soundPath;
  late bool _loop;

  @override
  void initState() {
    super.initState();
    final t = widget.trigger;
    _label = t?.label ?? '';
    _ntTopic = t?.ntTopic ?? '';
    _labelCtrl = TextEditingController(text: _label);
    _ntTopicCtrl = TextEditingController(text: _ntTopic);
    _condition = t?.condition ?? SoundCondition.boolRising;
    _threshold = t?.threshold ?? 0.0;
    _thresholdCtrl = TextEditingController(text: _threshold.toString());
    _soundPath = t?.soundPath ?? '';
    _loop = t?.loop ?? false;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _ntTopicCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  bool get _isNumeric =>
      _condition == SoundCondition.numberCrossDown ||
      _condition == SoundCondition.numberCrossUp;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.trigger == null ? 'Add Trigger' : 'Edit Trigger'),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
              ),
              controller: _labelCtrl,
              onChanged: (v) => _label = v,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'NT Topic',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                    ),
                    controller: _ntTopicCtrl,
                    onChanged: (v) => setState(() => _ntTopic = v),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.account_tree_outlined, size: 16),
                    label: const Text('Browse'),
                    onPressed: () async {
                      final String? picked = await showNTTopicPicker(
                        context: context,
                        ntConnection: widget.ntConnection,
                      );
                      if (picked != null) {
                        setState(() {
                          _ntTopic = picked;
                          _ntTopicCtrl.text = picked;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SoundCondition>(
              initialValue: _condition,
              decoration: const InputDecoration(
                labelText: 'Condition',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
              ),
              items: SoundCondition.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _condition = v);
              },
            ),
            if (_isNumeric) ...[
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Threshold',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                controller: _thresholdCtrl,
                onChanged: (v) => _threshold = double.tryParse(v) ?? _threshold,
              ),
            ],
            const SizedBox(height: 8),
            _SoundFileRow(
              initialPath: _soundPath,
              onPathSelected: (path) => setState(() => _soundPath = path),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              title: const Text('Loop until condition ends'),
              value: _loop,
              onChanged: (v) => setState(() => _loop = v),
              dense: true,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _ntTopic.isEmpty
            ? null
            : () {
                final trigger = (widget.trigger ?? SoundTrigger()).copyWith(
                  label: _label,
                  ntTopic: _ntTopic,
                  condition: _condition,
                  threshold: _threshold,
                  soundPath: _soundPath,
                  loop: _loop,
                );
                Navigator.of(context).pop(trigger);
              },
        child: const Text('Save'),
      ),
    ],
  );
}

class _SoundFileRow extends StatefulWidget {
  final String initialPath;
  final void Function(String) onPathSelected;

  const _SoundFileRow({
    required this.initialPath,
    required this.onPathSelected,
  });

  @override
  State<_SoundFileRow> createState() => _SoundFileRowState();
}

class _SoundFileRowState extends State<_SoundFileRow> {
  late String _path = widget.initialPath;

  @override
  Widget build(BuildContext context) {
    final String name = _path.isEmpty ? 'No file selected' : p.basename(_path);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Text(name, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            const XTypeGroup audioGroup = XTypeGroup(
              label: 'Audio',
              extensions: ['wav', 'mp3', 'aac', 'm4a'],
            );
            final XFile? file = await openFile(
              acceptedTypeGroups: [audioGroup],
            );
            if (file != null) {
              setState(() => _path = file.path);
              widget.onPathSelected(file.path);
            }
          },
          child: const Text('Browse'),
        ),
      ],
    );
  }
}
