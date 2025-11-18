import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'dart:typed_data';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();
  
  // 本地通知插件实例
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // 初始化通知
  Future<void> initNotifications() async {
    if (_isInitialized) return;
    
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('<Error> 初始化通知出错: $e');
      // 尝试继续执行，虽然通知功能可能不会正常工作
    }
  }

  // iOS旧版通知回调 - 保留方法但不再使用
  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    debugPrint('<Info> 接收到iOS本地通知: $id, $title, $body, $payload');
  }

  // 通知响应回调
  void onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint('<Info> 通知响应: ${response.payload}');
  }
  
  // 请求所有权限
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};
    
    try {
      // 申请通知权限
      statuses[Permission.notification] = await Permission.notification.request();
      
      // 申请震动权限 (Android无需单独申请，iOS不支持单独申请)
      if(Platform.isAndroid) {
        // 震动权限在Android中包含在通知权限中
      }
      
      // 申请悬浮窗权限（仅Android需要）
      if(Platform.isAndroid) {
        statuses[Permission.systemAlertWindow] = await Permission.systemAlertWindow.request();
      }
      
      // 申请闹钟权限（仅Android需要）
      if(Platform.isAndroid) {
        statuses[Permission.scheduleExactAlarm] = await Permission.scheduleExactAlarm.request();
      }
      
      // 其他可能需要的权限 - iOS不需要日历权限，我们改为申请通知权限
      if(Platform.isIOS) {
        statuses[Permission.notification] = await Permission.notification.request();
      }
      
      return statuses;
    } catch (e) {
      debugPrint('<Error> 请求权限发生错误: $e');
      // 返回空映射，表示请求失败
      return statuses;
    }
  }
  
  // 检查单个权限状态
  Future<PermissionStatus> checkPermission(Permission permission) async {
    try {
      return await permission.status;
    } catch (e) {
      debugPrint('<Error> 检查权限状态发生错误: $e');
      return PermissionStatus.denied;
    }
  }
  
  // 检查多个权限状态
  Future<Map<Permission, PermissionStatus>> checkPermissions(List<Permission> permissions) async {
    Map<Permission, PermissionStatus> statuses = {};
    try {
      for (var permission in permissions) {
        statuses[permission] = await permission.status;
      }
    } catch (e) {
      debugPrint('<Error> 检查多个权限状态发生错误: $e');
    }
    return statuses;
  }
  
  // 获取所有需要的权限状态
  Future<Map<String, bool>> getAllPermissionStatus() async {
    Map<String, bool> permissionStatus = {};
    
    try {
      // 通知权限
      permissionStatus['通知'] = await Permission.notification.isGranted;
      
      // 系统悬浮窗
      if(Platform.isAndroid) {
        permissionStatus['悬浮窗'] = await Permission.systemAlertWindow.isGranted;
      } else {
        permissionStatus['悬浮窗'] = true; // iOS不需要单独申请悬浮窗权限
      }
      
      // 震动权限
      permissionStatus['震动'] = true; // 基础震动不需要特殊权限
      
      // 闹钟权限
      if(Platform.isAndroid) {
        permissionStatus['闹钟'] = await Permission.scheduleExactAlarm.isGranted;
      } else {
        permissionStatus['闹钟'] = true; // iOS通过通知权限控制
      }
      
      return permissionStatus;
    } catch (e) {
      debugPrint('<Error> 获取权限状态发生错误: $e');
      // 返回默认值
      return {
        '通知': false,
        '悬浮窗': false,
        '震动': false,
        '闹钟': false,
      };
    }
  }
  
  // 显示通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool useHighImportance = false,
  }) async {
    if (!_isInitialized) {
      debugPrint('<Warn> 通知服务未初始化，尝试初始化...');
      await initNotifications();
    }
    
    try {
      // 根据重要性创建Android通知细节
      final androidDetails = AndroidNotificationDetails(
        'alarm_channel',
        'Alarm Notifications',
        channelDescription: 'Channel for Alarm notifications',
        importance: useHighImportance ? Importance.max : Importance.high,
        priority: useHighImportance ? Priority.max : Priority.high,
        showWhen: true,
        enableLights: true,
        color: Colors.red,
        ledColor: Colors.red,
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: '新通知',
        styleInformation: BigTextStyleInformation(body),
      );
      
      // iOS通知细节
      const iOSDetails = DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.active,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );
      
      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      debugPrint('<Info> 通知已发送: $title');
    } catch (e) {
      debugPrint('<Error> 显示通知出错: $e');
    }
  }
  
  // 播放系统声音（通过通知实现提示音）
  Future<void> playAlarmSound() async {
    try {
      // 使用重要性较高的通知播放声音
      await showNotification(
        id: 888,
        title: '提示音测试',
        body: '这是一个提示音测试，确认您是否能听到系统提示音。如果您听不到，请检查设备的音量设置和通知权限。',
        payload: 'alarm_sound_test',
        useHighImportance: true,
      );
      
      debugPrint('<Info> 提示音已播放');
    } catch (e) {
      debugPrint('<Error> 播放提示音出错: $e');
    }
  }
  
  // 触发设备震动
  Future<void> vibrate() async {
    try {
      // 基本震动不需要特殊权限
      // 创建一个带有震动模式的通知
      final androidDetails = AndroidNotificationDetails(
        'vibration_channel',
        'Vibration Notifications',
        channelDescription: 'Channel for vibration tests',
        importance: Importance.low,
        priority: Priority.low,
        enableVibration: true,
        playSound: false,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
        styleInformation: const BigTextStyleInformation(
          '此消息应该只触发震动，不会播放声音。如果您感觉不到震动，请检查设备的震动设置是否已开启。',
        ),
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentSound: false,
          presentAlert: true,
          presentBadge: false,
        ),
      );
      
      await flutterLocalNotificationsPlugin.show(
        999,
        '震动测试',
        '正在测试设备震动...',
        notificationDetails,
        payload: 'vibration_test',
      );
      
      debugPrint('<Info> 震动已触发');
    } catch (e) {
      debugPrint('<Error> 触发震动出错: $e');
    }
  }
  
  // 显示系统悬浮窗 (悬浮通知/横幅)
  Future<void> showSystemOverlay() async {
    try {
      // 在Android上，使用高优先级通知以确保显示为横幅
      // 在iOS上，通知会自动显示为横幅
      
      final androidDetails = AndroidNotificationDetails(
        'overlay_channel',
        'Overlay Notifications',
        channelDescription: 'Channel for overlay tests',
        importance: Importance.max,
        priority: Priority.max,
        enableLights: true,
        fullScreenIntent: true, // 尝试以全屏意图显示
        showWhen: true,
        styleInformation: const BigTextStyleInformation(
          '这是一条悬浮通知测试，应该以横幅形式显示在屏幕顶部。如果没有显示，请检查应用的通知设置。',
        ),
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          interruptionLevel: InterruptionLevel.timeSensitive, // 时间敏感的打断级别
        ),
      );
      
      await flutterLocalNotificationsPlugin.show(
        777,
        '悬浮窗测试',
        '这是一个系统悬浮窗测试，您应该能看到一个通知横幅。',
        notificationDetails,
        payload: 'overlay_test',
      );
      
      debugPrint('<Info> 悬浮通知已发送');
    } catch (e) {
      debugPrint('<Error> 显示悬浮窗出错: $e');
    }
  }
} 