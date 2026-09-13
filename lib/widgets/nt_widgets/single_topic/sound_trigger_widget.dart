import 'dart:async';

import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:crusader_dashboard/models/sound_trigger.dart';
import 'package:crusader_dashboard/services/log.dart';
import 'package:crusader_dashboard/services/nt4_client.dart';
import 'package:crusader_dashboard/services/settings.dart';
import 'package:crusader_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:crusader_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:crusader_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:crusader_dashboard/widgets/nt_widgets/nt_widget.dart';

class SoundTriggerWidgetModel extends SingleTopicNTWidgetModel {
  static const String widgetType = 'Sound Trigger';

  @override
  String get type => widgetType;

  SoundCondition condition;
  double threshold;
  String soundPath;
  bool loop;

  bool isPlaying = false;

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  Object? _lastValue;
  NT4Subscription? _listening;

  SoundTriggerWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.ntStructMeta,
    super.dataType,
    super.period,
    this.condition = SoundCondition.boolRising,
    this.threshold = 0.0,
    this.soundPath = '',
    this.loop = false,
  }) : super();

  SoundTriggerWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : condition = SoundCondition.values.firstWhere(
         (c) => c.name == (jsonData['condition'] as String? ?? ''),
         orElse: () => SoundCondition.boolRising,
       ),
       threshold = (jsonData['threshold'] as num?)?.toDouble() ?? 0.0,
       soundPath = jsonData['soundPath'] as String? ?? '',
       loop = jsonData['loop'] as bool? ?? false,
       super.fromJson();

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'condition': condition.name,
    'threshold': threshold,
    'soundPath': soundPath,
    'loop': loop,
  };

  bool get _soundEnabled => preferences.getBool(PrefKeys.soundEnabled) ?? true;
  double get _volume => preferences.getDouble(PrefKeys.soundVolume) ?? 1.0;

  @override
  void init() {
    super.init();
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        if (isPlaying) {
          isPlaying = false;
          refresh();
        }
      }
    });
    _attachListener();
  }

  void _attachListener() {
    if (identical(_listening, subscription)) return;
    _detachListener();
    _lastValue = null;
    _listening = subscription;
    subscription?.listen(_onValue);
  }

  void _detachListener() {
    _listening?.unlisten(_onValue);
    _listening = null;
  }

  void _onValue(Object? value, int timestamp) {
    final Object? prev = _lastValue;
    _lastValue = value;
    if (!_soundEnabled) return;

    bool shouldPlay = false;
    bool shouldStop = false;

    switch (condition) {
      case SoundCondition.boolRising:
        final p = prev is bool ? prev : null;
        final c = value is bool ? value : null;
        if (c == true && p == false) shouldPlay = true;
        if (loop && c == false) shouldStop = true;
        break;
      case SoundCondition.boolFalling:
        final p = prev is bool ? prev : null;
        final c = value is bool ? value : null;
        if (c == false && p == true) shouldPlay = true;
        if (loop && c == true) shouldStop = true;
        break;
      case SoundCondition.numberCrossDown:
        final p = _toDouble(prev);
        final c = _toDouble(value);
        if (p != null && c != null && p > threshold && c <= threshold) {
          shouldPlay = true;
        }
        break;
      case SoundCondition.numberCrossUp:
        final p = _toDouble(prev);
        final c = _toDouble(value);
        if (p != null && c != null && p < threshold && c >= threshold) {
          shouldPlay = true;
        }
        break;
    }

    if (shouldStop) {
      _player.stop();
      return;
    }
    if (shouldPlay && soundPath.isNotEmpty) {
      _playSound();
    }
  }

  double? _toDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return null;
  }

  Future<void> _playSound() async {
    try {
      await _player.setVolume(_volume);
      await _player.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      await _player.play(DeviceFileSource(soundPath));
      isPlaying = true;
      refresh();
    } catch (e) {
      logger.warning('SoundTriggerWidget: failed to play $soundPath', e);
    }
  }

  @override
  void resetSubscription() {
    super.resetSubscription();
    _attachListener();
  }

  @override
  void softDispose({bool deleting = false}) {
    if (deleting) {
      _detachListener();
      _stateSub?.cancel();
      _player.dispose();
      isPlaying = false;
    }
  }

  @override
  void unSubscribe() {
    _detachListener();
    _player.stop();
    isPlaying = false;
    super.unSubscribe();
  }

  @override
  List<String> getAvailableDisplayTypes() => [widgetType];

  @override
  List<Widget> getEditProperties(BuildContext context) {
    final bool isNumeric =
        condition == SoundCondition.numberCrossDown ||
        condition == SoundCondition.numberCrossUp;

    return [
      // Condition picker
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('Trigger Condition'),
          ),
          DialogDropdownChooser<String>(
            onSelectionChanged: (value) {
              if (value == null) return;
              condition = SoundCondition.values.firstWhere(
                (c) => c.label == value,
                orElse: () => SoundCondition.boolRising,
              );
              refresh();
            },
            choices: SoundCondition.values.map((c) => c.label).toList(),
            initialValue: condition.label,
          ),
        ],
      ),
      const SizedBox(height: 5),
      // Threshold (number conditions only)
      if (isNumeric)
        DialogTextInput(
          label: 'Threshold',
          initialText: threshold.toString(),
          onSubmit: (value) {
            threshold = double.tryParse(value) ?? threshold;
            refresh();
          },
        ),
      if (isNumeric) const SizedBox(height: 5),
      // Sound file picker
      _SoundFilePicker(
        initialPath: soundPath,
        onPathSelected: (path) {
          soundPath = path;
          refresh();
        },
      ),
      const SizedBox(height: 5),
      // Loop toggle
      DialogToggleSwitch(
        label: 'Loop Until Condition Ends',
        initialValue: loop,
        onToggle: (value) {
          loop = value;
          refresh();
        },
      ),
    ];
  }
}

/// Inline file-picker row used in widget edit dialog.
class _SoundFilePicker extends StatefulWidget {
  final String initialPath;
  final void Function(String path) onPathSelected;

  const _SoundFilePicker({
    required this.initialPath,
    required this.onPathSelected,
  });

  @override
  State<_SoundFilePicker> createState() => _SoundFilePickerState();
}

class _SoundFilePickerState extends State<_SoundFilePicker> {
  late String _path = widget.initialPath;

  @override
  Widget build(BuildContext context) {
    final String name = _path.isEmpty ? 'No file selected' : p.basename(_path);

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _path.isEmpty
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
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
      ),
    );
  }
}

class SoundTriggerWidget extends NTWidget {
  static const String widgetType = 'Sound Trigger';

  const SoundTriggerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final SoundTriggerWidgetModel model = cast(context.watch<NTWidgetModel>());
    final bool playing = model.isPlaying;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: playing ? cs.primaryContainer : cs.surfaceContainerHighest,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            playing ? Icons.volume_up : Icons.volume_mute,
            size: 36,
            color: playing ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            model.topic.split('/').last,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            model.condition.label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (playing && model.loop) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: cs.tertiary,
              ),
              child: Text(
                'LOOPING',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onTertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
