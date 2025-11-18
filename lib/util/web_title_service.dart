import 'package:flutter/foundation.dart';
import 'package:alarm_front/util/shared_data_service.dart';

// 条件导入：Web平台使用html实现，其他平台使用stub实现
import 'web_title_service_stub.dart' if (dart.library.html) 'web_title_service_web.dart';

/// 跨平台页面标题管理服务
class WebTitleService {
  static final WebTitleService _instance = WebTitleService._internal();
  factory WebTitleService() => _instance;
  WebTitleService._internal();

  static const String _baseTitle = 'JUNOMonitor';
  int _alarmCount = 0;
  bool _isInitialized = false;
  
  // 平台特定的标题更新实现
  final PlatformTitleUpdater _titleUpdater = PlatformTitleUpdater();

  /// 初始化服务
  void initialize() {
    if (_isInitialized) return;
    
    // 只在Web平台监听报警消息
    if (kIsWeb) {
      SharedDataService().addAlarmListener(_handleAlarmMessage);
      debugPrint('<Info> WebTitleService 初始化成功 (Web平台)');
    } else {
      debugPrint('<Info> WebTitleService 跳过初始化 (非Web平台)');
    }
    
    _isInitialized = true;
  }

  /// 处理报警消息
  void _handleAlarmMessage(Map<String, dynamic> alarmMessage) {
    if (alarmMessage['type'] == 'alarm') {
      _alarmCount++;
      _updateTitle();
      debugPrint('<Info> 报警计数更新: $_alarmCount');
    }
  }

  /// 更新浏览器标题
  void _updateTitle() {
    if (!kIsWeb) return;
    
    try {
      final title = _alarmCount > 0 
        ? '$_baseTitle - ${_alarmCount}条Alarm'
        : _baseTitle;
      _titleUpdater.updateTitle(title);
    } catch (e) {
      debugPrint('<Error> 更新标题失败: $e');
    }
  }

  /// 清除报警计数
  void clearAlarmCount() {
    _alarmCount = 0;
    _updateTitle();
    debugPrint('<Info> 报警计数已清除');
  }

  /// 获取当前报警数量
  int get alarmCount => _alarmCount;

  /// 释放资源
  void dispose() {
    if (_isInitialized) {
      SharedDataService().removeAlarmListener(_handleAlarmMessage);
      _isInitialized = false;
    }
  }
}