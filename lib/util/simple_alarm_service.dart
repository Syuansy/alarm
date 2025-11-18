import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

/// 简单的报警服务类，提供完全独立的功能
/// 每个功能都是纯粹的，不会相互干扰
class SimpleAlarmService {
  static final SimpleAlarmService _instance = SimpleAlarmService._internal();
  factory SimpleAlarmService() => _instance;
  SimpleAlarmService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  
  // 通知ID计数器，确保每个报警使用不同的ID
  int _notificationIdCounter = 1000;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 初始化通知插件（仅用于悬浮窗和提示音）
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: false,
        requestAlertPermission: true,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await _notificationsPlugin.initialize(initializationSettings);
      _isInitialized = true;
      debugPrint('<Info> SimpleAlarmService 初始化成功');
    } catch (e) {
      debugPrint('<Error> SimpleAlarmService 初始化失败: $e');
    }
  }

  /// 1. 纯悬浮窗功能 - 显示系统级悬浮窗（通知横幅）
  /// 这是最接近真正系统悬浮窗的实现方式
  Future<void> showSystemOverlay({
    String title = '系统悬浮窗测试',
    String subtitle = '纯悬浮窗显示，无声音无震动',
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      if (Platform.isAndroid) {
        // Android: 使用最高优先级通知显示为悬浮横幅
        final androidDetails = AndroidNotificationDetails(
          'overlay_only_channel',
          'System Overlay',
          channelDescription: 'Pure system overlay notifications',
          importance: Importance.max,
          priority: Priority.max,
          enableLights: false,
          enableVibration: false,  // 不震动
          playSound: false,        // 不播放声音
          fullScreenIntent: true,  // 全屏意图，确保显示为悬浮窗
          showWhen: false,
          autoCancel: true,
          ongoing: false,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(
            subtitle,
          ),
        );
        
        final notificationDetails = NotificationDetails(android: androidDetails);
        
        final overlayId = ++_notificationIdCounter;
        await _notificationsPlugin.show(
          overlayId, // 使用递增的ID
          title,
          subtitle,
          notificationDetails,
        );
      } else {
        // iOS: 使用横幅通知
        const iOSDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,  // 不播放声音
          presentBadge: false,  // 不显示角标
          interruptionLevel: InterruptionLevel.timeSensitive,
        );
        
        const notificationDetails = NotificationDetails(iOS: iOSDetails);
        
        final overlayId = ++_notificationIdCounter;
        await _notificationsPlugin.show(
          overlayId,
          title,
          subtitle,
          notificationDetails,
        );
      }
      
      debugPrint('<Info> 纯悬浮窗已显示');
    } catch (e) {
      debugPrint('<Error> 显示悬浮窗失败: $e');
      rethrow;
    }
  }

  /// 2. 纯提示音功能 - 只播放声音，不显示任何UI
  Future<void> playAlarmSound() async {
    if (!_isInitialized) await initialize();
    
    try {
      if (Platform.isAndroid) {
        // Android: 使用隐藏通知播放声音
        const androidDetails = AndroidNotificationDetails(
          'sound_only_channel',
          'Sound Only',
          channelDescription: 'Pure sound notifications',
          importance: Importance.low,     // 低重要性，避免显示UI
          priority: Priority.low,
          enableLights: false,
          enableVibration: false,         // 不震动
          playSound: true,                // 播放声音
          visibility: NotificationVisibility.secret, // 隐藏通知
          showWhen: false,
          autoCancel: true,
          ongoing: false,
          channelShowBadge: false,
          sound: RawResourceAndroidNotificationSound('alarm'), // 系统铃声
        );
        
        const notificationDetails = NotificationDetails(android: androidDetails);
        
        final soundId = ++_notificationIdCounter;
        await _notificationsPlugin.show(
          soundId, // 使用递增的ID
          '', // 空标题
          '', // 空内容
          notificationDetails,
        );
        
        // 3秒后自动取消通知，确保不留痕迹
        Future.delayed(const Duration(seconds: 3), () {
          _notificationsPlugin.cancel(soundId);
        });
      } else {
        // iOS: 使用系统声音
        const iOSDetails = DarwinNotificationDetails(
          presentAlert: false,  // 不显示警告
          presentSound: true,   // 播放声音
          presentBadge: false,  // 不显示角标
          sound: 'default',     // 默认系统声音
        );
        
        const notificationDetails = NotificationDetails(iOS: iOSDetails);
        
        final soundId = ++_notificationIdCounter;
        await _notificationsPlugin.show(
          soundId,
          '',
          '',
          notificationDetails,
        );
        
        // 自动取消
        Future.delayed(const Duration(seconds: 3), () {
          _notificationsPlugin.cancel(soundId);
        });
      }
      
      debugPrint('<Info> 纯提示音已播放');
    } catch (e) {
      debugPrint('<Error> 播放提示音失败: $e');
      rethrow;
    }
  }

  /// 3. 纯震动功能 - 使用vibration插件，完全独立于通知系统
  Future<void> vibrateDevice({int duration = 2000}) async {
    try {
      // 检查设备是否支持震动
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) {
        debugPrint('<Warn> 设备不支持震动功能');
        return;
      }

      // 检查是否有震动权限
      bool? hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      
      if (hasAmplitudeControl == true) {
        // 支持震动强度控制的设备
        await Vibration.vibrate(
          duration: duration,
          amplitude: 255, // 最大强度
        );
      } else {
        // 不支持强度控制的设备，使用模式震动
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500, 200, 500], // 震动模式：等待0ms，震动500ms，暂停200ms，重复
        );
      }
      
      debugPrint('<Info> 纯震动已触发，持续时间: ${duration}ms');
    } catch (e) {
      debugPrint('<Error> 震动失败: $e');
      rethrow;
    }
  }

  /// 4. 组合功能 - 同时执行悬浮窗、提示音和震动
  Future<void> triggerFullAlarm({
    String title = '系统悬浮窗测试',
    String subtitle = '组合功能：悬浮窗+提示音+震动',
  }) async {
    try {
      debugPrint('<Info> 开始触发组合报警功能...');
      
      // 立即触发所有功能，不等待完成，避免阻塞新报警
      showSystemOverlay(title: title, subtitle: subtitle).catchError((e) {
        debugPrint('<Error> 显示悬浮窗失败: $e');
      });
      
      playAlarmSound().catchError((e) {
        debugPrint('<Error> 播放提示音失败: $e');
      });
      
      vibrateDevice(duration: 2000).catchError((e) {
        debugPrint('<Error> 震动失败: $e');
      });
      
      debugPrint('<Info> 组合报警功能已全部触发（异步执行）');
    } catch (e) {
      debugPrint('<Error> 触发组合报警失败: $e');
      rethrow;
    }
  }

  /// 停止所有正在进行的报警
  Future<void> stopAllAlarms() async {
    try {
      // 取消所有通知
      await _notificationsPlugin.cancelAll();
      
      // 停止震动
      await Vibration.cancel();
      
      debugPrint('<Info> 所有报警已停止');
    } catch (e) {
      debugPrint('<Error> 停止报警失败: $e');
    }
  }

  /// 清理资源
  void dispose() {
    // 清理资源
    _isInitialized = false;
  }
}
