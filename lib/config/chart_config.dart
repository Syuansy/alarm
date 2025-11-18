import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// 内容项类 - 表示每个具体的图表/页面
class ContentItem {
  final String type;
  final String? title;
  final String? key;
  final int? interval;
  final String? abnormalCondition;
  final String? yAxis;
  final String? defaultDisplay;
  final String? htmlUrl;

  ContentItem({
    required this.type,
    this.title,
    this.key,
    this.interval,
    this.abnormalCondition,
    this.yAxis,
    this.defaultDisplay,
    this.htmlUrl,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      key: json['key'] ?? '',
      interval: json['interval'] ?? json['Interval'] ?? 1,
      abnormalCondition: json['abnormalCondition'] ?? json['Abnormal_Condition'] ?? '',
      yAxis: json['y_axis'] ?? '',
      defaultDisplay: json['default_display'] ?? '',
      htmlUrl: json['htmlUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'key': key,
      'interval': interval,
      'abnormalCondition': abnormalCondition,
      'y_axis': yAxis,
      'default_display': defaultDisplay,
      'htmlUrl': htmlUrl,
    };
  }
}

// 菜单栏组类 - 表示同一个menuBar下的所有内容
class MenuBarGroup {
  final String menuBar;
  final List<ContentItem> content;
  final String timePicker; // "0" 不显示时间选择器, "1" 显示时间选择器
  final String timeRange; // 默认时间范围
  final Map<String, String> varPicker; // 变量选择器配置

  MenuBarGroup({
    required this.menuBar,
    required this.content,
    this.timePicker = "0",
    this.timeRange = "10m",
    this.varPicker = const {},
  });

  factory MenuBarGroup.fromJson(Map<String, dynamic> json) {
    List<ContentItem> contentItems = [];
    if (json['content'] != null) {
      contentItems = (json['content'] as List)
          .map<ContentItem>((item) => ContentItem.fromJson(item))
          .toList();
    }
    
    // 处理 varPicker 配置
    Map<String, String> varPickerMap = {};
    if (json['varPicker'] != null && json['varPicker'] is Map) {
      final Map<String, dynamic> rawVarPicker = json['varPicker'];
      varPickerMap = rawVarPicker.map((key, value) => MapEntry(key, value.toString()));
    }
    
    return MenuBarGroup(
      menuBar: json['menuBar'] ?? 'Home',
      content: contentItems,
      timePicker: json['timePicker'] ?? "0",
      timeRange: json['timeRange'] ?? "10m",
      varPicker: varPickerMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menuBar': menuBar,
      'content': content.map((item) => item.toJson()).toList(),
      'timePicker': timePicker,
      'timeRange': timeRange,
      'varPicker': varPicker,
    };
  }
}

// 图表配置类 - 向后兼容的包装类
class ChartConfig {
  final String position;
  final String type;
  final String title;
  final String key;
  final int interval;
  final String abnormalCondition;
  final String yAxis;
  final String defaultDisplay;
  final String? htmlUrl;
  final String menuBar;

  ChartConfig({
    required this.position,
    required this.type,
    required this.title,
    required this.key,
    required this.interval,
    required this.abnormalCondition,
    required this.yAxis,
    required this.defaultDisplay,
    this.htmlUrl,
    required this.menuBar,
  });

  // 从ContentItem和menuBar创建ChartConfig，position自动计算
  factory ChartConfig.fromContentItem(
    ContentItem item, 
    String menuBar, 
    int position
  ) {
    return ChartConfig(
      position: position.toString(),
      type: item.type,
      title: item.title ?? '',
      key: item.key ?? '',
      interval: item.interval ?? 1,
      abnormalCondition: item.abnormalCondition ?? '',
      yAxis: item.yAxis ?? '',
      defaultDisplay: item.defaultDisplay ?? '',
      htmlUrl: item.htmlUrl,
      menuBar: menuBar,
    );
  }

  factory ChartConfig.fromJson(Map<String, dynamic> json) {
    return ChartConfig(
      position: json['position']?.toString() ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      key: json['key'] ?? '',
      interval: json['interval'] ?? json['Interval'] ?? 1,
      abnormalCondition: json['abnormalCondition'] ?? json['Abnormal_Condition'] ?? '',
      yAxis: json['y_axis'] ?? '',
      defaultDisplay: json['default_display'] ?? '',
      htmlUrl: json['htmlUrl'] ?? '',
      menuBar: json['menuBar'] ?? 'Home',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'position': position,
      'type': type,
      'title': title,
      'key': key,
      'interval': interval,
      'abnormalCondition': abnormalCondition,
      'y_axis': yAxis,
      'default_display': defaultDisplay,
      'htmlUrl': htmlUrl,
      'menuBar': menuBar,
    };
  }
  
  @override
  String toString() {
    return 'ChartConfig(position: $position, type: $type, title: $title, menuBar: $menuBar)';
  }
}

class ChartConfigManager {
  static List<ChartConfig>? _charts;
  static List<MenuBarGroup>? _menuBarGroups;
  static String? _currentGroup;
  static String? _defaultGroup;
  static Map<String, dynamic>? _fullConfigData;

  // 获取默认组名
  static String? get defaultGroup => _defaultGroup;
  
  // 获取当前选中的组名
  static String? get currentGroup => _currentGroup;
  
  // 设置当前选中的组
  static void setCurrentGroup(String? groupName) {
    if (groupName != _currentGroup) {
      _currentGroup = groupName;
      _charts = null; // 清空缓存，强制重新加载
      _menuBarGroups = null; // 清空新格式缓存
      debugPrint('<Info> 当前组已切换为: ${groupName ?? "默认组"}');
    }
  }
  
  // 检查组是否存在
  static bool hasGroup(String groupName) {
    return _fullConfigData?.containsKey(groupName) ?? false;
  }

  // 获取菜单栏组列表（新格式）
  static Future<List<MenuBarGroup>> loadMenuBarGroups() async {
    try {
      // 如果全局配置数据为空，先加载整个配置文件
      if (_fullConfigData == null) {
        await _loadFullConfig();
      }
      
      // 如果已有缓存且当前组未变化，直接返回缓存
      if (_menuBarGroups != null) {
        debugPrint('<Info> 使用缓存的菜单栏组配置: ${_menuBarGroups!.length}个组');
        return _menuBarGroups!;
      }

      // 确定要加载的组名
      String groupToLoad = _currentGroup ?? _defaultGroup ?? 'daq';
      
      // 如果指定的组不存在，使用默认组
      if (!_fullConfigData!.containsKey(groupToLoad)) {
        debugPrint('<Warn> 警告: 组 "$groupToLoad" 不存在，使用默认组 "$_defaultGroup"');
        groupToLoad = _defaultGroup ?? 'daq';
      }
      
      // 加载指定组的配置
      final List<dynamic> groupData = _fullConfigData![groupToLoad] ?? [];
      debugPrint('<Info> 从组 "$groupToLoad" 加载 ${groupData.length} 个菜单栏组配置');
      
      _menuBarGroups = groupData.map<MenuBarGroup>((groupJson) {
        return MenuBarGroup.fromJson(groupJson);
      }).toList();
      
      return _menuBarGroups ?? [];
    } catch (e) {
      debugPrint('<Error> 加载菜单栏组配置失败: $e');
      return [];
    }
  }

  static Future<List<ChartConfig>> loadChartConfigs() async {
    try {
      // 如果已有缓存，直接返回
      if (_charts != null) {
        debugPrint('<Info> 使用缓存的图表配置: ${_charts!.length}个图表');
        return _charts!;
      }

      // 加载菜单栏组配置
      final menuBarGroups = await loadMenuBarGroups();
      
      // 将新格式转换为向后兼容的ChartConfig列表
      List<ChartConfig> allCharts = [];
      int globalPosition = 1;
      
      for (var group in menuBarGroups) {
        for (int i = 0; i < group.content.length; i++) {
          final chartConfig = ChartConfig.fromContentItem(
            group.content[i], 
            group.menuBar, 
            globalPosition++
          );
          allCharts.add(chartConfig);
        }
      }
      
      _charts = allCharts;
      debugPrint('<Info> 转换生成 ${_charts!.length} 个图表配置');
      
      return _charts!;
    } catch (e) {
      debugPrint('<Error> 加载图表配置失败: $e');
      return [];
    }
  }

  // 加载完整配置文件
  static Future<void> _loadFullConfig() async {
    try {
      debugPrint('<Info> 加载完整配置文件...');
      String jsonString;
      
      // 尝试从资源包加载
      try {
        jsonString = await rootBundle.loadString('lib/config/chart_config.json');
        debugPrint('<Info> 从Asset资源包加载配置文件成功');
      } catch (e) {
        debugPrint('<Error> 从Asset资源包加载配置失败: $e');
        // 如果从资源包加载失败，尝试从文件系统加载
        final file = File('lib/config/chart_config.json');
        jsonString = await file.readAsString();
        debugPrint('<Info> 从文件系统加载配置文件成功');
      }
      
      // 解析JSON
      _fullConfigData = jsonDecode(jsonString);
      
      // 获取默认组
      _defaultGroup = _fullConfigData?['default'] as String?;
      debugPrint('<Info> 设置默认组: $_defaultGroup');
      
      // 如果没有设置当前组，使用默认组
      if (_currentGroup == null) {
        _currentGroup = _defaultGroup;
      }
      
    } catch (e) {
      debugPrint('<Error> 加载完整配置文件失败: $e');
      _fullConfigData = {};
    }
  }
  
  // 重新加载配置
  static Future<void> reloadConfig() async {
    _fullConfigData = null;
    _charts = null;
    _menuBarGroups = null;
    await _loadFullConfig();
  }
  
  // 根据menuBar获取对应的内容项
  static Future<List<ContentItem>> getContentByMenuBar(String menuBar) async {
    final menuBarGroups = await loadMenuBarGroups();
    
    for (var group in menuBarGroups) {
      if (group.menuBar == menuBar) {
        return group.content;
      }
    }
    
    return [];
  }

  // 保存图表配置（向后兼容方法，但功能受限）
  static Future<bool> saveChartConfig(String position, {
    String? title,
    String? key,
    int? interval,
    String? abnormalCondition,
    String? htmlUrl,
    String? menuBar,
  }) async {
    debugPrint('<Warn> 注意: 由于配置文件格式已更改，保存功能暂时不可用');
    debugPrint('<Info> 建议通过修改JSON配置文件来更新配置');
    return false;
  }
}