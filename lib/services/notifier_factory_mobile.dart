import 'package:flutter/foundation.dart';

import 'alarm_kit_notifier.dart';
import 'notification_service.dart';

/// iOS drives breaks through AlarmKit so they run in system UI; Android keeps
/// local notifications.
Notifier createNotifier() => defaultTargetPlatform == TargetPlatform.iOS
    ? AlarmKitNotifier()
    : NotificationService();
