import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:alarm_front/urls.dart';
import 'package:alarm_front/presentation/pages/monitor_models.dart';

/// 监控状态服务 - 负责从后端获取实时监控状态
class MonitorStatusService {
  static final MonitorStatusService _instance = MonitorStatusService._internal();
  factory MonitorStatusService() => _instance;
  MonitorStatusService._internal();

  // API基础地址 - 从 Urls 动态获取
  static String get _baseUrl => Urls.alarmApiBase;

  /// 获取所有监控项目的实时状态
  Future<Map<String, MonitorStatusData>> getMonitorStatuses() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/monitor/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          final List<dynamic> statusList = jsonData['data'] ?? [];
          final Map<String, MonitorStatusData> statusMap = {};
          
          for (final item in statusList) {
            final statusData = MonitorStatusData.fromJson(item);
            statusMap[statusData.id] = statusData;
          }
          
          return statusMap;
        } else {
          debugPrint('<Error> 获取监控状态失败: ${jsonData['message']}');
          return {};
        }
      } else {
        debugPrint('<Error> 监控状态API请求失败: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      debugPrint('<Error> 获取监控状态异常: $e');
      return {};
    }
  }
}

/// 监控状态数据模型
class MonitorStatusData {
  final String id;
  final String key;
  final String algorithm;
  final MonitorStatus status;
  final MonitorValue value;
  final int currentOverCount;  // 当前连续过阈次数
  final double lastCheckTime;
  final int consecutiveTriggerCount; // 配置的连续触发次数

  const MonitorStatusData({
    required this.id,
    required this.key,
    required this.algorithm,
    required this.status,
    required this.value,
    required this.currentOverCount,
    required this.lastCheckTime,
    required this.consecutiveTriggerCount,
  });

  /// 从JSON创建MonitorStatusData
  factory MonitorStatusData.fromJson(Map<String, dynamic> json) {
    // 解析状态
    MonitorStatus status = MonitorStatus.unknown;
    final statusStr = json['status'] as String?;
    if (statusStr != null) {
      switch (statusStr) {
        case 'normal':
          status = MonitorStatus.normal;
          break;
        case 'keyNotFound':
          status = MonitorStatus.keyNotFound;
          break;
        case 'valueGetFailed':
          status = MonitorStatus.valueGetFailed;
          break;
        case 'alarmFailed':
          status = MonitorStatus.alarmFailed;
          break;
        default:
          status = MonitorStatus.unknown;
      }
    }

    // 解析监控值
    MonitorValue value = const MonitorValue();
    final valueNum = json['value'] as num?;
    final timestampStr = json['timestamp'] as String?;
    
    if (valueNum != null && timestampStr != null) {
      try {
        final timestamp = DateTime.parse(timestampStr);
        value = MonitorValue(
          value: valueNum.toDouble(),
          timestamp: timestamp,
        );
      } catch (e) {
        debugPrint('<Warning> 解析监控值时间戳失败: $e');
      }
    }

    return MonitorStatusData(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? '',
      algorithm: json['algorithm'] as String? ?? '',
      status: status,
      value: value,
      currentOverCount: json['current_over_count'] as int? ?? 0,
      lastCheckTime: (json['last_check_time'] as num?)?.toDouble() ?? 0.0,
      consecutiveTriggerCount: json['consecutive_trigger_count'] as int? ?? 3,
    );
  }
}