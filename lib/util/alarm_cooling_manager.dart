import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_platform/universal_platform.dart';
import 'dart:convert';

class AlarmCoolingManager {
  static final AlarmCoolingManager _instance = AlarmCoolingManager._internal();
  factory AlarmCoolingManager() => _instance;
  AlarmCoolingManager._internal();

  // 存储已触发的报警 ID 和触发时间
  final Map<int, DateTime> _triggeredAlarms = {};
  
  // 默认冷却时间（分钟）
  int _defaultCoolingMinutes = 10;

  /// 检查是否应该触发报警
  /// 返回 true 表示应该触发，false 表示在冷却期内
  Future<bool> shouldTriggerAlarm(int alarmId) async {
    final coolingMinutes = await _getCoolingTime();
    final now = DateTime.now();
    
    // 如果冷却时间设置为"从不"，则总是触发
    if (coolingMinutes == 0) {
      return true;
    }
    
    // 检查该 ID 是否已记录
    if (_triggeredAlarms.containsKey(alarmId)) {
      final lastTriggered = _triggeredAlarms[alarmId]!;
      final timeDiff = now.difference(lastTriggered).inMinutes;
      
      // 如果还在冷却期内，不触发
      if (timeDiff < coolingMinutes) {
        print('<Info> 报警 ID $alarmId 在冷却期内，剩余${coolingMinutes - timeDiff}分钟');
        return false;
      }
    }
    
    // 记录触发时间
    _triggeredAlarms[alarmId] = now;
    print('<Info> 报警 ID $alarmId 触发，冷却时间 $coolingMinutes 分钟');
    return true;
  }

  /// 从设置中获取冷却时间
  Future<int> _getCoolingTime() async {
    // Web端使用默认值
    if (UniversalPlatform.isWeb) {
      return _defaultCoolingMinutes;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('app_settings');
      
      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        
        // 获取Alarm分类下的报警冷却控制设置
        final alarmSettings = settingsMap['Alarm'] as Map<String, dynamic>?;
        if (alarmSettings != null) {
          final coolingControl = alarmSettings['报警冷却控制'] as Map<String, dynamic>?;
          if (coolingControl != null) {
            final coolingValue = coolingControl['dropdownValue'] as String?;
            return _parseCoolingValue(coolingValue);
          }
        }
      }
    } catch (e) {
      print('<Error> 获取冷却时间失败: $e');
    }
    
    return _defaultCoolingMinutes;
  }

  /// 解析冷却时间字符串为分钟数
  int _parseCoolingValue(String? value) {
    if (value == null) return _defaultCoolingMinutes;
    
    switch (value) {
      case '1min':
        return 1;
      case '5min':
        return 5;
      case '10min':
        return 10;
      case '30min':
        return 30;
      case '1h':
        return 60;
      case '从不':
        return 0; // 0 表示从不冷却，总是触发
      default:
        return _defaultCoolingMinutes;
    }
  }

  /// 清除所有冷却记录（用于测试或重置）
  void clearAllCooling() {
    _triggeredAlarms.clear();
    print('<Info> 已清除所有报警冷却记录');
  }

  /// 手动设置冷却时间（用于测试）
  void setDefaultCoolingMinutes(int minutes) {
    _defaultCoolingMinutes = minutes;
  }

  /// 获取当前冷却时间设置（用于调试）
  Future<String> getCurrentCoolingTimeString() async {
    final minutes = await _getCoolingTime();
    if (minutes == 0) return '从不';
    if (minutes == 60) return '1h';
    return '${minutes}min';
  }
}