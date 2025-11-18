import 'dart:convert';
import 'package:flutter/services.dart';

/// 应用统一配置管理类
/// 
/// 从 app_config.json 文件读取配置，提供全局访问接口
class AppConfig {
  // 单例实例
  static final AppConfig _instance = AppConfig._internal();
  
  // 工厂构造函数返回单例实例
  factory AppConfig() {
    return _instance;
  }
  
  // 私有构造函数
  AppConfig._internal();
  
  // 配置数据
  late Map<String, dynamic> _config;
  
  // 是否已加载
  bool _isLoaded = false;
  
  /// 加载配置文件
  Future<void> load() async {
    if (_isLoaded) return;
    
    try {
      final configStr = await rootBundle.loadString('lib/config/app_config.json');
      _config = jsonDecode(configStr);
      _isLoaded = true;
      print('<Info> 应用配置加载成功');
    } catch (e) {
      print('<Error> 加载应用配置失败: $e');
      // 使用默认配置
      _config = _getDefaultConfig();
      _isLoaded = true;
    }
  }
  
  /// 获取默认配置（当配置文件加载失败时使用）
  Map<String, dynamic> _getDefaultConfig() {
    return {
      'app': {
        'name': 'JUNOMonitor',
        'description': 'JUNOMonitor is a Jiangmen neutrino monitoring software.',
      },
      'backend': {
        'baseUrl': 'http://10.3.192.122:8001',
        'alarmApiBase': 'http://10.3.192.122:8001/api/alarm',
        'alarmHistoryUrl': 'http://10.3.192.122:8001/api/alarm/history',
        'llmHistoryUrl': 'http://10.3.192.122:8001/api/alarm/llm/history',
        'dashboardUploadUrl': 'http://10.3.192.122:8001/api/dashboard/upload',
        'dashboardStatusUrl': 'http://10.3.192.122:8001/api/dashboard/status',
        'grafanaBaseUrl': 'http://10.3.192.122:3000',
      },
      'websocket': {
        'url': 'ws://10.3.192.122:8001/ws',
      },
    };
  }
  
  // ==================== 应用基础配置 ====================
  
  /// 应用名称
  String get appName => _config['app']['name'] ?? 'JUNOMonitor';
  
  /// 应用描述
  String get appDescription => _config['app']['description'] ?? 'JUNOMonitor is a Jiangmen neutrino monitoring software.';
  
  /// 应用版本
  String get appVersion => _config['app']['version'] ?? '1.1.5';
  
  /// 构建号
  String get buildNumber => _config['app']['buildNumber'] ?? '10105';
  
  // ==================== 后端服务配置 ====================
  
  /// 后端 API 基础地址
  String get backendUrl => _config['backend']['baseUrl'] ?? 'http://10.3.192.122:8001';
  
  /// 报警 API 基础地址
  String get alarmApiBase => _config['backend']['alarmApiBase'] ?? 'http://10.3.192.122:8001/api/alarm';
  
  /// 报警历史 API 完整 URL
  String get alarmHistoryUrl => _config['backend']['alarmHistoryUrl'] ?? 'http://10.3.192.122:8001/api/alarm/history';
  
  /// LLM 历史 API 完整 URL
  String get llmHistoryUrl => _config['backend']['llmHistoryUrl'] ?? 'http://10.3.192.122:8001/api/alarm/llm/history';
  
  /// 仪表盘上传 API 完整 URL
  String get dashboardUploadUrl => _config['backend']['dashboardUploadUrl'] ?? 'http://10.3.192.122:8001/api/dashboard/upload';
  
  /// 仪表盘状态 API 完整 URL
  String get dashboardStatusUrl => _config['backend']['dashboardStatusUrl'] ?? 'http://10.3.192.122:8001/api/dashboard/status';
  
  // ==================== WebSocket 配置 ====================
  
  /// WebSocket 连接地址
  String get websocketUrl => _config['websocket']['url'] ?? 'ws://10.3.192.122:8001/ws';
  
  /// 心跳间隔（秒）
  int get heartbeatInterval => _config['websocket']['heartbeatInterval'] ?? 30;
  
  /// 心跳超时（秒）
  int get heartbeatTimeout => _config['websocket']['heartbeatTimeout'] ?? 60;
  
  /// 最大重连次数
  int get maxReconnectAttempts => _config['websocket']['maxReconnectAttempts'] ?? 5;
  
  // ==================== Grafana 配置 ====================
  
  /// Grafana 基础地址
  String get grafanaBaseUrl => _config['backend']['grafanaBaseUrl'] ?? 'http://10.3.192.122:3000';
  
  // ==================== 平台配置 ====================
  
  /// Web 标题
  String get webTitle => _config['platform']['web']['title'] ?? appName;
  
  /// Android 应用名称
  String get androidAppName => _config['platform']['android']['appName'] ?? appName;
  
  /// Android 包名
  String get androidPackageName => _config['platform']['android']['packageName'] ?? 'dev.flchart.app';
  
  /// iOS 应用名称
  String get iosAppName => _config['platform']['ios']['appName'] ?? appName;
  
  /// iOS Bundle ID
  String get iosBundleId => _config['platform']['ios']['bundleId'] ?? 'dev.flchart.app';
  
  /// Flutter 项目名称
  String get flutterProjectName => _config['platform']['flutter']['projectName'] ?? 'alarm_front';
  
  // ==================== 工具方法 ====================
  
  /// 打印当前配置信息（用于调试）
  void printConfig() {
    print('========== 应用配置信息 ==========');
    print('应用名称: $appName');
    print('后端地址: $backendUrl');
    print('WebSocket: $websocketUrl');
    print('Grafana: $grafanaBaseUrl');
    print('================================');
  }
  
  /// 获取原始配置对象
  Map<String, dynamic> get rawConfig => Map.from(_config);
}
