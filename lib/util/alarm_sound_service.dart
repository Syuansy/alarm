// 条件导入：只在Web平台导入dart:html
import 'alarm_sound_service_stub.dart'
    if (dart.library.html) 'alarm_sound_service_web.dart';

/// 报警提示音管理服务
/// 专门负责在web端播放系统提示音，移动端提供空实现
abstract class AlarmSoundService {
  static AlarmSoundService? _instance;
  
  /// 工厂构造函数，根据平台返回对应实现
  factory AlarmSoundService() {
    _instance ??= createAlarmSoundService();
    return _instance!;
  }

  /// 初始化音频服务
  void initialize();

  /// 播放报警提示音
  void playAlarmSound({String? alarmLevel});

  /// 启用/禁用提示音
  void setEnabled(bool enabled);

  /// 检查是否启用
  bool get isEnabled;

  /// 检查是否已初始化
  bool get isInitialized;

  /// 测试播放提示音
  void testSound({String? level});

  /// 释放资源
  void dispose();
}