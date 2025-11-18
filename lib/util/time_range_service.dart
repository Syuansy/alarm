import 'package:flutter/material.dart';
import 'package:alarm_front/util/var_picker_service.dart';

/// 时间范围选择服务
class TimeRangeService extends ChangeNotifier {
  static final TimeRangeService _instance = TimeRangeService._internal();
  factory TimeRangeService() => _instance;
  TimeRangeService._internal();

  // 当前选中的时间范围
  String _selectedTimeRange = '10m';
  
  String get selectedTimeRange => _selectedTimeRange;

  // 时间范围选项映射
  static const Map<String, String> timeRangeOptions = {
    'Last 10min': '10m',
    'Last 30min': '30m',
    'Last 1h': '1h',
    'Last 6h': '6h',
    'Last 1day': '24h',
  };

  /// 获取显示文本对应的时间范围值
  String getTimeRangeValue(String displayText) {
    return timeRangeOptions[displayText] ?? '10m';
  }

  /// 获取时间范围值对应的显示文本
  String getDisplayText(String timeRangeValue) {
    return timeRangeOptions.entries
        .firstWhere((entry) => entry.value == timeRangeValue,
            orElse: () => const MapEntry('Last 10min', '10m'))
        .key;
  }

  /// 更新时间范围
  void updateTimeRange(String newTimeRange) {
    if (_selectedTimeRange != newTimeRange) {
      _selectedTimeRange = newTimeRange;
      notifyListeners();
    }
  }

  /// 替换URL中的timeRange占位符
  String replaceTimeRangeInUrl(String url) {
    return url.replaceAll('{timeRange}', _selectedTimeRange);
  }

  /// 批量替换多个URL中的timeRange占位符
  List<String> replaceTimeRangeInUrls(List<String> urls) {
    return urls.map((url) => replaceTimeRangeInUrl(url)).toList();
  }

  /// 替换URL中的所有占位符（时间范围 + 变量）
  String replaceAllPlaceholdersInUrl(String url) {
    // 先替换时间范围
    String result = replaceTimeRangeInUrl(url);
    
    // 再替换变量
    final varPickerService = VarPickerService();
    result = varPickerService.replaceVariablesInUrl(result);
    
    return result;
  }

  /// 批量替换多个URL中的所有占位符
  List<String> replaceAllPlaceholdersInUrls(List<String> urls) {
    return urls.map((url) => replaceAllPlaceholdersInUrl(url)).toList();
  }
}