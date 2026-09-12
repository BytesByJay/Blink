class Settings {
  final int intervalMinutes;
  final int lookAwaySeconds;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const Settings({
    required this.intervalMinutes,
    required this.lookAwaySeconds,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  const Settings.defaults()
      : intervalMinutes = 20,
        lookAwaySeconds = 20,
        soundEnabled = true,
        vibrationEnabled = true;

  Settings copyWith({
    int? intervalMinutes,
    int? lookAwaySeconds,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) =>
      Settings(
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        lookAwaySeconds: lookAwaySeconds ?? this.lookAwaySeconds,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      );

  Map<String, dynamic> toMap() => {
        'intervalMinutes': intervalMinutes,
        'lookAwaySeconds': lookAwaySeconds,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
      };

  factory Settings.fromMap(Map<String, dynamic> m) => Settings(
        intervalMinutes: m['intervalMinutes'] as int,
        lookAwaySeconds: m['lookAwaySeconds'] as int,
        soundEnabled: m['soundEnabled'] as bool,
        vibrationEnabled: m['vibrationEnabled'] as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.intervalMinutes == intervalMinutes &&
      other.lookAwaySeconds == lookAwaySeconds &&
      other.soundEnabled == soundEnabled &&
      other.vibrationEnabled == vibrationEnabled;

  @override
  int get hashCode => Object.hash(
      intervalMinutes, lookAwaySeconds, soundEnabled, vibrationEnabled);
}
