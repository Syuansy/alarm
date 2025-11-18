import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:alarm_front/config/app_config.dart';

// 全局图表数据管理器
class ChartDataManager {
  // 单例实例
  static final ChartDataManager _instance = ChartDataManager._internal();
  
  // 工厂构造函数
  factory ChartDataManager() => _instance;
  
  // 私有构造函数
  ChartDataManager._internal();
  
  // 获取当前WebSocket URL（从配置读取）
  String get _currentWebSocketUrl => AppConfig().websocketUrl;
  
  // 重连计数器和最大重试次数
  int _reconnectCount = 0;
  static const int _maxReconnectAttempts = 10;
  
  // 连接超时时间
  static const Duration _connectionTimeout = Duration(seconds: 10);
  
  // 心跳计时器
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  
  // 是否正在进行重连
  bool _isReconnecting = false;
  
  // 最近一次连接尝试的时间戳，用于防抖动
  DateTime _lastConnectionAttempt = DateTime.now().subtract(const Duration(minutes: 1));
  
  // WebSocket连接对象
  WebSocketChannel? _channel;
  
  // 数据存储，按图表key分组
  final Map<String, Map<String, dynamic>> _chartDataMap = {};
  
  // 添加图表配置属性
  final Map<String, int> _chartIntervals = {};
  
  // 提供公共访问接口，暴露内部数据结构
  Map<String, List<(DateTime, double)>> get dataHistoryByKey {
    // 如果有监听器，返回当前正在处理的图表数据
    if (_listeners.isNotEmpty) {
      // 选择第一个图表的数据返回
      final firstKey = _listeners.keys.first;
      final chartData = _chartDataMap[firstKey];
      if (chartData != null) {
        return chartData['dataPoints'] as Map<String, List<(DateTime, double)>>;
      }
    }
    // 如果没有数据，返回空映射
    return {};
  }
  
  // 注册的监听器，按图表key分组
  final Map<String, Set<Function(Map<String, dynamic>)>> _listeners = {};
  
  // 连接状态
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  // 自动刷新状态
  bool _isAutoRefreshEnabled = false;
  bool get isAutoRefreshEnabled => _isAutoRefreshEnabled;
  set isAutoRefreshEnabled(bool value) {
    _isAutoRefreshEnabled = value;
    // 通知所有监听器
    for (final listeners in _listeners.values) {
      for (final listener in listeners) {
        if (_chartDataMap.containsKey(_getChartKeyFromListener(listener))) {
          listener(_chartDataMap[_getChartKeyFromListener(listener)]!);
        }
      }
    }
  }
  
  // 从监听器回调中获取图表键值的辅助方法
  String _getChartKeyFromListener(Function listener) {
    for (final entry in _listeners.entries) {
      if (entry.value.contains(listener)) {
        return entry.key;
      }
    }
    return '';
  }
  
  // 数据筛选规则
  static RegExp keyPattern = RegExp(r'^top-PMT-dcr\.VME[^.]+\.triggerRate$');
  
  // 初始化并连接WebSocket
  Future<void> initialize() async {
    if (_channel == null && !_isReconnecting) {
      await _connectWebSocket();
    }
  }
  
  // 获取某个图表的最新数据
  Map<String, dynamic>? getDataForChart(String chartKey) {
    return _chartDataMap[chartKey];
  }
  
  // 设置图表的更新间隔
  void setChartInterval(String chartKey, int intervalSeconds) {
    _chartIntervals[chartKey] = intervalSeconds;
    print('<Info> 设置图表[$chartKey]的更新间隔为$intervalSeconds秒');
  }
  
  // 获取图表的更新间隔
  int getChartInterval(String chartKey) {
    return _chartIntervals[chartKey] ?? 3; // 默认3秒
  }
  
  // 添加数据监听器
  void addListener(String chartKey, Function(Map<String, dynamic>) listener) {
    if (!_listeners.containsKey(chartKey)) {
      _listeners[chartKey] = {};
    }
    _listeners[chartKey]!.add(listener);
    
    // 确保WebSocket已连接
    initialize();
    
    // 如果已有数据，立即通知
    if (_chartDataMap.containsKey(chartKey)) {
      listener(_chartDataMap[chartKey]!);
    }
  }
  
  // 移除数据监听器
  void removeListener(String chartKey, Function(Map<String, dynamic>) listener) {
    if (_listeners.containsKey(chartKey)) {
      _listeners[chartKey]!.remove(listener);
      
      // 如果该图表没有更多监听器，可以清理数据
      if (_listeners[chartKey]!.isEmpty) {
        _listeners.remove(chartKey);
      }
    }
  }
  
  // 连接WebSocket
  Future<void> _connectWebSocket() async {
    // 防抖动：如果距离上次连接尝试不到2秒，则忽略
    final now = DateTime.now();
    if (now.difference(_lastConnectionAttempt).inSeconds < 2) {
      print('<Warn> 连接请求过于频繁，忽略当前请求');
      return;
    }
    _lastConnectionAttempt = now;
    
    // 如果已经在重连中，忽略重复请求
    if (_isReconnecting) {
      print('<Warn> 已经有重连任务在进行中，忽略当前请求');
      return;
    }
    
    _isReconnecting = true;
    
    try {
      if (_reconnectCount >= _maxReconnectAttempts) {
        print('<Error> 达到最大重连次数($_maxReconnectAttempts)，停止尝试连接');
        
        // 通知所有监听器连接已失败
        for (final chartKey in _listeners.keys) {
          if (_chartDataMap.containsKey(chartKey)) {
            _chartDataMap[chartKey]!['subtitle'] = '连接失败: 请检查网络并刷新页面';
            for (final listener in _listeners[chartKey]!) {
              listener(_chartDataMap[chartKey]!);
            }
          }
        }
        
        _isReconnecting = false;
        return;
      }
      
      // 确保之前的连接已关闭
      if (_channel != null) {
        try {
          await _channel!.sink.close();
        } catch (e) {
          print('<Error> 关闭之前的连接时出错: $e');
        }
        _channel = null;
      }
      
      // 获取当前要连接的URL
      final url = _currentWebSocketUrl;
      print('<Info> 正在连接WebSocket($url)...');
      _isConnected = false;
      
      // 更新所有图表的副标题为"正在连接..."
      for (final chartKey in _listeners.keys) {
        if (_chartDataMap.containsKey(chartKey)) {
          _chartDataMap[chartKey]!['subtitle'] = '正在连接...';
          for (final listener in _listeners[chartKey]!) {
            listener(_chartDataMap[chartKey]!);
          }
        }
      }
      
      // 创建连接
      WebSocketChannel? newChannel;
      bool connectionSuccessful = false;
      
      try {
        // 创建WebSocket连接
        newChannel = WebSocketChannel.connect(Uri.parse(url));
        
        // 设置连接超时
        final completer = Completer<bool>();
        Timer? timeoutTimer;
        
        // 创建超时计时器
        timeoutTimer = Timer(_connectionTimeout, () {
          if (!completer.isCompleted) {
            print('<Warn> WebSocket连接超时: $url');
            completer.complete(false);
          }
        });
        
        // 监听第一条消息以确认连接成功
        StreamSubscription? initialSubscription;
        initialSubscription = newChannel.stream.listen(
          (data) {
            if (!completer.isCompleted) {
              print('<Info> 收到WebSocket数据，连接成功');
              completer.complete(true);
            }
            initialSubscription?.cancel();
          },
          onError: (error) {
            if (!completer.isCompleted) {
              print('<Error> WebSocket初始连接错误: $error');
              completer.complete(false);
            }
            initialSubscription?.cancel();
          },
          onDone: () {
            if (!completer.isCompleted) {
              print('<Info> WebSocket初始连接关闭');
              completer.complete(false);
            }
            initialSubscription?.cancel();
          },
        );
        
        // 尝试发送一个ping消息以测试连接
        try {
          // 使用与后端一致的格式发送ping消息
          newChannel.sink.add('{"type":"ping"}');
          print('<Info> 发送ping消息测试连接');
        } catch (e) {
          print('<Error> 发送ping消息失败: $e');
          // 不影响后续流程，仍等待接收数据或超时
        }
        
        // 等待连接完成或超时
        connectionSuccessful = await completer.future;
        timeoutTimer.cancel();
        
        if (!connectionSuccessful) {
          // 连接失败或超时，关闭通道
          try {
            await newChannel.sink.close();
          } catch (e) {
            print('<Error> 关闭失败的连接时出错: $e');
          }
          throw Exception('连接失败或超时');
        }
      } catch (e) {
        print('<Error> 创建或测试WebSocket连接时出错: $e');
        
        // 确保连接关闭
        if (newChannel != null) {
          try {
            await newChannel.sink.close();
          } catch (closeError) {
            print('<Error> 关闭失败的连接时出错: $closeError');
          }
        }
        
        throw e; // 重新抛出以便外层捕获
      }
      
      // 如果连接成功，设置主连接对象
      if (connectionSuccessful) {
        _channel = newChannel;
        _isConnected = true;
        print('<Info> WebSocket连接成功: $url');
        
        // 重置重连计数器
        _reconnectCount = 0;
        
        // 启动心跳
        _startHeartbeat();
        
        // 开始监听实际的消息
        _channel!.stream.listen(
          (dynamic message) {
            try {
              // 预处理JSON字符串，将NaN替换为字符串"NaN"
              String jsonStr = message.toString();
              if (jsonStr.contains('NaN')) {
                // 适配新的消息格式，NaN值现在在content.value中
                jsonStr = jsonStr.replaceAll('"value":NaN', '"value":"NaN"');
              }
              
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              
              // 直接传递消息给处理函数，所有类型的消息都在那里处理
              _handleWebSocketMessage(data);
            } catch (e) {
              print('<Error> 处理WebSocket消息出错: $e');
            }
          },
          onDone: () {
            print('<Info> WebSocket连接已关闭: $url');
            _isConnected = false;
            
            // 停止心跳
            _stopHeartbeat();
            
            // 关闭并置空channel
            try {
              _channel?.sink.close();
            } catch (e) {
              print('<Error> 关闭WebSocket连接时出错: $e');
            }
            _channel = null;
            
            // 尝试重新连接
            _isReconnecting = false;
            Future.delayed(const Duration(seconds: 3), () {
              print('<Info> 连接关闭，尝试重新连接...');
              _reconnectCount++;
              _connectWebSocket();
            });
          },
          onError: (error) {
            print('<Error> WebSocket连接错误: $error');
            _isConnected = false;
            
            // 停止心跳
            _stopHeartbeat();
            
            // 关闭并置空channel
            try {
              _channel?.sink.close();
            } catch (e) {
              print('<Error> 关闭WebSocket连接时出错: $e');
            }
            _channel = null;
            
            // 尝试重新连接
            _isReconnecting = false;
            Future.delayed(const Duration(seconds: 3), () {
              print('<Info> 连接错误，尝试重新连接...');
              _reconnectCount++;
              _connectWebSocket();
            });
          },
        );
      }
      
      _isReconnecting = false;
    } catch (e) {
      print('<Error> WebSocket连接失败: $e');
      _isConnected = false;
      
      // 确保关闭连接
      try {
        _channel?.sink.close();
      } catch (closeError) {
        print('<Error> 关闭WebSocket连接时出错: $closeError');
      }
      _channel = null;
      
      // 更新所有图表的副标题
      for (final chartKey in _listeners.keys) {
        if (_chartDataMap.containsKey(chartKey)) {
          _chartDataMap[chartKey]!['subtitle'] = '连接失败: 重试中...';
          for (final listener in _listeners[chartKey]!) {
            listener(_chartDataMap[chartKey]!);
          }
        }
      }
      
      // 尝试重新连接，增加延迟时间
      final delay = Duration(seconds: 3 + _reconnectCount);
      print('<Info> 将在$delay后重试连接');
      
      _isReconnecting = false;
      Future.delayed(delay, () {
        _reconnectCount++;
        _connectWebSocket();
      });
    }
  }
  
  // 处理WebSocket消息
  void _handleWebSocketMessage(Map<String, dynamic> data) {
    // 检查消息格式 - 只支持新格式 (type + data)
    if (!data.containsKey('type')) {
      print('<Error> 消息缺少type字段: $data');
      return;
    }
    
    // 根据消息类型进行处理
    final String messageType = data['type'] as String;
    
    switch (messageType) {
      case 'monitor_data':
        // 处理新格式消息
        if (data.containsKey('data')) {
          _handleMonitorData(data);
        } else {
          print('<Error> monitor_data消息缺少data字段: $data');
        }
        break;
      case 'run_data':
        // 可以添加处理run_data的逻辑，如果需要的话
        print('<Info> 收到run_data消息');
        break;
      case 'conn_status':
        // 可以添加处理conn_status的逻辑，如果需要的话
        print('<Info> 收到conn_status消息');
        break;
      case 'pong':
        // 心跳响应，不需要特殊处理
        print('<Info> 收到心跳响应');
        break;
      default:
        print('<Warn> 收到未知类型的消息: $messageType');
        break;
    }
  }
  
  // 处理监控数据消息
  void _handleMonitorData(Map<String, dynamic> data) {
    final messageData = data['data'];
    // 当前时间戳和格式化时间
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final formattedTime = DateTime.now().toString();
    
    if (messageData is List) {
      // 批量消息处理
      for (final item in messageData) {
        if (item is Map<String, dynamic>) {
          _processMonitorDataItem(item, timestamp, formattedTime);
        }
      }
    } else if (messageData is Map<String, dynamic>) {
      // 单条消息处理
      _processMonitorDataItem(messageData, timestamp, formattedTime);
    }
  }
  
  // 处理单条监控数据项
  void _processMonitorDataItem(Map<String, dynamic> content, int timestamp, String formattedTime) {
    final key = content['key'] as String;
    
    // 只处理匹配模式的key的数据
    if (!keyPattern.hasMatch(key)) {
      return;
    }
    
    // 解析value，可能是NaN
    final valueStr = content['value'].toString();
    double value;
    if (valueStr.toLowerCase() == 'nan') {
      value = double.nan;
    } else {
      value = double.tryParse(valueStr) ?? 0.0;
    }
    
    final status = content['status'] != null ? content['status'].toString() : 'Normal';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    
    // 为每个图表保存最新数据，考虑更新间隔
    for (final chartKey in _listeners.keys) {
      // 创建该图表的数据副本
      if (!_chartDataMap.containsKey(chartKey)) {
        _chartDataMap[chartKey] = {
          'dataPoints': <String, List<(DateTime, double)>>{},
          'lastUpdate': DateTime.now(),
          'subtitle': '连接中...'
        };
      }
      
      // 检查是否需要更新数据（基于更新间隔）
      final lastUpdate = _chartDataMap[chartKey]!['lastUpdate'] as DateTime;
      final interval = getChartInterval(chartKey);
      final now = DateTime.now();
      final shouldUpdate = now.difference(lastUpdate).inSeconds >= interval;
      
      // 如果未到更新时间，则跳过
      if (!shouldUpdate && _chartDataMap[chartKey]!['dataPoints'].containsKey(key)) {
        continue;
      }
      
      // 确保该key的数据列表已初始化
      if (!_chartDataMap[chartKey]!['dataPoints'].containsKey(key)) {
        _chartDataMap[chartKey]!['dataPoints'][key] = [];
      }
      
      // 添加新数据点
      _chartDataMap[chartKey]!['dataPoints'][key].add((dateTime, value));
      
      // 只保留最近10分钟内的数据
      final tenMinutesAgo = now.subtract(const Duration(minutes: 10));
      _chartDataMap[chartKey]!['dataPoints'][key] = _chartDataMap[chartKey]!['dataPoints'][key]
          .where((item) => item.$1.isAfter(tenMinutesAgo))
          .toList();
      
      // 更新最后更新时间和标题
      _chartDataMap[chartKey]!['lastUpdate'] = now;
      _chartDataMap[chartKey]!['subtitle'] = '最新数据: $formattedTime';
    }
    
    // 对每个chart都更新结束后，再通知所有监听器
    _notifyListeners();
  }
  
  // 通知所有监听器
  void _notifyListeners() {
    for (final chartKey in _listeners.keys) {
      if (_chartDataMap.containsKey(chartKey)) {
        for (final listener in _listeners[chartKey]!) {
          listener(_chartDataMap[chartKey]!);
        }
      }
    }
  }
  
  // 获取颜色
  Color getColorForKey(String key) {
    // 使用key的哈希码生成一个稳定的颜色
    // 使用黄金比例共轭(0.618033988749895)来生成分布更均匀的颜色
    final double goldenRatioConjugate = 0.618033988749895;
    double hue = (key.hashCode.abs() * goldenRatioConjugate) % 1.0;
    
    // 固定饱和度和亮度，只变化色调以获得鲜明的颜色
    return HSLColor.fromAHSL(
      1.0,           // 不透明度
      hue * 360,     // 色调(0-360)
      0.7,           // 饱和度(70%)
      0.6,           // 亮度(60%)
    ).toColor();
  }
  
  // 开始发送心跳
  void _startHeartbeat() {
    // 如果已经有计时器，先取消
    _heartbeatTimer?.cancel();
    
    // 创建新的计时器，定期发送心跳
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_channel != null && _isConnected) {
        try {
          // 发送心跳消息，符合后端期望的格式
          _channel!.sink.add('{"type":"ping"}');
          print('<Info> 发送心跳消息');
        } catch (e) {
          print('<Error> 发送心跳消息失败: $e');
          
          // 如果发送失败，尝试重新连接
          timer.cancel();
          _isConnected = false;
          _connectWebSocket();
        }
      } else {
        // 如果通道已关闭，取消计时器
        timer.cancel();
      }
    });
  }
  
  // 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  // 关闭连接
  void dispose() {
    // 停止心跳
    _stopHeartbeat();
    
    // 确保连接关闭
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    
    _isConnected = false;
    _listeners.clear();
    _chartDataMap.clear();
  }
  
  // 构建数据系列列表UI
  Widget buildSeriesList() {
    return Container(
      color: Colors.white.withOpacity(0.9),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      constraints: const BoxConstraints(maxHeight: 200), // 添加最大高度限制
      child: SingleChildScrollView( // 使用滚动视图包装内容
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 使用最小高度
          children: [
            const Text(
              '数据系列',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
            const SizedBox(height: 8.0),
            // 遍历当前所有图表数据构建列表
            ...(_chartDataMap.entries.expand((entry) {
              final chartKey = entry.key;
              final chartData = entry.value;
              final dataPoints = chartData['dataPoints'] as Map<String, List<(DateTime, double)>>;
              
              return dataPoints.keys.map((key) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12.0,
                        height: 12.0,
                        decoration: BoxDecoration(
                          color: getColorForKey(key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          key,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.0),
                        ),
                      ),
                    ],
                  ),
                );
              });
            }).toList()),
          ],
        ),
      ),
    );
  }
  
  // 计算Y轴的适当范围，添加边距使数据点不会紧贴边缘
  (double, double) calculateYAxisRange() {
    double minValue = double.infinity;
    double maxValue = -double.infinity;
    bool hasValidValue = false;
    
    // 遍历所有图表数据
    for (final chartData in _chartDataMap.values) {
      final dataPoints = chartData['dataPoints'] as Map<String, List<(DateTime, double)>>;
      
      for (final series in dataPoints.values) {
        for (final point in series) {
          final value = point.$2;
          if (value.isNaN) continue;
          
          hasValidValue = true;
          if (value < minValue) minValue = value;
          if (value > maxValue) maxValue = value;
        }
      }
    }
    
    // 如果没有有效值，返回默认范围
    if (!hasValidValue) {
      return (0, 100);
    }
    
    // 如果最小值和最大值相同，扩展范围
    if (minValue == maxValue) {
      minValue = minValue * 0.9;
      maxValue = maxValue * 1.1;
      if (minValue == 0 && maxValue == 0) {
        minValue = -10;
        maxValue = 10;
      }
    }
    
    // 计算数据范围
    final dataRange = maxValue - minValue;
    
    // 添加上下边距（各15%的数据范围）
    final paddingFactor = 0.15;
    final minY = minValue - (dataRange * paddingFactor);
    final maxY = maxValue + (dataRange * paddingFactor);
    
    return (minY, maxY);
  }
  
  // 构建折线图数据
  List<LineChartBarData> buildLineBarsData({
    required double radius,
    required double barWidth,
    double blurRadius = 2,
  }) {
    final List<LineChartBarData> result = [];
    
    // 遍历所有图表数据
    for (final chartData in _chartDataMap.values) {
      final dataPoints = chartData['dataPoints'] as Map<String, List<(DateTime, double)>>;
      
      // 为每个数据系列创建一条折线
      for (final entry in dataPoints.entries) {
        final key = entry.key;
        final points = entry.value;
        
        if (points.isEmpty) continue;
        
        // 排序数据点（按时间）
        points.sort((a, b) => a.$1.compareTo(b.$1));
        
        // 创建折线数据点
        final List<FlSpot> spots = [];
        for (int i = 0; i < points.length; i++) {
          final point = points[i];
          if (point.$2.isNaN) continue; // 跳过NaN值
          
          // X轴使用相对时间（以秒为单位）
          final x = i.toDouble();
          final y = point.$2;
          spots.add(FlSpot(x, y));
        }
        
        if (spots.isEmpty) continue;
        
        // 创建折线
        final lineData = LineChartBarData(
          spots: spots,
          isCurved: true,
          color: getColorForKey(key),
          barWidth: barWidth,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: radius,
                color: getColorForKey(key),
                strokeWidth: 1,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: getColorForKey(key).withOpacity(0.15),
          ),
          shadow: Shadow(
            color: getColorForKey(key).withOpacity(0.5),
            blurRadius: blurRadius,
          ),
        );
        
        result.add(lineData);
      }
    }
    
    return result;
  }
  
  // 获取放大的点尺寸
  double getExpandedDotRadius(double normalRadius) {
    return normalRadius * 1.8; // 放大到原来的1.8倍
  }
  
  // 获取概览数据（将数据按时间合并，减少数据点）
  Map<String, List<(DateTime, double)>> getOverviewData() {
    final Map<String, List<(DateTime, double)>> result = {};
    
    // 遍历所有图表数据
    for (final chartData in _chartDataMap.values) {
      final dataPoints = chartData['dataPoints'] as Map<String, List<(DateTime, double)>>;
      
      // 处理每个数据系列
      for (final entry in dataPoints.entries) {
        final key = entry.key;
        final points = entry.value;
        
        if (points.isEmpty) continue;
        
        // 如果是第一次处理该key，初始化结果列表
        if (!result.containsKey(key)) {
          result[key] = [];
        }
        
        // 按10秒间隔合并数据
        final Map<int, List<double>> timeSlots = {};
        for (final point in points) {
          // 将时间戳按10秒间隔分组
          final timestamp = point.$1;
          final slot = (timestamp.millisecondsSinceEpoch / 10000).floor();
          
          if (!timeSlots.containsKey(slot)) {
            timeSlots[slot] = [];
          }
          
          // 只添加有效值
          if (!point.$2.isNaN) {
            timeSlots[slot]!.add(point.$2);
          }
        }
        
        // 计算每个时间段的平均值
        for (final entry in timeSlots.entries) {
          final slot = entry.key;
          final values = entry.value;
          
          if (values.isEmpty) continue;
          
          // 计算平均值
          final avg = values.reduce((a, b) => a + b) / values.length;
          
          // 转换回DateTime
          final timestamp = DateTime.fromMillisecondsSinceEpoch(slot * 10000);
          
          // 添加到结果
          result[key]!.add((timestamp, avg));
        }
        
        // 确保结果按时间排序
        result[key]!.sort((a, b) => a.$1.compareTo(b.$1));
      }
    }
    
    return result;
  }
  
  // 获取底部标题控件（X轴）
  Widget getBottomTitleWidgets(double value, TitleMeta meta, {double fontSize = 12.0}) {
    const style = TextStyle(
      color: Colors.white60,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    
    // 将值转换为时间
    String text = '';
    if (value % 10 == 0) {
      // 每10个数据点显示一个标签
      final int index = value.toInt();
      text = index.toString();
    }
    
    return Text(text, style: style);
  }
} 