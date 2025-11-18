// 侧边栏列表名称

import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:alarm_front/urls.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// 菜单项列表，从配置文件加载
List<String> menuItems = [];

// 图标路径常量
class MenuIcons {
  static const String home = 'assets/icons/ic_home.svg';
  static const String page1 = 'assets/icons/ic_page1.svg';
  static const String page2 = 'assets/icons/ic_page2.svg';
  static const String page3 = 'assets/icons/ic_page3.svg';
  static const String page4 = 'assets/icons/ic_page4.svg';
  static const String page5 = 'assets/icons/ic_page5.svg';
  static const String page6 = 'assets/icons/ic_page6.svg';
  static const String page7 = 'assets/icons/ic_page7.svg';
  static const String page8 = 'assets/icons/ic_page8.svg';
  static const String page9 = 'assets/icons/ic_page9.svg';
  static const String page10 = 'assets/icons/ic_page10.svg';
  static const String page11 = 'assets/icons/ic_page11.svg';
  static const String page12 = 'assets/icons/ic_page12.svg';
  static const String logs = 'assets/icons/ic_logs.svg';
  static const String alarm = 'assets/icons/ic_alarm.svg';
  static const String monitor = 'assets/icons/ic_monitor.svg';
}

// 加载菜单项
Future<void> loadMenuItems() async {
  try {
    final String jsonString = await rootBundle.loadString('lib/config/chart_config.json');
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    
    if (jsonData.containsKey('menuItems') && jsonData['menuItems'] is List) {
      menuItems = List<String>.from(jsonData['menuItems']);
    } else {
      // 默认菜单项
      menuItems = [
        'Home',
        'Page1',
        'Page2',
        'Page3',
        'Page4',
        'Logs'
      ];
    }
    print('<Info> 已加载菜单项: $menuItems');
  } catch (e) {
    // 出错时使用默认值
    menuItems = [
      'Home',
      'Page1',
      'Page2',
      'Page3',
      'Page4',
      'Logs'
    ];
    print('<Warn> 加载菜单项出错，使用默认值: $e');
  }
}

enum ChartType { line, bar, pie, scatter, radar, html }

extension ChartTypeExtension on ChartType {
  String get displayName => '$simpleName';

  String get simpleName => switch (this) {
        ChartType.line => 'Line Chart',
        ChartType.bar => 'Bar Chart',
        ChartType.pie => 'Pie Chart',
        ChartType.scatter => 'Scatter Chart',
        ChartType.radar => 'Radar Chart',
        ChartType.html => 'HTML Content',
      };

  String get documentationUrl => Urls.getChartDocumentationUrl(this);

  String get assetIcon => AppAssets.getChartIcon(this);
}
