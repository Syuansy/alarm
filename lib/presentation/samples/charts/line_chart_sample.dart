// LineChartSample 折线图样例




// github路径:fl_chart-main\example\lib\presentation\samples\line\line_chart_sample12.dart
// cd fl_chart-main/example
// flutter run -d chrome

// 使用场景：
//   void main() {
//     runApp(MaterialApp(
//       home: Scaffold(
//         body: LineChartSample(), // 直接使用组件
//       ),
//     ));
//   }
// ​​渲染流程​​：
//   组件挂载 → 创建状态对象LineChartSample
//   执行initState → 建立WebSocket连接_connectWebSocket()
//   接收数据 → setState更新
//   重建UI → 显示带数据的折线图


import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:alarm_front/presentation/resources/app_colors.dart';
import 'package:alarm_front/util/extensions/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';
import 'package:alarm_front/util/websocket_manager.dart';
import 'package:alarm_front/util/chart_data_manager.dart';
import '../../../config/chart_data_manager.dart';
import '../../../config/chart_config.dart';
import 'dart:collection';
import 'package:alarm_front/presentation/samples/charts/html_chart_sample.dart'; // 导入HTML图表组件
import 'package:flutter/foundation.dart' show kIsWeb;
import 'html_chart_impl.dart' show WebHtmlChartImpl;
import 'package:webview_flutter/webview_flutter.dart';  // 添加WebView导入
import 'package:alarm_front/util/html_chart_manager.dart'; // 正确导入HtmlChartManager

// 通用图表数据模型类，全局使用
class ChartDataModel {
  // 数据存储
  final Map<String, Queue<(DateTime, double)>> dataHistoryByKey = {};
  // 图表标题状态
  String chartTitle = '实时数据监控';
  // 存储所有需要更新的回调函数
  final Set<Function()> _updateCallbacks = {};
  // 当前选中的key
  String? selectedKey;
  // 自动刷新状态，默认关闭
  bool _isAutoRefreshEnabled = false;

  // 数据过滤正则表达式
  late final RegExp keyPattern;
  
  // 标记是否已初始化WebSocket连接
  bool _isWebSocketInitialized = false;
  
  // 构造函数，创建时就开始接收数据
  ChartDataModel(String pattern) {
    // 验证pattern格式
    if (pattern.isEmpty) {
      print('<Warn> key pattern为空，此图表不会匹配任何数据');
      pattern = r'^\b$'; // 使用一个永远不会匹配的pattern
    }
    
    try {
      keyPattern = RegExp(pattern);
    } catch (e) {
      print('<Warn> key pattern格式错误 ($pattern)，此图表不会匹配任何数据');
      keyPattern = RegExp(r'^\b$'); // 使用一个永远不会匹配的pattern
    }
    
    // 立即开始从WebSocketManager接收数据
    _initializeWebSocket();
  }
  
  // 初始化WebSocket连接
  void _initializeWebSocket() {
    if (!_isWebSocketInitialized) {
      WebSocketManager().addListener(handleWebSocketMessage);
      loadCachedData();
      _isWebSocketInitialized = true;
      print('<Info> 已创建数据模型并开始接收数据');
    }
  }

  // 获取自动刷新状态
  bool get isAutoRefreshEnabled => _isAutoRefreshEnabled;
  
  // 设置自动刷新状态
  set isAutoRefreshEnabled(bool value) {
    if (_isAutoRefreshEnabled != value) {
      _isAutoRefreshEnabled = value;
      notifyListeners();
    }
  }

  // 为不同的key分配不同的颜色
  Color getColorForKey(String key) {
    // 使用key的哈希码生成一个稳定的颜色
    // 使用黄金比例共轭(0.618033988749895)来生成分布更均匀的颜色
    final double goldenRatioConjugate = 0.618033988749895;
    double hue = (key.hashCode.abs() * goldenRatioConjugate) % 1.0;
    
    // 固定饱和度和亮度，只变化色调以获得鲜明的颜色
    // HSL: 色调(0-1)，饱和度(0-1)，亮度(0-1)
    return HSLColor.fromAHSL(
      1.0,           // 不透明度
      hue * 360,     // 色调(0-360)
      0.7,           // 饱和度(70%)
      0.6,           // 亮度(60%)
    ).toColor();
  }

  // 获取放大的点尺寸
  double getExpandedDotRadius(double normalRadius) {
    return normalRadius * 1.8; // 放大到原来的1.8倍
  }

  // 计算Y轴的适当范围，添加边距使数据点不会紧贴边缘
  (double, double) calculateYAxisRange() {
    if (dataHistoryByKey.isEmpty) {
      return (0, 100); // 默认范围
    }
    
    // 找出所有数据点中的最小值和最大值
    double minValue = double.infinity;
    double maxValue = -double.infinity;
    bool hasValidValue = false;
    
    for (final dataPoints in dataHistoryByKey.values) {
      for (final point in dataPoints) {
        final value = point.$2;
        // 跳过NaN值
        if (value.isNaN) {
          continue;
        }
        hasValidValue = true;
        if (value < minValue) minValue = value;
        if (value > maxValue) maxValue = value;
      }
    }
    
    // 如果没有有效值（全是NaN），返回默认范围
    if (!hasValidValue) {
      return (0, 100);
    }
    
    // 如果最小值和最大值相同，扩展范围
    if (minValue == maxValue) {
      minValue = minValue * 0.9;
      maxValue = maxValue * 1.1;
      // 处理0值的特殊情况
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
  
  // 加载WebSocketManager中已缓存的数据
  void loadCachedData() {
    // 使用正则表达式模式获取匹配的缓存数据
    final matchedCache = WebSocketManager().getChartDataCacheByPattern(keyPattern);
    
    if (matchedCache.isNotEmpty) {
      print('<Info> 从WebSocketManager加载缓存数据，共${matchedCache.length}条');
      
      // 处理所有匹配的缓存数据
      for (final entry in matchedCache.entries) {
        handleWebSocketMessage(entry.value);
      }
    }
  }

  // 处理WebSocket消息
  void handleWebSocketMessage(Map<String, dynamic> data) {
    // 检查消息格式 - 只支持新格式 (type + data)
    if (!data.containsKey('type')) {
      print('<Error> 消息缺少type字段: $data');
      return;
    }

    // 只处理monitor_data类型的消息
    if (data['type'] != 'monitor_data' && data['type'] != 'root_html') {
      return;
    }
    
    // 处理新格式：{type: monitor_data, data: [...]}
    if (data.containsKey('data')) {
      final content = data['data'];
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000; // 使用当前时间戳
      final formattedTime = DateTime.now().toString(); // 使用当前格式化时间
      
      // 处理批量消息
      if (content is List) {
        // 循环处理每个数据项
        for (var item in content) {
          if (item is Map<String, dynamic>) {
            _processMonitorDataItem(item, timestamp, formattedTime);
          }
        }
      } 
      // 处理单条消息
      else if (content is Map<String, dynamic>) {
        // 直接处理单条消息
        _processMonitorDataItem(content, timestamp, formattedTime);
      }
    }
    else {
      print('<Error> 消息格式不符(缺少data字段): $data');
      return;
    }
    
    
    // 调用所有注册的更新回调
    notifyListeners();
  }
  
  // 处理单条监控数据
  void _processMonitorDataItem(Map<String, dynamic> content, int timestamp, String formattedTime) {
    final key = content['key'] as String;
    
    if (!keyPattern.hasMatch(key)) {
      // print('跳过非目标key的数据: $key');
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
    
    // 如果是第一次收到该key的数据，初始化列表
    if (!dataHistoryByKey.containsKey(key)) {
      dataHistoryByKey[key] = Queue();
    }
    
    // 添加新数据
    dataHistoryByKey[key]!.addLast((dateTime, value));
    
    // 只保留最近10分钟内的数据
    final now = DateTime.now();
    final tenMinutesAgo = now.subtract(const Duration(minutes: 10));
    while (dataHistoryByKey[key]!.isNotEmpty && dataHistoryByKey[key]!.first.$1.isBefore(tenMinutesAgo)) {
      dataHistoryByKey[key]!.removeFirst();
    }
  }

  // 通知所有监听器刷新UI
  void notifyListeners() {
    for (final callback in _updateCallbacks) {
      callback();
    }
  }

  // 注册更新回调
  void addListener(Function() callback) {
    _updateCallbacks.add(callback);
    
    // 如果这是第一个UI更新回调，确保已初始化WebSocket
    if (_updateCallbacks.length == 1 && !_isWebSocketInitialized) {
      _initializeWebSocket();
    }
  }

  // 移除更新回调
  void removeListener(Function() callback) {
    _updateCallbacks.remove(callback);
    
    // 如果没有回调了，取消注册WebSocket监听器
    // 但保持数据缓存
    if (_updateCallbacks.isEmpty && _isWebSocketInitialized) {
      WebSocketManager().removeListener(handleWebSocketMessage);
      _isWebSocketInitialized = false;
      print('<Info> 已移除WebSocket监听器，但保留数据缓存');
    }
  }

  // 生成每intervalSeconds秒一个数据点的概览数据
  Map<String, List<(DateTime, double)>> getOverviewData({int intervalSeconds = 10}) //默认10s
  {
    if (dataHistoryByKey.isEmpty) {
      return {};
    }
    
    final Map<String, List<(DateTime, double)>> overviewData = {};
    
    // 遍历所有数据系列
    for (final entry in dataHistoryByKey.entries) {
      final key = entry.key;
      final dataPoints = entry.value.toList();
      
      if (dataPoints.isEmpty) {
        overviewData[key] = [];
        continue;
      }
      
      // 为数据点按照intervalSeconds的窗口进行分组
      // 组织数据结构：Map<TimeWindow, List<Value>>
      final Map<int, List<double>> windowGroups = {};
      
      for (final point in dataPoints) {
        final dateTime = point.$1;
        final value = point.$2;
        
        // 将时间戳按照intervalSeconds进行分组
        // 将时间转换成自Unix纪元以来的秒数，然后按照intervalSeconds取整
        final timeWindow = (dateTime.millisecondsSinceEpoch / 1000 / intervalSeconds).floor() * intervalSeconds;
        
        // 跳过NaN值
        if (!value.isNaN) {
          if (!windowGroups.containsKey(timeWindow)) {
            windowGroups[timeWindow] = [];
          }
          windowGroups[timeWindow]!.add(value);
        }
      }
      
      // 计算每个窗口的平均值
      final List<(DateTime, double)> averagedPoints = [];
      windowGroups.forEach((timeWindow, values) {
        if (values.isNotEmpty) {
          // 计算平均值
          final double average = values.reduce((a, b) => a + b) / values.length;
          
          // 创建该时间窗口的代表时间点
          final dateTime = DateTime.fromMillisecondsSinceEpoch(timeWindow * 1000);
          
          // 添加到结果列表
          averagedPoints.add((dateTime, average));
        }
      });
      
      // 按时间排序
      averagedPoints.sort((a, b) => a.$1.compareTo(b.$1));
      
      // 添加到概览数据中
      overviewData[key] = averagedPoints;
    }
    
    return overviewData;
  }

  // 为每个key创建不同的LineChartBarData
  List<LineChartBarData> buildLineBarsData({
    double radius = 1,      //数据点的圆点半径
    double barWidth = 0.5,   //折线的宽度
    double blurRadius = 0, //阴影的模糊半径
    bool? useOverviewMode, // 是否使用概览模式
  }) {
    List<LineChartBarData> result = [];
    
    // 如果没有数据，返回空列表
    if (dataHistoryByKey.isEmpty) {
      return result;
    }
    
    // 根据模式选择使用原始数据还是概览数据
    // 如果传入了useOverviewMode参数，优先使用该参数
    final bool useOverview = useOverviewMode ?? isAutoRefreshEnabled;
    final int interval = (this is _LineChartSampleState && (this as _LineChartSampleState).widget.interval != null)
        ? (this as _LineChartSampleState).widget.interval!
        : 10;   //概览模式：默认10s生成一个数据点
    final Map<String, List<(DateTime, double)>> dataToUse = useOverview
        ? getOverviewData(intervalSeconds: interval).map((k, v) => MapEntry(k, v.toList()))
        : dataHistoryByKey.map((k, v) => MapEntry(k, v.toList()));
    
    // 遍历所有数据系列
    dataToUse.forEach((key, dataPoints) {
      // 如果有选中的key并且当前key不是选中的key，则跳过
      if (selectedKey != null && key != selectedKey) {
        return;
      }
      
      // 获取该key的颜色
      final color = getColorForKey(key);
      
      // 准备所有数据点（包括NaN）
      List<FlSpot> allSpots = [];
      
      for (int i = 0; i < dataPoints.length; i++) {
        final value = dataPoints[i].$2;
        // 对于NaN值，使用特殊标记，但保留索引位置
        // 注意：我们使用极大的负值（比任何正常数据都小）作为标记
        // 这些点不会被显示，但会保留索引位置
        allSpots.add(FlSpot(i.toDouble(), value.isNaN ? double.negativeInfinity : value));
      }
      
      // 按照索引顺序分段，当遇到NaN值时断开
      final List<List<FlSpot>> segments = [];
      List<FlSpot> currentSegment = [];
      
      for (final spot in allSpots) {
        if (spot.y == double.negativeInfinity) { // 这是NaN值的标记
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
            currentSegment = [];
          }
        } else {
          currentSegment.add(spot);
        }
      }
      
      if (currentSegment.isNotEmpty) {
        segments.add(currentSegment);
      }
      
      // 为每个连续段创建LineChartBarData
      for (final segment in segments) {
        if (segment.isNotEmpty) {
          result.add(
            LineChartBarData(
              spots: segment,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: radius,
                    color: color,
                    strokeWidth: 0,
                    strokeColor: color,
                  );
                },
              ),
              color: color,
              barWidth: barWidth,
              shadow: Shadow(
                color: color,
                blurRadius: blurRadius,
              ),
            ),
          );
        }
      }
      
      // 为索引连续性添加一个"隐形"线（不可见但占据相应的位置）
      result.add(
        LineChartBarData(
          spots: allSpots,
          dotData: FlDotData(
            show: false, // 不显示点
          ),
          color: Colors.transparent, // 透明色
          barWidth: 0, // 宽度为0
          isStrokeJoinRound: false,
          preventCurveOverShooting: true,
          showingIndicators: [], // 不显示指示器
          isStrokeCapRound: false,
          shadow: const Shadow(
            color: Colors.transparent, // 透明阴影
            blurRadius: 0,
          ),
        ),
      );
    });
    
    return result;
  }

  // 获取底部标题小部件
  Widget getBottomTitleWidgets(double value, TitleMeta meta, {
    double fontSize = 12,
    bool? useOverviewMode, // 新增参数，用于控制是否使用概览模式
  }) {
    // 如果没有数据，返回空小部件
    if (dataHistoryByKey.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 根据模式选择使用原始数据还是概览数据
    // 如果传入了useOverviewMode参数，优先使用该参数
    final bool useOverview = useOverviewMode ?? isAutoRefreshEnabled;
    final int interval = (this is _LineChartSampleState && (this as _LineChartSampleState).widget.interval != null)
        ? (this as _LineChartSampleState).widget.interval!
        : 10;
    final Map<String, List<(DateTime, double)>> dataToUse = useOverview
        ? getOverviewData(intervalSeconds: interval).map((k, v) => MapEntry(k, v.toList()))
        : dataHistoryByKey.map((k, v) => MapEntry(k, v.toList()));
    
    // 确定用于时间轴的key
    String? keyForTimeAxis;
    
    // 如果有选中的key，优先使用选中的key
    if (selectedKey != null && dataToUse.containsKey(selectedKey)) {
      keyForTimeAxis = selectedKey;
    } else {
      // 否则找到所有key中总数据点最多的一个（包括NaN点）
      int maxPointCount = 0;
      
      for (final entry in dataToUse.entries) {
        if (entry.value.length > maxPointCount) {
          maxPointCount = entry.value.length;
          keyForTimeAxis = entry.key;
        }
      }
    }
    
    if (keyForTimeAxis == null) {
      return const SizedBox.shrink();
    }
    
    // 获取时间戳
    final dataPoints = dataToUse[keyForTimeAxis]?.toList() ?? [];
    final valueInt = value.toInt();
    
    if (valueInt >= dataPoints.length) {
      return const SizedBox.shrink();
    }
    
    final date = dataPoints[valueInt].$1;
    
    // 根据模式显示不同的时间格式
    String timeText;
    if (useOverview) {
      // 概览模式显示分钟:秒格式
      timeText = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      // 详细模式显示时:分:秒格式
      timeText = '${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    }
    
    return SideTitleWidget(
      meta: meta,
      child: Transform.rotate(
        angle: -45 * 3.14 / 180,    //旋转-45度避免重叠
        child: Text(
          timeText,
          style: TextStyle(
            color: AppColors.contentColorGreen,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 构建数据系列列表
  Widget buildSeriesList({double fontSize = 12, double initialHeight = 150, VoidCallback? onClose}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: AppColors.contentColorBlack.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.contentColorYellow.withOpacity(0.5)),
      ),
      child: dataHistoryByKey.isEmpty
          ? Text(
              '暂无数据',
              style: TextStyle(
                color: AppColors.contentColorGreen,
                fontSize: fontSize,
              ),
            )
          : _ResizableSeriesList(
              initialHeight: initialHeight,
              maxHeight: 400,
              onClose: onClose,
              child: Column(
                children: dataHistoryByKey.entries.map((entry) {
                  final key = entry.key;
                  final color = getColorForKey(key);
                  final isSelected = key == selectedKey;
                  
                  // 获取当前值（最新值）
                  String currentValue = "---";    //为空时显示"---"
                  if (entry.value.isNotEmpty) {
                    final lastPoint = entry.value.last;
                    currentValue = lastPoint.$2.isNaN 
                        ? "NaN" 
                        : lastPoint.$2.toStringAsFixed(2);
                  }

                  return GestureDetector(
                    onTap: () {
                      // 点击时切换选中状态
                      selectedKey = isSelected ? null : key;
                      notifyListeners();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              key,
                              style: TextStyle(
                                color: AppColors.contentColorGreen,
                                fontSize: fontSize,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, // 选中时加粗
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 添加当前值显示
                          Text(
                            currentValue,
                            style: TextStyle(
                              color: AppColors.contentColorYellow,
                              fontSize: fontSize,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class LineChartSample extends StatefulWidget {
  const LineChartSample({
    super.key,
    this.title,
    this.chartKey,
    this.interval,
    this.abnormalCondition,
    this.isAutoRefreshEnabled = false,
    this.yAxis,
    this.defaultDisplay,
    this.htmlUrl, // 新增htmlUrl属性
  });

  final String? title;
  final String? chartKey;
  final int? interval;
  final String? abnormalCondition;
  final bool isAutoRefreshEnabled;
  final String? yAxis;
  final String? defaultDisplay;
  final String? htmlUrl; // 存储htmlUrl

  @override
  State<LineChartSample> createState() => _LineChartSampleState();
}

class _LineChartSampleState extends State<LineChartSample> {
  // 使用全局数据模型管理器获取数据模型实例
  late final ChartDataModel _dataModel;
  bool _isSeriesListVisible = false;
  // 编辑面板显示状态
  bool _isEditPanelVisible = false;
  
  // 在状态中单独维护自动刷新状态
  late bool _isAutoRefreshEnabled;
  
  // 添加root模式状态
  bool _isRootModeEnabled = false;
  
  // 添加TextEditingController
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController();
  final TextEditingController _abnormalConditionController = TextEditingController();
  late final String _yAxis;
  late final String _defaultDisplay;

  @override
  void initState() {
    super.initState();
    _yAxis = widget.yAxis ?? 'Hz';
    _defaultDisplay = widget.defaultDisplay ?? '详情图';
    // 根据defaultDisplay初始化自动刷新状态
    if (_defaultDisplay == '概览图') {
      _isAutoRefreshEnabled = true;
    } else {
      _isAutoRefreshEnabled = false;
    }
    // 使用默认的Key Pattern
    // String keyPattern = r'^top-PMT-dcr\.VME[^.]+\.triggerRate$';
    String keyPattern = r'.*';
    // 使用配置中的参数（如果提供）
    if (widget.chartKey != null && widget.chartKey!.isNotEmpty) {
      keyPattern = widget.chartKey!;
      print('<Info> 使用配置中的正则表达式: $keyPattern');
    }
    // 从全局管理器获取数据模型实例
    _dataModel = ChartDataModelManager().getDataModel(keyPattern);
    // 设置异常条件（如果提供）
    if (widget.abnormalCondition != null) {
      print('<Info> 设置异常条件: ${widget.abnormalCondition}');
      // 这里可以添加处理异常条件的逻辑
    }
    // 设置刷新间隔（如果提供）
    if (widget.interval != null) {
      print('<Info> 设置刷新间隔: ${widget.interval}秒');
      // 这里可以设置刷新间隔
    }
    // 注册更新回调以更新UI
    _dataModel.addListener(_updateUI);
  }

  void _updateUI() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _dataModel.removeListener(_updateUI);
    // 释放控制器
    _titleController.dispose();
    _keyController.dispose();
    _intervalController.dispose();
    _abnormalConditionController.dispose();
    super.dispose();
  }

  // 切换到全屏模式
  void _toggleFullScreen() {
    // 如果当前是root模式并且有htmlUrl，直接使用HTML图表的全屏方法
    if (_isRootModeEnabled && widget.htmlUrl != null) {
      // 调用HtmlChartSample的全屏方法
      if (kIsWeb) {
        // Web平台：在新窗口打开URL
        WebHtmlChartImpl.openInNewWindow(widget.htmlUrl!);
      } else {
        // 非Web平台：使用原生WebView全屏展示
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _FullScreenWebView(
              htmlUrl: widget.htmlUrl!,
              title: widget.title ?? _dataModel.chartTitle,
            ),
          ),
        );
      }
    } else {
      // 非root模式，使用_FullScreenChart
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullScreenChart(
            dataModel: _dataModel,
            yAxis: _yAxis,
            htmlUrl: widget.htmlUrl,
            isRootModeEnabled: _isRootModeEnabled,
          ),
        ),
      );
    }
  }

  // 切换数据系列列表的显示/隐藏
  void _toggleSeriesList() {
    setState(() {
      _isSeriesListVisible = !_isSeriesListVisible;
    });
  }

  // 切换编辑面板显示状态
  void _toggleEditPanel() {
    setState(() {
      _isEditPanelVisible = !_isEditPanelVisible;
      
      // 如果是打开编辑面板，则设置初始值
      if (_isEditPanelVisible) {
        _titleController.text = widget.title ?? _dataModel.chartTitle;
        _keyController.text = widget.chartKey ?? '';
        _intervalController.text = (widget.interval ?? 1).toString();
        _abnormalConditionController.text = widget.abnormalCondition ?? 'value > 0';
      }
    });
  }
  
  // 保存配置
  void _saveConfig() async {
    // 获取位置信息
    String position = "7"; // 默认使用当前文件所在的位置
    
    try {
      // 尝试从widget.key中提取位置信息
      final keyString = widget.chartKey.toString();
      final keyParts = keyString.split('\'');
      if (keyParts.length > 1) {
        position = keyParts[1]; 
      }
    } catch (e) {
      print('<Warn> 提取位置信息失败: $e，使用默认位置: $position');
    }
    
    // 获取编辑后的值
    final String title = _titleController.text;
    final String key = _keyController.text;
    final int interval = int.tryParse(_intervalController.text) ?? 1;
    final String abnormalCondition = _abnormalConditionController.text;
    
    // 调用保存方法
    final bool success = await ChartConfigManager.saveChartConfig(
      position,
      title: title,
      key: key,
      interval: interval,
      abnormalCondition: abnormalCondition,
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图表配置已保存')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败')),
      );
    }
    
    // 关闭编辑面板
    setState(() {
      _isEditPanelVisible = false;
    });
  }

  // 切换自动刷新状态
  void _toggleAutoRefresh() {
    setState(() {
      _isAutoRefreshEnabled = !_isAutoRefreshEnabled;
      // 切换自动刷新时，如果处于root模式，需要退出root模式
      if (_isRootModeEnabled) {
        _isRootModeEnabled = false;
      }
    });
  }
  
  // 切换到root模式
  void _toggleRootMode() {
    setState(() {
      _isRootModeEnabled = !_isRootModeEnabled;
      // 当进入root模式时，关闭自动刷新
      if (_isRootModeEnabled) {
        _isAutoRefreshEnabled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _ChartTitle(
              onFullScreenPressed: _toggleFullScreen,
              onListPressed: _toggleSeriesList,
              onEditPressed: _toggleEditPanel,
              onTogglePressed: _toggleAutoRefresh,
              chartTitle: widget.title ?? _dataModel.chartTitle,
              isFullScreen: false,
              isAutoRefreshEnabled: _isAutoRefreshEnabled,
              isRootModeEnabled: _isRootModeEnabled, // 传递root模式状态
            ),
            // 添加条件显示的数据系列列表
            if (_isSeriesListVisible && !_isRootModeEnabled)
              _dataModel.buildSeriesList(onClose: _toggleSeriesList),
            
            // 使用AspectRatio包装图表内容
            AspectRatio(
              aspectRatio: 1.4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 20, 8),
                child: _isRootModeEnabled && widget.htmlUrl != null
                  // 在root模式下，使用Column布局组合图表信息表格和HTML图表
                  ? Column(
                      children: [
                        // 显示图表信息表格
                        _buildChartInfoBar(),
                        // 显示HTML图表
                        Expanded(
                          child: HtmlChartSample(
                            htmlUrl: widget.htmlUrl!,
                          ),
                        ),
                      ],
                    )
                  // 在非root模式下，使用普通的_LineChartContent
                  : _LineChartContent(
                      dataModel: _dataModel,
                      isFullScreen: false,
                      isAutoRefreshEnabled: _isAutoRefreshEnabled,
                      yAxis: _yAxis,
                      hashtmlUrl: widget.htmlUrl != null, // 传递是否有htmlUrl
                      onRootModeSelected: _toggleRootMode, // 传递root模式切换回调
                    ),
              ),
            ),
          ],
        ),
        
        // 编辑按钮——编辑面板
        if (_isEditPanelVisible)
          Positioned.fill(
            child: Container(
              color: AppColors.contentColorBlack.withOpacity(0.7),
              child: Stack(
                children: [
                  // 面板内容
                  Center(
                    child: Container(
                      width: 450,
                      height: 380,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.contentColorBlack.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.contentColorYellow.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 第一行 - Title
                          Row(
                            children: [
                              const SizedBox(
                                width: 120,
                                child: Text(
                                  'Title',
                                  style: TextStyle(
                                    color: AppColors.contentColorYellow,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _titleController,
                                  style: const TextStyle(
                                    color: AppColors.contentColorGreen,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    fillColor: AppColors.contentColorBlack.withOpacity(0.5),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.contentColorYellow.withOpacity(0.5),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.contentColorYellow.withOpacity(0.5),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppColors.contentColorYellow,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // 第二行 - Key
                          Row(
                            children: [
                              const SizedBox(
                                width: 120,
                                child: Text(
                                  'Key',
                                  style: TextStyle(
                                    color: AppColors.contentColorYellow,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _keyController,
                                  style: const TextStyle(
                                    color: AppColors.contentColorGreen,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    fillColor: AppColors.contentColorBlack.withOpacity(0.5),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.contentColorYellow.withOpacity(0.5),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.contentColorYellow.withOpacity(0.5),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppColors.contentColorYellow,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // 第三行 - Interval
                          Row(
                            children: [
                              const SizedBox(
                                width: 120,
                                child: Text(
                                  'Interval',
                                  style: TextStyle(
                                    color: AppColors.contentColorYellow,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _intervalController,
                                  style: const TextStyle(
                                    color: AppColors.contentColorGreen,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    fillColor: AppColors.contentColorBlack.withOpacity(0.5),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.contentColorYellow.withOpacity(0.5),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.contentColorYellow.withOpacity(0.5),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppColors.contentColorYellow,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // 第四行 - Abnormal Condition
                          Row(
                            children: [
                              const SizedBox(
                                width: 160,
                                child: Text(
                                  'Abnormal Condition',
                                  style: TextStyle(
                                    color: AppColors.contentColorYellow,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _abnormalConditionController,
                                  style: const TextStyle(
                                    color: AppColors.contentColorGreen,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    fillColor: AppColors.contentColorBlack.withOpacity(0.5),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.contentColorYellow.withOpacity(0.5),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.contentColorYellow.withOpacity(0.5),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppColors.contentColorYellow,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // 第五行 - 完成按钮
                          Center(
                            child: ElevatedButton(
                              onPressed: _saveConfig,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.contentColorYellow.withOpacity(0.8),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                '完成',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 关闭按钮
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.contentColorYellow,
                        size: 32,
                      ),
                      onPressed: _toggleEditPanel,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  // 新增：构建图表信息表格的方法
  Widget _buildChartInfoBar() {
    final double fontSize = 12; // 修正为12
    final String pointInterval = _isAutoRefreshEnabled ? '10秒/点' : '1秒/点';
    final int keyMatchCount = _dataModel.dataHistoryByKey.length;
    
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Key匹配数: $keyMatchCount',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 添加分隔线
            Container(
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            // 模式下拉菜单
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: InkWell(
                onTap: () {
                  _showModeMenu(context);
                },
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isRootModeEnabled ? 'root模式' : (_isAutoRefreshEnabled ? '概览模式' : '详细模式'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.contentColorYellow.withOpacity(0.8),
                      size: fontSize + 8,
                    ),
                  ],
                ),
              ),
            ),
            // 添加分隔线
            Container(
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            Text(
              pointInterval,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 新增：显示模式菜单的方法
  void _showModeMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    
    showMenu<String>(
      context: context,
      position: position,
      elevation: 0,
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem<String>(
          height: 30,
          value: 'detail',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '详细模式',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
        PopupMenuItem<String>(
          height: 30,
          value: 'overview',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '概览模式',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
        PopupMenuItem<String>(
          height: 30,
          value: 'extremum',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '最值模式',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
        PopupMenuItem<String>(
          height: 30,
          value: 'abnormal',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '异常模式',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
        // 仅当有htmlUrl时才显示root模式选项
        if (widget.htmlUrl != null)
          PopupMenuItem<String>(
            height: 30,
            value: 'root',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'root模式',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ),
      ],
    ).then((value) {
      if (value != null) {
        if (value == 'detail') {
          // 如果当前是root模式，先退出root模式
          if (_isRootModeEnabled) {
            _toggleRootMode();
          }
          // 如果当前是自动刷新模式，关闭自动刷新
          if (_isAutoRefreshEnabled) {
            _toggleAutoRefresh();
          }
        } else if (value == 'overview') {
          // 如果当前是root模式，先退出root模式
          if (_isRootModeEnabled) {
            _toggleRootMode();
          }
          // 如果当前不是自动刷新模式，开启自动刷新
          if (!_isAutoRefreshEnabled) {
            _toggleAutoRefresh();
          }
        } else if (value == 'root' && widget.htmlUrl != null) {
          // 如果当前不是root模式，切换到root模式
          if (!_isRootModeEnabled) {
            _toggleRootMode();
          }
        }
        // 其他模式暂不处理
      }
    });
  }
}

// 全屏图表页面
class _FullScreenChart extends StatefulWidget {
  final ChartDataModel dataModel;
  final String yAxis;
  final String? htmlUrl; // 添加htmlUrl属性
  final bool isRootModeEnabled; // 添加root模式状态

  const _FullScreenChart({
    required this.dataModel,
    required this.yAxis,
    this.htmlUrl,
    this.isRootModeEnabled = false,
  });

  @override
  State<_FullScreenChart> createState() => _FullScreenChartState();
}

class _FullScreenChartState extends State<_FullScreenChart> {
  bool _isSeriesListVisible = false;
  // 编辑面板显示状态
  bool _isEditPanelVisible = false;
  
  // 添加自动刷新状态
  bool _isAutoRefreshEnabled = false;
  
  // 添加root模式状态
  late bool _isRootModeEnabled;
  
  // 添加TextEditingController
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController();
  final TextEditingController _abnormalConditionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 从widget初始化root模式状态
    _isRootModeEnabled = widget.isRootModeEnabled;
    // 注册更新回调以更新UI
    widget.dataModel.addListener(_updateUI);
  }

  void _updateUI() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.dataModel.removeListener(_updateUI);
    // 释放控制器
    _titleController.dispose();
    _keyController.dispose();
    _intervalController.dispose();
    _abnormalConditionController.dispose();
    super.dispose();
  }

  // 切换数据系列列表的显示/隐藏
  void _toggleSeriesList() {
    setState(() {
      _isSeriesListVisible = !_isSeriesListVisible;
    });
  }
  
  // 切换编辑面板显示状态
  void _toggleEditPanel() {
    setState(() {
      _isEditPanelVisible = !_isEditPanelVisible;
      
      // 如果是打开编辑面板，则设置初始值
      if (_isEditPanelVisible) {
        _titleController.text = widget.dataModel.chartTitle;
        _keyController.text = widget.dataModel.keyPattern.pattern;
        _intervalController.text = '1'; // 默认值
        _abnormalConditionController.text = 'value > 0'; // 默认值
      }
    });
  }
  
  // 保存配置
  void _saveConfig() async {
    // 在全屏模式中使用默认位置
    String position = "7"; // 默认使用当前配置文件中的位置
    
    // 获取编辑后的值
    final String title = _titleController.text;
    final String key = _keyController.text;
    final int interval = int.tryParse(_intervalController.text) ?? 1;
    final String abnormalCondition = _abnormalConditionController.text;
    
    // 调用保存方法
    final bool success = await ChartConfigManager.saveChartConfig(
      position,
      title: title,
      key: key,
      interval: interval,
      abnormalCondition: abnormalCondition,
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图表配置已保存')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败')),
      );
    }
    
    // 关闭编辑面板
    setState(() {
      _isEditPanelVisible = false;
    });
  }
  
  // 切换自动刷新状态
  void _toggleAutoRefresh() {
    setState(() {
      _isAutoRefreshEnabled = !_isAutoRefreshEnabled;
      // 切换自动刷新时，如果处于root模式，需要退出root模式
      if (_isRootModeEnabled) {
        _isRootModeEnabled = false;
      }
    });
  }
  
  // 切换到root模式
  void _toggleRootMode() {
    setState(() {
      _isRootModeEnabled = !_isRootModeEnabled;
      // 当进入root模式时，关闭自动刷新
      if (_isRootModeEnabled) {
        _isAutoRefreshEnabled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {    // 编辑按钮——编辑面板
    return Scaffold(   //Scaffold是Flutter提供的一个组件，用于创建一个包含导航栏、抽屉、底部导航栏等的页面
      backgroundColor: Colors.black,  // 黑色背景
      body: SafeArea(// 避开系统UI区域
        child: Stack(   // 叠加布局（用于浮动编辑面板）
          children: [
            Column(
              children: [
                _ChartTitle(
                  onFullScreenPressed: () => Navigator.of(context).pop(),
                  onListPressed: _toggleSeriesList,
                  onEditPressed: _toggleEditPanel,
                  onTogglePressed: _toggleAutoRefresh,
                  chartTitle: widget.dataModel.chartTitle,
                  isFullScreen: true,
                  isAutoRefreshEnabled: _isAutoRefreshEnabled,
                  isRootModeEnabled: _isRootModeEnabled, // 传递root模式状态
                ),
                // 添加条件显示的数据系列列表
                if (_isSeriesListVisible && !_isRootModeEnabled)
                  widget.dataModel.buildSeriesList(fontSize: 14, onClose: _toggleSeriesList),
                
                // 使用Expanded包装图表内容
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 20, 16),
                    child: _isRootModeEnabled && widget.htmlUrl != null
                      // 在root模式下，使用Column布局组合图表信息表格和HTML图表
                      ? Column(
                          children: [
                            // 显示图表信息表格
                            _buildChartInfoBar(),
                            // 显示HTML图表
                            Expanded(
                              child: HtmlChartSample(
                                htmlUrl: widget.htmlUrl!,
                              ),
                            ),
                          ],
                        )
                      // 在非root模式下，使用普通的_LineChartContent
                      : _LineChartContent(
                          dataModel: widget.dataModel,
                          isFullScreen: true,
                          isAutoRefreshEnabled: _isAutoRefreshEnabled,
                          yAxis: widget.yAxis,
                          hashtmlUrl: widget.htmlUrl != null, // 传递是否有htmlUrl
                          onRootModeSelected: _toggleRootMode, // 传递root模式切换回调
                        ),
                  ),
                ),
              ],
            ),
            
            // 编辑按钮——编辑面板
            if (_isEditPanelVisible)
              Positioned.fill(
                child: Container(
                  color: AppColors.contentColorBlack.withOpacity(0.7),
                  child: Stack(
                    children: [
                      // 面板内容
                      Center(
                        child: Container(
                          width: 450,
                          height: 380,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.contentColorBlack.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.contentColorYellow.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 第一行 - Title
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Title',
                                      style: TextStyle(
                                        color: AppColors.contentColorYellow,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _titleController,
                                      style: const TextStyle(
                                        color: AppColors.contentColorGreen,
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        fillColor: AppColors.contentColorBlack.withOpacity(0.5),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.contentColorYellow.withOpacity(0.5),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.contentColorYellow.withOpacity(0.5),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: AppColors.contentColorYellow,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // 第二行 - Key
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Key',
                                      style: TextStyle(
                                        color: AppColors.contentColorYellow,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _keyController,
                                      style: const TextStyle(
                                        color: AppColors.contentColorGreen,
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        fillColor: AppColors.contentColorBlack.withOpacity(0.5),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.contentColorYellow.withOpacity(0.5),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.contentColorYellow.withOpacity(0.5),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: AppColors.contentColorYellow,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // 第三行 - Interval
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Interval',
                                      style: TextStyle(
                                        color: AppColors.contentColorYellow,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _intervalController,
                                      style: const TextStyle(
                                        color: AppColors.contentColorGreen,
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        fillColor: AppColors.contentColorBlack.withOpacity(0.5),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.contentColorYellow.withOpacity(0.5),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.contentColorYellow.withOpacity(0.5),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: AppColors.contentColorYellow,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // 第四行 - Abnormal Condition
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 160,
                                    child: Text(
                                      'Abnormal Condition',
                                      style: TextStyle(
                                        color: AppColors.contentColorYellow,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _abnormalConditionController,
                                      style: const TextStyle(
                                        color: AppColors.contentColorGreen,
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        fillColor: AppColors.contentColorBlack.withOpacity(0.5),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.contentColorYellow.withOpacity(0.5),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: AppColors.contentColorYellow.withOpacity(0.5),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: AppColors.contentColorYellow,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // 第五行 - 完成按钮
                              Center(
                                child: ElevatedButton(
                                  onPressed: _saveConfig,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.contentColorYellow.withOpacity(0.8),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    '完成',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // 关闭按钮
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.contentColorYellow,
                            size: 32,
                          ),
                          onPressed: _toggleEditPanel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // 新增：构建图表信息表格的方法（在_FullScreenChart类中）
  Widget _buildChartInfoBar() {
    final double fontSize = 12; // 修正为12
    final String pointInterval = _isAutoRefreshEnabled ? '10秒/点' : '1秒/点';
    final int keyMatchCount = widget.dataModel.dataHistoryByKey.length;
    
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Key匹配数: $keyMatchCount',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 添加分隔线
            Container(
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            // 模式下拉菜单
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: InkWell(
                onTap: () {
                  _showModeMenu(context);
                },
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isRootModeEnabled ? 'root模式' : (_isAutoRefreshEnabled ? '概览模式' : '详细模式'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.contentColorYellow.withOpacity(0.8),
                      size: fontSize + 8,
                    ),
                  ],
                ),
              ),
            ),
            // 添加分隔线
            Container(
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            Text(
              pointInterval,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 新增：显示模式菜单的方法
  void _showModeMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    
    showMenu<String>(
      context: context,
      position: position,
      elevation: 0,
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem<String>(
          height: 30,
          value: 'detail',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '详细模式',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
        PopupMenuItem<String>(
          height: 30,
          value: 'overview',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '概览模式',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
        PopupMenuItem<String>(
          height: 30,
          value: 'extremum',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '最值模式',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
        PopupMenuItem<String>(
          height: 30,
          value: 'abnormal',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '异常模式',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
        // 仅当有htmlUrl时才显示root模式选项
        if (widget.htmlUrl != null)
          PopupMenuItem<String>(
            height: 30,
            value: 'root',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'root模式',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ),
      ],
    ).then((value) {
      if (value != null) {
        if (value == 'detail') {
          // 如果当前是root模式，先退出root模式
          if (_isRootModeEnabled) {
            _toggleRootMode();
          }
          // 如果当前是自动刷新模式，关闭自动刷新
          if (_isAutoRefreshEnabled) {
            _toggleAutoRefresh();
          }
        } else if (value == 'overview') {
          // 如果当前是root模式，先退出root模式
          if (_isRootModeEnabled) {
            _toggleRootMode();
          }
          // 如果当前不是自动刷新模式，开启自动刷新
          if (!_isAutoRefreshEnabled) {
            _toggleAutoRefresh();
          }
        } else if (value == 'root' && widget.htmlUrl != null) {
          // 如果当前不是root模式，切换到root模式
          if (!_isRootModeEnabled) {
            _toggleRootMode();
          }
        }
        // 其他模式暂不处理
      }
    });
  }
}

// 图表标题组件
class _ChartTitle extends StatefulWidget {
  final VoidCallback onFullScreenPressed;
  final VoidCallback onListPressed;
  final VoidCallback onEditPressed;
  final VoidCallback onTogglePressed;
  final String chartTitle;
  final bool isFullScreen;
  final bool isAutoRefreshEnabled;
  final bool isRootModeEnabled; // 添加root模式状态

  const _ChartTitle({
    required this.onFullScreenPressed,
    required this.onListPressed,
    required this.onEditPressed,
    required this.onTogglePressed,
    required this.chartTitle,
    required this.isFullScreen,
    required this.isAutoRefreshEnabled,
    required this.isRootModeEnabled, // 接收root模式状态
  });

  @override
  State<_ChartTitle> createState() => _ChartTitleState();
}

class _ChartTitleState extends State<_ChartTitle> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 0, 0), // 只保留整体顶部间距
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一排：右对齐按钮
          Row(
            children: [
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: AppColors.contentColorYellow,
                  size: 20,
                ),
                onPressed: widget.onEditPressed,
              ),
              IconButton(
                icon: const Icon(
                  Icons.list,
                  color: AppColors.contentColorYellow,
                  size: 20,
                ),
                onPressed: widget.onListPressed,
              ),
              IconButton(
                icon: Icon(
                  widget.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: AppColors.contentColorYellow,
                  size: 20,
                ),
                onPressed: widget.onFullScreenPressed,
              ),
            ],
          ),
          // 第二排：标题居中（无padding）
          Center(
            child: Text(
              widget.chartTitle,
              style: TextStyle(
                color: AppColors.contentColorYellow,
                fontWeight: FontWeight.bold,
                fontSize: widget.isFullScreen ? 22 : 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 图表内容组件
class _LineChartContent extends StatelessWidget {
  final ChartDataModel dataModel;
  final bool isFullScreen;
  final bool isAutoRefreshEnabled;
  final String yAxis;
  final bool hashtmlUrl; // 添加是否有htmlUrl的属性
  final VoidCallback? onRootModeSelected; // 添加root模式回调

  const _LineChartContent({
    required this.dataModel,
    required this.isFullScreen,
    required this.isAutoRefreshEnabled,
    required this.yAxis,
    this.hashtmlUrl = false, // 默认没有htmlUrl
    this.onRootModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 获取Y轴范围
    final (minY, maxY) = dataModel.calculateYAxisRange();
    
    // 根据是否全屏设置不同的参数
    final double dotRadius = isFullScreen ? 3 : 2;
    final double barWidth = isFullScreen ? 2 : 1;
    final double blurRadius = isFullScreen ? 3 : 2;
    final double fontSize = isFullScreen ? 14 : 12;
    final double reservedLeftSize = isFullScreen ? 40.0 : 52.0;
    final double reservedBottomSize = isFullScreen ? 50 : 38;
    
    // 设置图表标题相关信息
    final String pointInterval = isAutoRefreshEnabled ? '10秒/点' : '1秒/点';
    final int keyMatchCount = dataModel.dataHistoryByKey.length;
    
    return Column(
      children: [
        // 显示图表信息表格
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          width: double.infinity,
          alignment: Alignment.center, // 添加居中对齐
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), // 减小垂直间距
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Key匹配数: $keyMatchCount',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7), // 改为白色
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 添加分隔线
                Container(
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 1,
                  color: Colors.white.withOpacity(0.3),
                ),
                // 自定义紧凑型下拉菜单
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: InkWell(
                    onTap: () {
                      // 创建自定义弹出菜单
                      final RenderBox button = context.findRenderObject() as RenderBox;
                      final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                      final RelativeRect position = RelativeRect.fromRect(
                        Rect.fromPoints(
                          button.localToGlobal(Offset.zero, ancestor: overlay),
                          button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
                        ),
                        Offset.zero & overlay.size,
                      );
                      
                      showMenu<String>(
                        context: context,
                        position: position,
                        elevation: 0,
                        color: Colors.white.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        items: [
                          PopupMenuItem<String>(
                            height: 30, // 这里可以设置更小的高度
                            value: 'detail',
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text(
                              '详细模式',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            height: 30, // 这里可以设置更小的高度
                            value: 'overview',
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text(
                              '概览模式',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                          // 新增最值模式
                          PopupMenuItem<String>(
                            height: 30,
                            value: 'extremum',
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text(
                              '最值模式',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                          // 新增异常模式
                          PopupMenuItem<String>(
                            height: 30,
                            value: 'abnormal',
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text(
                              '异常模式',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                          // 仅当有htmlUrl时才显示root模式选项
                          if (hashtmlUrl)
                            PopupMenuItem<String>(
                              height: 30,
                              value: 'root',
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Text(
                                'root模式',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: fontSize,
                                ),
                              ),
                            ),
                        ],
                        ).then((value) {
                          if (value != null) {
                            // 处理详细模式和概览模式的切换
                            if (value == 'detail') {
                              // 如果在root模式，先退出root模式
                              if (hashtmlUrl && onRootModeSelected != null) {
                                onRootModeSelected!(); // 调用回调切换到非root模式
                              }
                              // 然后切换到详细模式
                              if (isAutoRefreshEnabled) {
                                if (context.findAncestorStateOfType<_LineChartSampleState>() != null) {
                                  context.findAncestorStateOfType<_LineChartSampleState>()!._toggleAutoRefresh();
                                } else if (context.findAncestorStateOfType<_FullScreenChartState>() != null) {
                                  context.findAncestorStateOfType<_FullScreenChartState>()!._toggleAutoRefresh();
                                }
                              }
                            } else if (value == 'overview') {
                              // 如果在root模式，先退出root模式
                              if (hashtmlUrl && onRootModeSelected != null) {
                                onRootModeSelected!(); // 调用回调切换到非root模式
                              }
                              // 然后切换到概览模式
                              if (!isAutoRefreshEnabled) {
                                if (context.findAncestorStateOfType<_LineChartSampleState>() != null) {
                                  context.findAncestorStateOfType<_LineChartSampleState>()!._toggleAutoRefresh();
                                } else if (context.findAncestorStateOfType<_FullScreenChartState>() != null) {
                                  context.findAncestorStateOfType<_FullScreenChartState>()!._toggleAutoRefresh();
                                }
                              }
                            } else if (value == 'root' && hashtmlUrl && onRootModeSelected != null) {
                              onRootModeSelected!(); // 调用回调切换到root模式
                            }
                            // 其他模式暂不处理
                          }
                        });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isAutoRefreshEnabled ? '概览模式' : '详细模式',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.contentColorYellow.withOpacity(0.8),
                          size: fontSize + 8,
                        ),
                      ],
                    ),
                  ),
                ),
                // 添加分隔线
                Container(
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 1,
                  color: Colors.white.withOpacity(0.3),
                ),
                Text(
                  pointInterval,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7), // 改为白色
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 图表
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // y轴单位标签
              Container(
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: -3.14 / 2,
                  child: Text(
                    yAxis,
                    style: const TextStyle(
                      color: AppColors.contentColorYellow,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              // 图表主体
              Expanded(
                child: LineChart(
                  transformationConfig: FlTransformationConfig(
                    scaleAxis: FlScaleAxis.horizontal,
                    minScale: 1.0, maxScale: 25.0,
                    panEnabled: true,
                    scaleEnabled: true,
                  ),
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: dataModel.buildLineBarsData(
                      radius: dotRadius,
                      barWidth: barWidth,
                      blurRadius: blurRadius,
                      useOverviewMode: isAutoRefreshEnabled, // 传递当前组件的模式
                    ),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchSpotThreshold: 12, // 增大触摸区域
                      handleBuiltInTouches: true, // 启用内置触摸处理，恢复提示线
                      touchTooltipData: LineTouchTooltipData(
                        // 禁用内置tooltip，我们使用自定义tooltip
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          // 必须返回与touchedBarSpots相同数量的items，即使是空的
                          return List.generate(
                            touchedBarSpots.length,
                            (index) => const LineTooltipItem('', TextStyle(fontSize: 0)),
                          );
                        },
                        tooltipRoundedRadius: 0,
                        tooltipPadding: EdgeInsets.zero,
                        tooltipMargin: 0,
                        getTooltipColor: (_) => Colors.transparent,
                      ),
                      touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                        // 过滤掉NaN值的触摸事件
                        if (touchResponse != null && 
                            touchResponse.lineBarSpots != null && 
                            touchResponse.lineBarSpots!.isNotEmpty) {
                          // 检查是否有spot的y值为NaN或极大负值（我们的NaN标记）
                          touchResponse.lineBarSpots!.removeWhere(
                            (spot) => spot.y.isNaN || spot.y == double.negativeInfinity
                          );
                          
                          // 只要有触摸响应且有有效点，就显示tooltip（处理问题1）
                          if (touchResponse.lineBarSpots!.isNotEmpty) {
                            // 鼠标移动、按下、拖动时都显示tooltip
                            if (event is FlPanStartEvent || 
                                event is FlTapDownEvent || 
                                event is FlPanUpdateEvent ||
                                event is FlLongPressStart ||
                                event is FlLongPressMoveUpdate ||
                                event is FlPointerHoverEvent) {
                              _showCustomTooltip(context, event, touchResponse, dataModel, isAutoRefreshEnabled);
                            } else if (event is FlPanEndEvent || 
                                      event is FlTapUpEvent || 
                                      event is FlPanCancelEvent ||
                                      event is FlLongPressEnd ||
                                      event is FlPointerExitEvent) {
                              // 隐藏tooltip
                              _hideCustomTooltip();
                            }
                          } else {
                            // 没有有效点时隐藏tooltip
                            _hideCustomTooltip();
                          }
                        } else {
                          // 没有触摸响应时隐藏tooltip
                          _hideCustomTooltip();
                        }
                      },
                      getTouchLineStart: (_, __) => -double.infinity,
                      getTouchLineEnd: (_, __) => double.infinity,
                      getTouchedSpotIndicator: 
                          (LineChartBarData barData, List<int> spotIndexes) {
                        // 预先检查barData是否有效
                        if (barData.spots.isEmpty) {
                          return [];
                        }
                        
                        return spotIndexes.map((spotIndex) {
                          // 安全检查：确保索引在有效范围内
                          if (spotIndex < 0 || spotIndex >= barData.spots.length) {
                            return TouchedSpotIndicatorData(
                              FlLine(color: Colors.transparent),
                              FlDotData(show: false),
                            );
                          }
                          
                          final spot = barData.spots[spotIndex];
                          // 如果值是NaN或极大负值（我们的NaN标记），不显示指示器
                          if (spot.y.isNaN || spot.y == double.negativeInfinity) {
                            return TouchedSpotIndicatorData(
                              FlLine(color: Colors.transparent),
                              FlDotData(show: false),
                            );
                          }
                          
                          // 获取更醒目的指示器样式
                          final color = barData.color ?? AppColors.contentColorYellow;
                          final expandedRadius = dataModel.getExpandedDotRadius(dotRadius);
                          
                          return TouchedSpotIndicatorData(
                            FlLine(
                              color: color.withOpacity(0.5),
                              strokeWidth: 2,
                              dashArray: [4, 4],
                            ),
                            FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: expandedRadius,
                                  color: color,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                          );
                        }).toList();
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        drawBelowEverything: true,
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: reservedLeftSize,
                          maxIncluded: false,
                          minIncluded: false,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: reservedBottomSize,
                          maxIncluded: false,
                          getTitlesWidget: (value, meta) => 
                              dataModel.getBottomTitleWidgets(
                                value, 
                                meta, 
                                fontSize: fontSize,
                                useOverviewMode: isAutoRefreshEnabled, // 传递当前组件的模式
                              ),
                        ),
                      ),
                    ),
                  ),
                  duration: Duration.zero,  // 设置动画持续时间为0，避免动画效果(也可以注释掉，产生动画效果)
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 添加这些辅助函数和变量到_LineChartContent类中
OverlayEntry? _tooltipOverlay;

// 显示自定义tooltip
void _showCustomTooltip(BuildContext context, FlTouchEvent touchEvent, LineTouchResponse touchResponse, ChartDataModel dataModel, bool isAutoRefreshEnabled) {
  // 关闭已存在的tooltip
  _hideCustomTooltip();
  
  // 确保有触摸到的点
  if (touchResponse.lineBarSpots == null || touchResponse.lineBarSpots!.isEmpty) {
    return;
  }
  
  // 从触摸事件中获取触摸位置
  Offset touchPosition;
  if (touchEvent is FlPanStartEvent) {
    touchPosition = touchEvent.localPosition;
  } else if (touchEvent is FlTapDownEvent) {
    touchPosition = touchEvent.localPosition;
  } else if (touchEvent is FlPanUpdateEvent) {
    touchPosition = touchEvent.localPosition;
  } else if (touchEvent is FlLongPressStart) {
    touchPosition = touchEvent.localPosition;
  } else if (touchEvent is FlLongPressMoveUpdate) {
    touchPosition = touchEvent.localPosition;
  } else if (touchEvent is FlPointerHoverEvent) {
    touchPosition = touchEvent.localPosition;
  } else {
    return; // 未知触摸事件类型
  }
  
  // 获取数据模型中的数据
  final int interval;
  // 安全地获取interval
  if (context.findAncestorWidgetOfExactType<LineChartSample>() != null) {
    interval = context.findAncestorWidgetOfExactType<LineChartSample>()?.interval ?? 10;
  } else {
    interval = 10; // 默认值
  }
  
  final Map<String, List<(DateTime, double)>> dataToUse = isAutoRefreshEnabled
      ? dataModel.getOverviewData(intervalSeconds: interval).map((k, v) => MapEntry(k, v.toList()))
      : dataModel.dataHistoryByKey.map((k, v) => MapEntry(k, v.toList()));
  
  // 使用FL Chart提供的触摸点信息
  final allTouchedSpots = touchResponse.lineBarSpots!;
  if (allTouchedSpots.isEmpty) {
    return;
  }
  
  // 直接使用FL Chart判定的最接近点
  // FL Chart已经通过其内部逻辑找到了距离触摸位置最近的点
  final touchedSpot = allTouchedSpots[0];
  
  // 获取数据键列表
  final keys = dataToUse.keys.toList();
  
  // 确保索引在有效范围内
  final barIndex = touchedSpot.barIndex;
  if (barIndex < 0 || barIndex >= keys.length) {
    return;
  }
  
  // 获取对应的数据键
  String closestKey = keys[barIndex];
  int closestSpotIndex = touchedSpot.spotIndex;
  
  // 获取数据点列表
  final data = dataToUse[closestKey];
  if (data == null || data.isEmpty || closestSpotIndex < 0 || closestSpotIndex >= data.length) {
    return;
  }
  
  // 获取数据点
  final point = data[closestSpotIndex];
  
  // 如果值无效，不显示tooltip
  if (point.$2.isNaN || point.$2 == double.negativeInfinity) {
    return;
  }
  
  // 计算重叠点
  int overlappingCount = 0;
  final timestamp = point.$1;
  final value = point.$2;
  
  // 统计重叠点数量
  for (final entry in dataToUse.entries) {
    for (final p in entry.value) {
      if (p.$1 == timestamp && p.$2 == value) {
        overlappingCount++;
      }
    }
  }
  
  // 获取当前点的颜色
  final color = dataModel.getColorForKey(closestKey);
  final formattedTime = DateFormat('HH:mm:ss').format(timestamp);
  String valueInfo = value.toStringAsFixed(2);
  if (isAutoRefreshEnabled) {
    valueInfo += ' (平均)';
  }
  
  // 构建自定义tooltip组件
  final tooltipWidget = Material(
    color: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 133, 133, 133).withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 第一行：key名称
          Text(
            closestKey,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2), // 最小间距
          // 第二行：数据信息
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 左侧：重叠点数量
              Text(
                overlappingCount > 1 ? '$overlappingCount个点' : '1个点',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              // 中间：时间
              Text(
                formattedTime,
                style: const TextStyle(
                  color: AppColors.contentColorGreen,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              // 右侧：值
              Text(
                valueInfo,
                style: const TextStyle(
                  color: AppColors.contentColorYellow,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  
  // 创建OverlayEntry
  _tooltipOverlay = OverlayEntry(
    builder: (overlayContext) {
      // 获取全局position
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return Container();
      
      final size = renderBox.size;
      final offset = renderBox.localToGlobal(Offset.zero);
      
      // 根据图表相对位置调整tooltip位置，放在触摸点上方
      double dx = touchPosition.dx + offset.dx - 80; // 默认居中
      double dy = touchPosition.dy + offset.dy - 60; // 默认在触摸点上方
      
      // 防止tooltip超出屏幕边界
      if (dx < offset.dx) dx = offset.dx;
      if (dx > offset.dx + size.width - 160) dx = offset.dx + size.width - 160;
      if (dy < offset.dy) dy = offset.dy;
      if (dy > offset.dy + size.height - 80) dy = offset.dy + size.height - 80;
      
      return Positioned(
        left: dx,
        top: dy,
        child: tooltipWidget,
      );
    },
  );
  
  // 添加到Overlay
  Overlay.of(context).insert(_tooltipOverlay!);
}

// 隐藏tooltip
void _hideCustomTooltip() {
  _tooltipOverlay?.remove();
  _tooltipOverlay = null;
}

// 添加可调整高度的列表组件
class _ResizableSeriesList extends StatefulWidget {
  final Widget child;
  final double initialHeight;
  final double maxHeight;
  final VoidCallback? onClose;

  const _ResizableSeriesList({
    required this.child,
    this.initialHeight = 80.0,
    this.maxHeight = 400.0,
    this.onClose,
  });

  @override
  State<_ResizableSeriesList> createState() => _ResizableSeriesListState();
}

class _ResizableSeriesListState extends State<_ResizableSeriesList> {
  late double _height;
  static const double _minHeight = 30.0; // 最小高度阈值
  static const double _dragHandleHeight = 16.0; // 拖动手柄高度
  bool _isDragging = false; // 添加拖动状态跟踪

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
  }

  void _updateHeight(double dy) {
    setState(() {
      _height = (_height + dy).clamp(_minHeight, widget.maxHeight);
      
      // 当高度接近最小值时，触发关闭回调
      if (_height <= _minHeight && widget.onClose != null) {
        widget.onClose!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(maxHeight: _height - _dragHandleHeight),
          child: SingleChildScrollView(
            child: widget.child,
          ),
        ),
        GestureDetector(
          onVerticalDragStart: (_) => setState(() => _isDragging = true),
          onVerticalDragEnd: (_) => setState(() => _isDragging = false),
          onVerticalDragCancel: () => setState(() => _isDragging = false),
          onVerticalDragUpdate: (details) => _updateHeight(details.delta.dy),
          child: Container(
            height: _dragHandleHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // 去掉拖动时的高亮渐变效果
            ),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _isDragging 
                  ? AppColors.contentColorYellow 
                  : AppColors.contentColorYellow.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
                // 去掉拖动时的阴影效果
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 添加_FullScreenWebView组件
// 全屏网页视图（仅非Web平台）
class _FullScreenWebView extends StatefulWidget {
  final String title;
  final String htmlUrl;

  const _FullScreenWebView({
    required this.title,
    required this.htmlUrl,
  });

  @override
  State<_FullScreenWebView> createState() => _FullScreenWebViewState();
}

class _FullScreenWebViewState extends State<_FullScreenWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    
    // 从HtmlChartManager获取或创建控制器，并正确处理类型
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.htmlUrl));
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.contentColorYellow,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.contentColorYellow),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // 添加刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.contentColorYellow),
            onPressed: () => _controller.reload(),
          ),
          // 添加全屏/退出全屏切换按钮
          IconButton(
            icon: const Icon(Icons.fullscreen_exit, color: AppColors.contentColorYellow),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.contentColorYellow,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '正在加载网页，请稍候...',
                    style: TextStyle(
                      color: AppColors.contentColorYellow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
