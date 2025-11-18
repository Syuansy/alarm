import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alarm_front/presentation/widgets/alarm_toast.dart';
import 'package:alarm_front/util/shared_data_service.dart';
import 'package:alarm_front/util/alarm_sound_service.dart';

/// 报警提示框管理服务
class AlarmToastService {
  static final AlarmToastService _instance = AlarmToastService._internal();
  factory AlarmToastService() => _instance;
  AlarmToastService._internal();

  bool _isInitialized = false;
  BuildContext? _context;
  final List<OverlayEntry> _activeToasts = [];

  /// 初始化服务
  void initialize(BuildContext context) {
    if (_isInitialized || !kIsWeb) return;
    
    _context = context;
    
    // 初始化音频服务
    AlarmSoundService().initialize();
    
    // 监听报警消息
    SharedDataService().addAlarmListener(_handleAlarmMessage);
    _isInitialized = true;
    
    debugPrint('<Info> AlarmToastService 初始化成功');
  }

  /// 处理报警消息
  void _handleAlarmMessage(Map<String, dynamic> alarmMessage) {
    if (alarmMessage['type'] == 'alarm' && _context != null) {
      final data = alarmMessage['data'] as Map<String, dynamic>?;
      
      String message = '收到新的报警消息';
      String alarmLevel = '';
      
      if (data != null) {
        // 提取报警信息构建消息
        String alarmSource = data['alarm_source']?.toString() ?? '';
        alarmLevel = data['alarm_level']?.toString() ?? '';
        String alarmType = data['alarm_type']?.toString() ?? '';
        String content = data['content']?.toString() ?? '';
        
        // 优先显示报警内容
        if (content.isNotEmpty) {
          message = content;
        } else if (alarmType.isNotEmpty) {
          // 如果没有内容，显示报警类型和级别
          message = alarmLevel.isNotEmpty 
              ? '[$alarmLevel] $alarmType' 
              : alarmType;
        } else if (alarmLevel.isNotEmpty) {
          message = '级别$alarmLevel报警';
        }
        
        // 在调试信息中显示完整信息
        debugPrint('<Info> 显示报警提示框: $message (来源: $alarmSource, 类型: $alarmType, 级别: $alarmLevel)');
      }
      
      // 播放报警提示音
      AlarmSoundService().playAlarmSound(alarmLevel: alarmLevel);
      
      // 显示提示框
      _showToast(message);
    }
  }

  /// 显示提示框
  void _showToast(String message) {
    if (_context == null) return;

    final overlay = Overlay.of(_context!);
    
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        // bottom: 20 + (_activeToasts.length * 120.0), // 堆叠显示
        bottom: 20, // 堆叠显示
        child: Material(
          color: Colors.transparent,
          child: AlarmToast(
            message: message,
            onClose: () {
              overlayEntry.remove();
              _activeToasts.remove(overlayEntry);
              _updateToastPositions();
            },
          ),
        ),
      ),
    );

    _activeToasts.add(overlayEntry);
    overlay.insert(overlayEntry);

    // 限制最多显示5个提示框
    if (_activeToasts.length > 5) {
      final oldestToast = _activeToasts.removeAt(0);
      oldestToast.remove();
      _updateToastPositions();
    }
  }

  /// 更新所有提示框位置
  void _updateToastPositions() {
    for (int i = 0; i < _activeToasts.length; i++) {
      _activeToasts[i].markNeedsBuild();
    }
  }

  /// 清除所有提示框
  void clearAllToasts() {
    for (final toast in _activeToasts) {
      toast.remove();
    }
    _activeToasts.clear();
    debugPrint('<Info> 清除所有报警提示框');
  }

  /// 启用/禁用报警提示音
  void setSoundEnabled(bool enabled) {
    AlarmSoundService().setEnabled(enabled);
    debugPrint('<Info> 报警提示音${enabled ? '已启用' : '已禁用'}');
  }

  /// 检查提示音是否启用
  bool get isSoundEnabled => AlarmSoundService().isEnabled;

  /// 测试播放提示音
  void testAlarmSound({String? level = '3'}) {
    AlarmSoundService().testSound(level: level);
  }

  /// 释放资源
  void dispose() {
    if (_isInitialized) {
      clearAllToasts();
      SharedDataService().removeAlarmListener(_handleAlarmMessage);
      
      // 释放音频服务资源
      AlarmSoundService().dispose();
      
      _isInitialized = false;
      _context = null;
    }
  }
}