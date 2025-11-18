import 'package:flutter/material.dart';
import 'package:alarm_front/util/permission_service.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';

class AlarmManager {
  static final AlarmManager _instance = AlarmManager._internal();
  factory AlarmManager() => _instance;
  AlarmManager._internal();
  
  final PermissionService _permissionService = PermissionService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // 初始化
  Future<void> initialize() async {
    await _permissionService.initNotifications();
  }
  
  // 只播放铃声，不显示通知UI
  // volume: 音量大小，范围0.0-1.0
  // duration: 持续时间，单位为秒
  Future<void> playRingtone({double volume = 1.0, int duration = 5}) async {
    try {
      // 创建只有声音没有视觉通知的配置
      if (Platform.isAndroid) {
        final androidDetails = AndroidNotificationDetails(
          'ringtone_channel',
          'Ringtone Channel',
          channelDescription: 'Channel for ringtone only',
          playSound: true,
          enableLights: false,
          enableVibration: false, // 不震动
          importance: Importance.low, // 低重要性防止显示UI
          priority: Priority.low,
          visibility: NotificationVisibility.secret, // 隐藏通知
          showWhen: false,
          ongoing: false,
          autoCancel: true,
          channelShowBadge: false,
          // 指定声音为系统铃声
          sound: const RawResourceAndroidNotificationSound('alarm'),
        );
        
        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentSound: true,
            presentAlert: false, // 不显示警告
            presentBadge: false, // 不显示角标
            sound: 'alarm.caf', // iOS铃声文件名
          ),
        );
        
        await _notificationsPlugin.show(
          2001,
          '', // 空标题
          '', // 空内容
          notificationDetails,
        );
      } else {
        // iOS上可以直接使用PermissionService的方法，但确保只有声音
        await _permissionService.showNotification(
          id: 2001,
          title: '',
          body: '',
          payload: 'ringtone_only',
          useHighImportance: true,
        );
      }
      
      debugPrint('<Info> 仅铃声播放中，音量: $volume');
      
      // 如果需要定时停止铃声，可以添加延时后取消通知
      if (duration > 0) {
        await Future.delayed(Duration(seconds: duration));
        await _notificationsPlugin.cancel(2001);
      }
    } catch (e) {
      debugPrint('<Error> 播放铃声出错: $e');
      rethrow;
    }
  }
  
  // 只触发震动，不显示通知UI或播放声音
  // pattern: 震动模式，如果为null则使用默认模式
  // intensity: 震动强度，范围0.0-1.0
  Future<void> vibrate({List<int>? pattern, double intensity = 1.0}) async {
    try {
      if (Platform.isAndroid) {
        final androidDetails = AndroidNotificationDetails(
          'vibration_channel',
          'Vibration Channel',
          channelDescription: 'Channel for vibration only',
          playSound: false, // 不播放声音
          enableLights: false, // 不显示灯光
          enableVibration: true, // 启用震动
          importance: Importance.low, // 低重要性防止显示UI
          priority: Priority.low,
          visibility: NotificationVisibility.secret, // 隐藏通知
          showWhen: false,
          ongoing: false,
          autoCancel: true,
          channelShowBadge: false,
          vibrationPattern: pattern != null ? Int64List.fromList(pattern) : Int64List.fromList([0, 500, 200, 500]),
        );
        
        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentSound: false, // 不播放声音
            presentAlert: false, // 不显示警告
            presentBadge: false, // 不显示角标
          ),
        );
        
        await _notificationsPlugin.show(
          2002,
          '', // 空标题
          '', // 空内容
          notificationDetails,
        );
        
        // 短暂震动后自动取消通知
        await Future.delayed(const Duration(milliseconds: 1500));
        await _notificationsPlugin.cancel(2002);
      } else {
        // iOS需要不同的实现方式
        // 这里使用通知系统，但确保只有震动
        final iOSDetails = const DarwinNotificationDetails(
          presentSound: false, // 不播放声音
          presentAlert: false, // 不显示警告
          presentBadge: false, // 不显示角标
        );
        
        final notificationDetails = NotificationDetails(
          iOS: iOSDetails,
        );
        
        await _notificationsPlugin.show(
          2002,
          '', // 空标题
          '', // 空内容
          notificationDetails,
        );
        
        // 短暂震动后自动取消通知
        await Future.delayed(const Duration(milliseconds: 1500));
        await _notificationsPlugin.cancel(2002);
      }
      
      debugPrint('<Info> 仅设备震动，强度: $intensity');
    } catch (e) {
      debugPrint('<Error> 触发震动出错: $e');
      rethrow;
    }
  }
  
  // 只显示弹窗，不播放声音或震动
  // title: 弹窗标题
  // message: 弹窗内容
  // fullScreen: 是否使用全屏模式
  Future<void> showPopup({
    required String title, 
    required String message,
    bool fullScreen = false,
  }) async {
    try {
      // 创建只有视觉通知没有声音和震动的配置
      final androidDetails = AndroidNotificationDetails(
        'popup_channel',
        'Popup Channel',
        channelDescription: 'Channel for popup only',
        playSound: false, // 不播放声音
        enableLights: false, // 不显示灯光
        enableVibration: false, // 不震动
        importance: Importance.max, // 高重要性确保显示UI
        priority: Priority.max,
        fullScreenIntent: fullScreen, // 全屏意图
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentSound: false, // 不播放声音
          presentAlert: true, // 仅显示警告
          presentBadge: false, // 不显示角标
        ),
      );
      
      await _notificationsPlugin.show(
        2003,
        title,
        message,
        notificationDetails,
      );
      
      debugPrint('<Info> 仅显示弹窗: $title, 全屏模式: $fullScreen');
    } catch (e) {
      debugPrint('<Error> 显示弹窗出错: $e');
      rethrow;
    }
  }
  
  // 组合功能：同时触发铃声、震动和弹窗
  Future<void> triggerFullAlarm({
    required String title,
    required String message,
  }) async {
    try {
      // 同时触发所有提醒方式
      await Future.wait([
        playRingtone(),
        vibrate(),
        showPopup(title: title, message: message, fullScreen: true),
      ]);
      
      debugPrint('<Info> 触发全部提醒: $title');
    } catch (e) {
      debugPrint('<Error> 触发全部提醒出错: $e');
      rethrow;
    }
  }
} 