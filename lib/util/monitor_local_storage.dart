import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarm_front/presentation/pages/monitor_models.dart';

/// 监控项目本地存储服务
/// 自动区分Web端和移动端存储方式
class MonitorLocalStorage {
  static const String _storageKey = 'monitor_items_v1';
  static MonitorLocalStorage? _instance;
  SharedPreferences? _prefs;

  MonitorLocalStorage._internal();

  /// 获取单例实例
  static Future<MonitorLocalStorage> getInstance() async {
    if (_instance == null) {
      _instance = MonitorLocalStorage._internal();
      await _instance!._init();
    }
    return _instance!;
  }

  /// 初始化存储
  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('<Info> 本地存储初始化成功 (${kIsWeb ? "Web" : "Mobile"}端)');
    } catch (e) {
      debugPrint('<Error> 本地存储初始化失败: $e');
    }
  }

  /// 保存监控项目列表
  Future<bool> saveMonitorItems(List<MonitorItem> items) async {
    try {
      if (_prefs == null) {
        debugPrint('<Error> 存储未初始化');
        return false;
      }

      // 将MonitorItem列表转换为JSON
      final itemsJson = items.map((item) => item.toMap()).toList();
      final jsonString = json.encode(itemsJson);
      
      // 保存到本地存储
      final success = await _prefs!.setString(_storageKey, jsonString);
      
      if (success) {
        debugPrint('<Info> 成功保存${items.length}个监控项目到本地存储');
      } else {
        debugPrint('<Error> 保存监控项目到本地存储失败');
      }
      
      return success;
    } catch (e) {
      debugPrint('<Error> 保存监控项目异常: $e');
      return false;
    }
  }

  /// 加载监控项目列表
  Future<List<MonitorItem>> loadMonitorItems() async {
    try {
      if (_prefs == null) {
        debugPrint('<Error> 存储未初始化');
        return [];
      }

      // 从本地存储读取JSON字符串
      final jsonString = _prefs!.getString(_storageKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('<Info> 本地存储中没有找到监控项目数据');
        return [];
      }

      // 解析JSON
      final List<dynamic> itemsJson = json.decode(jsonString);
      final List<MonitorItem> items = itemsJson
          .map((itemMap) => MonitorItem.fromMap(itemMap as Map<String, dynamic>))
          .toList();
      
      debugPrint('<Info> 成功从本地存储加载${items.length}个监控项目');
      return items;
      
    } catch (e) {
      debugPrint('<Error> 加载监控项目异常: $e');
      return [];
    }
  }

  /// 清除所有监控项目数据
  Future<bool> clearMonitorItems() async {
    try {
      if (_prefs == null) {
        debugPrint('<Error> 存储未初始化');
        return false;
      }

      final success = await _prefs!.remove(_storageKey);
      
      if (success) {
        debugPrint('<Info> 成功清除本地存储的监控项目数据');
      } else {
        debugPrint('<Error> 清除本地存储数据失败');
      }
      
      return success;
    } catch (e) {
      debugPrint('<Error> 清除监控项目数据异常: $e');
      return false;
    }
  }

  /// 检查本地存储是否有数据
  Future<bool> hasStoredData() async {
    try {
      if (_prefs == null) return false;
      
      final jsonString = _prefs!.getString(_storageKey);
      return jsonString != null && jsonString.isNotEmpty;
    } catch (e) {
      debugPrint('<Error> 检查存储数据异常: $e');
      return false;
    }
  }

  /// 获取存储的数据大小（用于调试）
  Future<int> getStorageSize() async {
    try {
      if (_prefs == null) return 0;
      
      final jsonString = _prefs!.getString(_storageKey);
      return jsonString?.length ?? 0;
    } catch (e) {
      debugPrint('<Error> 获取存储大小异常: $e');
      return 0;
    }
  }

  /// 导出监控配置为JSON（用于备份）
  Future<String?> exportMonitorConfig() async {
    try {
      final items = await loadMonitorItems();
      if (items.isEmpty) return null;
      
      final exportData = {
        'version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'platform': kIsWeb ? 'web' : 'mobile',
        'items': items.map((item) => item.toMap()).toList(),
      };
      
      return json.encode(exportData);
    } catch (e) {
      debugPrint('<Error> 导出配置异常: $e');
      return null;
    }
  }

  /// 导入监控配置（用于恢复）
  Future<bool> importMonitorConfig(String configJson) async {
    try {
      final Map<String, dynamic> exportData = json.decode(configJson);
      final List<dynamic> itemsJson = exportData['items'] ?? [];
      
      final List<MonitorItem> items = itemsJson
          .map((itemMap) => MonitorItem.fromMap(itemMap as Map<String, dynamic>))
          .toList();
      
      return await saveMonitorItems(items);
    } catch (e) {
      debugPrint('<Error> 导入配置异常: $e');
      return false;
    }
  }
}