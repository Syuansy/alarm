import 'package:flutter/foundation.dart';
import 'alarm_sound_service.dart';

/// 移动端空实现 - 不提供音频功能
class AlarmSoundServiceImpl implements AlarmSoundService {
  bool _isEnabled = true;
  bool _isInitialized = false;

  /// 初始化音频服务（空实现）
  @override
  void initialize() {
    _isInitialized = true;
    debugPrint('<Info> AlarmSoundService 移动端空实现已初始化');
  }

  /// 播放报警提示音（空实现）
  @override
  void playAlarmSound({String? alarmLevel}) {
    debugPrint('<Info> 移动端不支持音频播放，忽略报警提示音请求');
  }

  /// 启用/禁用提示音
  @override
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('<Info> 移动端报警提示音${enabled ? '已启用' : '已禁用'}（无实际效果）');
  }

  /// 检查是否启用
  @override
  bool get isEnabled => _isEnabled;

  /// 检查是否已初始化
  @override
  bool get isInitialized => _isInitialized;

  /// 测试播放提示音（空实现）
  @override
  void testSound({String? level}) {
    debugPrint('<Info> 移动端不支持音频播放，无法测试提示音');
  }

  /// 释放资源（空实现）
  @override
  void dispose() {
    _isInitialized = false;
    debugPrint('<Info> AlarmSoundService 移动端空实现已释放资源');
  }
}

/// 创建平台特定的实现
AlarmSoundService createAlarmSoundService() => AlarmSoundServiceImpl();