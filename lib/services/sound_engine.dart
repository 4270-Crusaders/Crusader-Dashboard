import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crusader_dashboard/models/sound_trigger.dart';
import 'package:crusader_dashboard/services/log.dart';
import 'package:crusader_dashboard/services/nt4_client.dart';
import 'package:crusader_dashboard/services/nt_connection.dart';
import 'package:crusader_dashboard/services/settings.dart';

class SoundEngine {
  final NTConnection ntConnection;
  final SharedPreferences preferences;

  List<SoundTrigger> _triggers = [];
  bool _disposed = false;

  // One subscription per unique NT topic
  final Map<String, NT4Subscription> _subs = {};
  final Map<String, Function(Object?, int)> _subListeners = {};
  final Map<String, Object?> _lastValues = {};

  // One AudioPlayer per trigger (supports independent looping)
  final Map<String, AudioPlayer> _players = {};

  SoundEngine({required this.ntConnection, required this.preferences});

  bool get enabled => preferences.getBool(PrefKeys.soundEnabled) ?? true;
  double get volume => preferences.getDouble(PrefKeys.soundVolume) ?? 1.0;
  List<SoundTrigger> get triggers => List.unmodifiable(_triggers);

  Future<void> init() async {
    _triggers = _loadTriggers();
    _rebuildSubscriptions();
  }

  List<SoundTrigger> _loadTriggers() {
    final String? raw = preferences.getString(PrefKeys.soundTriggers);
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .whereType<Map<String, dynamic>>()
          .map(SoundTrigger.fromJson)
          .toList();
    } catch (e) {
      logger.warning('SoundEngine: failed to parse triggers', e);
      return [];
    }
  }

  Future<void> _saveTriggers() async {
    final String json = jsonEncode(_triggers.map((t) => t.toJson()).toList());
    await preferences.setString(PrefKeys.soundTriggers, json);
  }

  void _unsubscribeAll() {
    for (final entry in _subs.entries) {
      entry.value.unlisten(_subListeners[entry.key]!);
      ntConnection.unSubscribe(entry.value);
    }
    _subs.clear();
    _subListeners.clear();
  }

  void _rebuildSubscriptions() {
    _unsubscribeAll();
    _lastValues.clear();

    // Group triggers by topic
    final Map<String, List<SoundTrigger>> byTopic = {};
    for (final t in _triggers) {
      if (t.ntTopic.isEmpty) continue;
      byTopic.putIfAbsent(t.ntTopic, () => []).add(t);
    }

    for (final entry in byTopic.entries) {
      final sub = ntConnection.subscribe(entry.key, 0.02);
      _subs[entry.key] = sub;
      final triggers = entry.value;
      void listener(Object? value, int timestamp) =>
          _onValue(entry.key, value, triggers);
      _subListeners[entry.key] = listener;
      sub.listen(listener);
    }
  }

  void _onValue(String topic, Object? value, List<SoundTrigger> triggers) {
    if (_disposed) return;

    final Object? prev = _lastValues[topic];
    _lastValues[topic] = value;
    if (!enabled || (prev == null && value == null)) return;

    for (final trigger in triggers) {
      _checkTrigger(trigger, prev, value);
    }
  }

  void _checkTrigger(SoundTrigger trigger, Object? prev, Object? curr) {
    switch (trigger.condition) {
      case SoundCondition.boolRising:
        final p = prev is bool ? prev : null;
        final c = curr is bool ? curr : null;
        if (c == true && p == false) {
          _play(trigger);
        } else if (trigger.loop && c == false) {
          _stopLoop(trigger.id);
        }
        break;

      case SoundCondition.boolFalling:
        final p = prev is bool ? prev : null;
        final c = curr is bool ? curr : null;
        if (c == false && p == true) {
          _play(trigger);
        } else if (trigger.loop && c == true) {
          _stopLoop(trigger.id);
        }
        break;

      case SoundCondition.numberCrossDown:
        final p = _toDouble(prev);
        final c = _toDouble(curr);
        if (p != null &&
            c != null &&
            p > trigger.threshold &&
            c <= trigger.threshold) {
          _play(trigger);
        }
        break;

      case SoundCondition.numberCrossUp:
        final p = _toDouble(prev);
        final c = _toDouble(curr);
        if (p != null &&
            c != null &&
            p < trigger.threshold &&
            c >= trigger.threshold) {
          _play(trigger);
        }
        break;
    }
  }

  double? _toDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return null;
  }

  Future<void> _play(SoundTrigger trigger) async {
    if (trigger.soundPath.isEmpty) return;
    final AudioPlayer player = _players.putIfAbsent(
      trigger.id,
      AudioPlayer.new,
    );
    try {
      await player.setVolume(volume);
      await player.setReleaseMode(
        trigger.loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      await player.play(DeviceFileSource(trigger.soundPath));
    } catch (e) {
      logger.warning('SoundEngine: play failed for "${trigger.label}"', e);
    }
  }

  Future<void> _stopLoop(String triggerId) async {
    final AudioPlayer? player = _players[triggerId];
    if (player != null && player.state == PlayerState.playing) {
      await player.stop();
    }
  }

  Future<void> addTrigger(SoundTrigger trigger) async {
    _triggers.add(trigger);
    await _saveTriggers();
    _rebuildSubscriptions();
  }

  Future<void> removeTrigger(String id) async {
    _triggers.removeWhere((t) => t.id == id);
    final AudioPlayer? player = _players.remove(id);
    await player?.dispose();
    await _saveTriggers();
    _rebuildSubscriptions();
  }

  Future<void> updateTrigger(SoundTrigger trigger) async {
    final int idx = _triggers.indexWhere((t) => t.id == trigger.id);
    if (idx >= 0) _triggers[idx] = trigger;
    await _saveTriggers();
    _rebuildSubscriptions();
  }

  Future<void> setEnabled(bool value) async {
    await preferences.setBool(PrefKeys.soundEnabled, value);
    if (!value) {
      for (final p in _players.values) {
        await p.stop();
      }
    }
  }

  Future<void> setVolume(double value) async {
    await preferences.setDouble(PrefKeys.soundVolume, value);
  }

  void dispose() {
    _disposed = true;
    _unsubscribeAll();
    for (final player in _players.values) {
      player.dispose();
    }
  }
}
