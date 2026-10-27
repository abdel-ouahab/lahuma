import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_notifications.dart';

/// The app's single [LocalNotifications] instance (initialised in `main`).
final localNotificationsProvider =
    Provider<LocalNotifications>((ref) => LocalNotifications());
