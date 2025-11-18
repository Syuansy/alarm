import 'dart:convert';
import 'package:alarm_front/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:math' as math;

/// WebSocket管理器单例类
/// 
/// 用于管理全局WebSocket连接，确保多个控件共享同一个连接
class WebSocketManager {
  // 单例实例
  static final WebSocketManager _instance = WebSocketManager._internal();
  
  // 工厂构造函数返回单例实例
  factory WebSocketManager() {
    return _instance;
  }
  
  // 私有构造函数
  WebSocketManager._internal();
  
  // WebSocket连接对象
  WebSocketChannel? _channel;
  
  // WebSocket连接URL - 从 AppConfig 读取
  String get webSocketUrl => AppConfig().websocketUrl;
  
  // 存储所有监听器
  final Set<Function(Map<String, dynamic>)> _listeners = {};
  
  // 连接状态
  String _connectionStatus = '连接中...';
  String get connectionStatus => _connectionStatus;
  
  // 获取WebSocket连接
  WebSocketChannel? get channel => _channel;
  
  // 所有图表的数据缓存，key是图表的key，value是图表的数据
  final Map<String, Map<String, dynamic>> _chartDataCache = {};
  
  // 心跳定时器
  Timer? _heartbeatTimer;
  
  // 重连次数
  int _reconnectAttempts = 0;
  
  // 最大重连次数 - 从 AppConfig 读取
  int get _maxReconnectAttempts => AppConfig().maxReconnectAttempts;
  
  // 心跳间隔（秒）- 从 AppConfig 读取
  int get _heartbeatInterval => AppConfig().heartbeatInterval;
  
  // 心跳超时（秒）- 从 AppConfig 读取
  int get _heartbeatTimeout => AppConfig().heartbeatTimeout;
  
  // 上次收到pong的时间
  int _lastPongTime = 0;
  
  // 添加监听器
  void addListener(Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
    
    // 如果还没有WebSocket连接，则创建一个
    if (_channel == null) {
      connectWebSocket();
    }
  }
  
  // 移除监听器
  void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
    
    // 如果没有监听器了，但仍保持连接以继续收集数据
    // 不再断开连接: if (_listeners.isEmpty) { disconnectWebSocket(); }
  }
  
  // 获取图表数据缓存
  Map<String, dynamic>? getChartDataCache(String chartKey) {
    return _chartDataCache[chartKey];
  }
  
  // 获取所有缓存的数据
  Map<String, Map<String, dynamic>> getAllChartDataCache() {
    return Map.from(_chartDataCache);
  }
  
  // 根据正则表达式模式获取匹配的缓存数据
  Map<String, Map<String, dynamic>> getChartDataCacheByPattern(RegExp pattern) {
    final Map<String, Map<String, dynamic>> result = {};
    _chartDataCache.forEach((key, value) {
      if (pattern.hasMatch(key)) {
        result[key] = value;
      }
    });
    return result;
  }
  
  // 启动后台数据收集
  void startBackgroundDataCollection() {
    // 确保连接已建立
    if (_channel == null) {
      connectWebSocket();
    }
  }
  
  // 建立WebSocket连接
  void connectWebSocket() {
    if (_channel != null) {
      // 已经有连接了，不需要重新连接
      return;
    }
    
    try {
      // 连接到WebSocket服务器
      _channel = WebSocketChannel.connect(
        Uri.parse(webSocketUrl),
      );

      // 监听WebSocket消息
      _channel!.stream.listen(
        (dynamic message) {
          try {
            // 处理心跳响应
            if (message == "pong") {
              _lastPongTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              _connectionStatus = '已连接';
              _reconnectAttempts = 0;  // 重置重连计数器
              return;
            }
            
            // 预处理JSON字符串，将NaN替换为字符串"NaN"
            String jsonStr = message.toString();
            if (jsonStr.contains('NaN')) {
              jsonStr = jsonStr.replaceAll('"value":NaN', '"value":"NaN"');
            }
            
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            
            // 确保消息至少有type字段
            if (!data.containsKey('type')) {
              print('<Error> 消息缺少type字段: $data');
              return;
            }
            
            // 只处理monitor_data类型消息，并且必须包含data字段
            if (data['type'] == 'monitor_data' && data.containsKey('data')) {
              final messageData = data['data'];
              if (messageData is List) {
                // 批量消息处理
                for (var item in messageData) {
                  if (item is Map<String, dynamic> && item.containsKey('key')) {
                    final key = item['key'] as String;
                    
                    // 为每个item创建完整消息并缓存
                    final singleMessage = {
                      'type': 'monitor_data',
                      'data': item,
                    };
                    
                    _chartDataCache[key] = singleMessage;
                  }
                }
                
                // 为每条数据分别通知监听器 - 支持图表等需要单独处理每条数据的组件
                for (var item in messageData) {
                  if (item is Map<String, dynamic> && item.containsKey('key')) {
                    final singleItemMessage = {
                      'type': 'monitor_data',
                      'data': item,
                    };
                    
                    // 单独通知每一条数据
                    for (final listener in _listeners) {
                      try {
                        listener(singleItemMessage);
                      } catch (e) {
                        print('<Error> 监听器处理单条数据异常: $e');
                      }
                    }
                  }
                }
                
                // 不再调用通用监听器通知，因为已经单独通知了每一条数据
                return;
              } else if (messageData is Map<String, dynamic>) {
                // 单条消息处理
                if (messageData.containsKey('key')) {
                  final key = messageData['key'] as String;
                  _chartDataCache[key] = data;
                }
              }
            }
            
            // 通知所有监听器
            for (final listener in _listeners) {
              listener(data);
            }
          } catch (e) {
            print('<Error> 解析WebSocket消息失败: $e');
            print('<Info> 原始消息: $message');
          }
        },
        onError: (error) {
          print('<Error> WebSocket错误: $error');
          _connectionStatus = '连接错误';
          _heartbeatTimer?.cancel();
          reconnectWebSocket();
        },
        onDone: () {
          print('<Info> WebSocket连接已关闭');
          _connectionStatus = '连接已关闭';
          _heartbeatTimer?.cancel();
          reconnectWebSocket();
        },
      );

      _connectionStatus = '已连接';
      
      // 启动心跳机制
      startHeartbeat();
      
      // 重置重连尝试次数
      _reconnectAttempts = 0;
    } catch (e) {
      print('<Error> WebSocket连接失败: $e');
      _connectionStatus = '连接失败';
      reconnectWebSocket();
    }
  }
  
  // 开始心跳机制
  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _lastPongTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    _heartbeatTimer = Timer.periodic(Duration(seconds: _heartbeatInterval), (timer) {
      if (_channel != null) {
        try {
          // 发送简化的心跳包
          _channel!.sink.add("ping");
          
          // 检查心跳超时
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (now - _lastPongTime > _heartbeatTimeout) {  // 使用配置的超时时间
            print('<Warn> 心跳超时，重新连接...');
            _heartbeatTimer?.cancel();
            _channel?.sink.close();
            _channel = null;
            reconnectWebSocket();
          }
        } catch (e) {
          print('<Error> 发送心跳包失败: $e');
          reconnectWebSocket();
        }
      }
    });
  }
  
  // 重新连接WebSocket
  void reconnectWebSocket() {
    _connectionStatus = '正在重新连接...';
    
    // 清除现有连接
    _channel = null;
    
    // 使用指数退避策略
    if (_reconnectAttempts < _maxReconnectAttempts) {
      // 延迟时间随重试次数增加
      final delay = Duration(seconds: math.pow(2, _reconnectAttempts).toInt());
      _reconnectAttempts++;
      
      print('<Info> 尝试第$_reconnectAttempts次重连，延迟${delay.inSeconds}秒');
      Future.delayed(delay, () {
        connectWebSocket();
      });
    } else {
      _connectionStatus = '重连失败，已达最大重试次数';
      print('<Error> 重连失败，已达最大重试次数');
      
      // 最后一次尝试，延迟更长时间
      Future.delayed(const Duration(seconds: 60), () {
        _reconnectAttempts = 0;
        connectWebSocket();
      });
    }
  }
  
  // 断开WebSocket连接
  void disconnectWebSocket() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connectionStatus = '已断开连接';
  }
  
  // 资源释放
  void dispose() {
    _heartbeatTimer?.cancel();
    disconnectWebSocket();
  }
} 