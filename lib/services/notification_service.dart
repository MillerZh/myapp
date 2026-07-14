import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/signal.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const channelId = 'stock_signals';
  static const channelName = '纪律信号';
  static const channelDescription = 'A股纪律扫描与盘中监控提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _payloads =
      StreamController<String>.broadcast();
  bool _initialized = false;

  Stream<String> get payloads => _payloads.stream;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    const android = AndroidInitializationSettings('ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _payloads.add(payload);
      },
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) {
      final web = _plugin
          .resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin
          >();
      if (web == null) return false;
      return await web.requestNotificationsPermission() ?? false;
    }
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  Future<void> showSignal(TradeSignal signal) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      id: signal.id.hashCode & 0x7fffffff,
      title: '${signal.name} · ${signal.title}',
      body: signal.advice,
      notificationDetails: details,
      payload: 'stock:${signal.code}',
    );
  }

  Future<void> showTest() async {
    await showSignal(
      TradeSignal(
        id: 'notification-test-${DateTime.now().millisecondsSinceEpoch}',
        code: '600519',
        name: '通知测试',
        title: '纪律提醒通道正常',
        reason: '这是一条测试通知。',
        advice: '收到此通知说明权限与通知渠道可用。',
        disciplineId: 'test',
        disciplineName: '系统测试',
        action: SignalAction.watch,
        side: SignalSide.neutral,
        triggeredAt: DateTime.now(),
        score: 100,
      ),
    );
  }
}
