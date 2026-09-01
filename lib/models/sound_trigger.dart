import 'package:uuid/uuid.dart';

enum SoundCondition {
  boolRising('Bool: False → True'),
  boolFalling('Bool: True → False'),
  numberCrossDown('Number: Crosses Down'),
  numberCrossUp('Number: Crosses Up');

  const SoundCondition(this.label);
  final String label;
}

class SoundTrigger {
  final String id;
  String label;
  String ntTopic;
  SoundCondition condition;
  double threshold;
  String soundPath;
  bool loop;

  SoundTrigger({
    String? id,
    this.label = '',
    this.ntTopic = '',
    this.condition = SoundCondition.boolRising,
    this.threshold = 0.0,
    this.soundPath = '',
    this.loop = false,
  }) : id = id ?? const Uuid().v4();

  SoundTrigger copyWith({
    String? label,
    String? ntTopic,
    SoundCondition? condition,
    double? threshold,
    String? soundPath,
    bool? loop,
  }) => SoundTrigger(
    id: id,
    label: label ?? this.label,
    ntTopic: ntTopic ?? this.ntTopic,
    condition: condition ?? this.condition,
    threshold: threshold ?? this.threshold,
    soundPath: soundPath ?? this.soundPath,
    loop: loop ?? this.loop,
  );

  factory SoundTrigger.fromJson(Map<String, dynamic> json) => SoundTrigger(
    id: json['id'] as String?,
    label: json['label'] as String? ?? '',
    ntTopic: json['ntTopic'] as String? ?? '',
    condition: SoundCondition.values.firstWhere(
      (c) => c.name == (json['condition'] as String? ?? ''),
      orElse: () => SoundCondition.boolRising,
    ),
    threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
    soundPath: json['soundPath'] as String? ?? '',
    loop: json['loop'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'ntTopic': ntTopic,
    'condition': condition.name,
    'threshold': threshold,
    'soundPath': soundPath,
    'loop': loop,
  };
}
