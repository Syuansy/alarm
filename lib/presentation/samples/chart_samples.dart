import 'package:alarm_front/config/chart_config.dart';
import 'package:alarm_front/util/app_helper.dart';
import 'package:flutter/material.dart';
import 'package:alarm_front/util/websocket_manager.dart';
import 'package:alarm_front/util/chart_data_manager.dart';
import 'package:alarm_front/util/time_range_service.dart';

// import 'bar/bar_chart_sample1.dart';
// import 'bar/bar_chart_sample2.dart';
// import 'bar/bar_chart_sample3.dart';
// import 'bar/bar_chart_sample4.dart';
// import 'bar/bar_chart_sample5.dart';
// import 'bar/bar_chart_sample6.dart';
// import 'bar/bar_chart_sample7.dart';
// import 'bar/bar_chart_sample8.dart';
import 'chart_sample.dart';
import 'charts/line_chart_sample.dart' as line_chart_widget;
import 'charts/html_chart_sample.dart' as html_chart_widget;
import 'charts/bar_chart_sample3.dart' as bar_chart_widget;

import 'charts/pie_chart_sample2.dart';
// import 'pie/pie_chart_sample3.dart';
// import 'radar/radar_chart_sample1.dart';
// import 'scatter/scatter_chart_sample1.dart';
// import 'scatter/scatter_chart_sample2.dart';

class ConfigurableChartSample extends ChartSample {
  final String title;
  final String key;
  final int interval;
  final String abnormalCondition;
  final String menuBar;

  ConfigurableChartSample({
    required ChartType chartType,
    required String position,
    required WidgetBuilder builder,
    required this.title,
    required this.key,
    required this.interval,
    required this.abnormalCondition,
    required this.menuBar,
  }) : super(int.parse(position), builder) {
    _chartType = chartType;
  }

  late final ChartType _chartType;

  @override
  ChartType get type => _chartType;

  @override
  String get name => title;
}

class ChartSamples {
  static Map<ChartType, List<ChartSample>> _hardcodedSamples = {
    ChartType.line: [
      LineChartSample(12, (context) => const line_chart_widget.LineChartSample()),
    ],
    ChartType.pie: [
      PieChartSample(2, (context) => const PieChartSample2()),
    ],
    // 添加html类型的默认样本
    ChartType.html: [],
  };

  static Map<ChartType, List<ChartSample>> get samples => _samples ?? _hardcodedSamples;
  
  // 按menuBar分组的图表
  static Map<String, List<ChartSample>>? _menuBarSamples;
  static Map<String, List<ChartSample>> get menuBarSamples {
    if (_menuBarSamples == null) {
      _menuBarSamples = {};
      // 确保所有菜单项都有一个空列表
      for (String menuName in menuItems) {
        _menuBarSamples![menuName] = [];
      }
    }
    return _menuBarSamples!;
  }
  
  static Map<ChartType, List<ChartSample>>? _samples;
  
  // 是否已启动后台数据收集
  static bool _isBackgroundDataCollectionStarted = false;

  static Future<void> loadSamplesFromConfig() async {
    try {
      // 启动后台数据收集
      if (!_isBackgroundDataCollectionStarted) {
        WebSocketManager().startBackgroundDataCollection();
        _isBackgroundDataCollectionStarted = true;
        debugPrint('<Info> 已启动后台数据收集');
        
        // 预加载默认模式的数据模型
        ChartDataModelManager().getDataModel(r'^top-PMT-dcr\.VME[^.]+\.triggerRate$');
        debugPrint('<Info> 已预加载默认模式的数据模型');
      }
      
      // 使用新格式加载菜单栏组配置
      final menuBarGroups = await ChartConfigManager.loadMenuBarGroups();
      if (menuBarGroups.isEmpty) {
        debugPrint('<Warn> 没有找到有效的菜单栏组配置');
        return;
      }
      
      debugPrint('<Info> 成功加载 ${menuBarGroups.length} 个菜单栏组配置');
      
      final Map<ChartType, List<ChartSample>> loadedSamples = {
        // 初始化所有可能的图表类型，以确保它们在map中存在
        ChartType.line: [],
        ChartType.bar: [],
        ChartType.pie: [],
        ChartType.radar: [],
        ChartType.scatter: [],
        ChartType.html: [],
      };
      
      // 初始化按menuBar分组的样本Map
      final Map<String, List<ChartSample>> loadedMenuBarSamples = {};
      
      // 确保所有菜单项都有一个空列表
      for (String menuName in menuItems) {
        loadedMenuBarSamples[menuName] = [];
      }
      
      final List<String> chartKeyPatterns = [];
      int globalPosition = 1;  // 全局position计数器
      
      // 直接处理按menuBar分组的配置
      for (final group in menuBarGroups) {
        final String menuBar = group.menuBar;
        
        // 如果menuBar不在menuItems中，则跳过该组
        if (menuBar.isEmpty || !menuItems.contains(menuBar)) {
          debugPrint('<Warn> 跳过菜单栏组 $menuBar，因为不在菜单列表中');
          continue;
        }
        
        // 确保该menuBar在样本映射中存在
        if (!loadedMenuBarSamples.containsKey(menuBar)) {
          loadedMenuBarSamples[menuBar] = [];
        }
        
        debugPrint('<Info> 处理菜单栏组: $menuBar，包含 ${group.content.length} 个内容项');
        
        // 处理该组下的所有内容项
        for (int i = 0; i < group.content.length; i++) {
          final contentItem = group.content[i];
          
          ChartType chartType;
          WidgetBuilder builder;
          
          final String title = contentItem.title ?? '图表-${globalPosition}';
          final String position = globalPosition.toString();
          
          debugPrint('<Info> 处理内容项: position=$position, type=${contentItem.type}, title=$title, menuBar=$menuBar');
          
          // 收集图表Key模式，用于预加载数据模型
          if (contentItem.key != null && contentItem.key!.isNotEmpty) {
            chartKeyPatterns.add(contentItem.key!);
          }
          
          switch (contentItem.type) {
            case 'LineChart':
              chartType = ChartType.line;
              debugPrint('<Info> 创建LineChart: $title');
              final String? originalHtmlUrl = contentItem.htmlUrl?.isNotEmpty == true ? contentItem.htmlUrl : null;
              final String? htmlUrl = originalHtmlUrl != null 
                ? TimeRangeService().replaceAllPlaceholdersInUrl(originalHtmlUrl)
                : null;
              if (htmlUrl != null) {
                debugPrint('<Info> LineChart $title 包含htmlUrl: $htmlUrl');
              }
              builder = (context) => line_chart_widget.LineChartSample(
                title: title,
                chartKey: contentItem.key ?? '',
                interval: contentItem.interval ?? 1, 
                abnormalCondition: contentItem.abnormalCondition ?? '',
                yAxis: contentItem.yAxis ?? '',
                defaultDisplay: contentItem.defaultDisplay ?? '',
                htmlUrl: htmlUrl,
              );
              break;
            case 'PieChart':
              chartType = ChartType.pie;
              debugPrint('<Info> 创建PieChart: $title');
              builder = (context) => PieChartSample2(
                title: title,
                chartKey: contentItem.key ?? '',
                interval: contentItem.interval ?? 1,
                abnormalCondition: contentItem.abnormalCondition ?? ''
              );
              break;
            case 'BarChart':
              chartType = ChartType.bar;
              debugPrint('<Info> 创建BarChart: $title');
              final String? htmlUrl = contentItem.htmlUrl?.isNotEmpty == true ? contentItem.htmlUrl : null;
              if (htmlUrl != null) {
                debugPrint('<Info> BarChart $title 包含htmlUrl: $htmlUrl');
                builder = (context) => html_chart_widget.HtmlChartSample(
                  title: title,
                  htmlUrl: htmlUrl,
                );
              } else {
                builder = (context) => const bar_chart_widget.BarChartSample3();
              }
              break;
            case 'html':
              chartType = ChartType.html;
              debugPrint('<Info> 创建HTML图表: $title');
              final String htmlUrl = TimeRangeService().replaceAllPlaceholdersInUrl(
                contentItem.htmlUrl ?? 'http://localhost'
              );
              builder = (context) => html_chart_widget.HtmlChartSample(
                title: title,
                htmlUrl: htmlUrl,
              );
              break;
            case 'htmlPage':
              chartType = ChartType.html;
              debugPrint('<Info> 创建全屏HTML页面: $title');
              debugPrint('<Info> 全屏页面URL: ${contentItem.htmlUrl}');
              final String pageUrl = TimeRangeService().replaceAllPlaceholdersInUrl(
                contentItem.htmlUrl ?? 'http://localhost'
              );
              builder = (context) => html_chart_widget.FullPageHtmlSample(
                htmlUrl: pageUrl,
                key: ValueKey('html_page_${pageUrl.hashCode}'),
              );
              break;
            default:
              debugPrint('<Warn> 未知图表类型: ${contentItem.type}');
              globalPosition++; // 即使跳过也要增加position
              continue;
          }
          
          // 创建可配置图表样本
          final sample = ConfigurableChartSample(
            chartType: chartType,
            position: position,
            builder: builder,
            title: title,
            key: contentItem.key ?? '',
            interval: contentItem.interval ?? 1,
            abnormalCondition: contentItem.abnormalCondition ?? '',
            menuBar: menuBar,
          );
          
          // 将样本添加到对应图表类型的列表中
          loadedSamples[chartType]!.add(sample);
          
          // 添加到对应menuBar的列表中
          loadedMenuBarSamples[menuBar]!.add(sample);
          
          debugPrint('<Info> 添加样本到 ${chartType.name} 列表和 $menuBar 菜单');
          
          globalPosition++; // 增加全局position计数器
        }
        
        debugPrint('<Info> 菜单 $menuBar 处理完成，共 ${loadedMenuBarSamples[menuBar]!.length} 个图表');
      }
      
      // 预加载所有图表的数据模型
      if (chartKeyPatterns.isNotEmpty) {
        debugPrint('<Info> 预加载图表数据模型...');
        for (final pattern in chartKeyPatterns) {
          if (pattern.isNotEmpty) {
            ChartDataModelManager().getDataModel(pattern);
          }
        }
        debugPrint('<Info> 图表数据模型预加载完成');
      }
      
      // 更新全局样本映射
      _samples = loadedSamples;
      _menuBarSamples = loadedMenuBarSamples;
      
      // 统计总数
      int totalCharts = 0;
      for (var list in loadedSamples.values) {
        totalCharts += list.length;
      }
      
      debugPrint('<Info> 图表加载完成，总共加载了 $totalCharts 个图表');
      
    } catch (e) {
      debugPrint('<Error> 加载图表配置时出错: $e');
    }
  }
  
  // 重新加载图表配置（当选择不同的组时调用）
  static Future<void> reloadForGroup(String? groupName) async {
    // 设置ChartConfigManager的当前组
    ChartConfigManager.setCurrentGroup(groupName);
    
    // 清空现有图表
    _samples = null;
    _menuBarSamples = null;
    
    // 重新加载图表
    await loadSamplesFromConfig();
  }
  
  // 初始化图表（在app启动时调用）
  static Future<void> init() async {
    await loadSamplesFromConfig();
  }
}
