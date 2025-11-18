import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alarm_front/util/websocket_manager.dart';
import 'package:alarm_front/config/chart_config_manager.dart';

// 共享数据服务，用于管理和共享所有组件数据
class SharedDataService extends ChangeNotifier {
  static final SharedDataService _instance = SharedDataService._internal();
  factory SharedDataService() => _instance;
  
  // WebSocket管理器
  final WebSocketManager _wsManager = WebSocketManager();
  
  // 日志功能已移除，不再需要日志相关数据
  
  // 组状态数据
  final Map<String, Map<String, dynamic>> _groupStates = {};
  
  // 组运行信息
  final Map<String, Map<String, dynamic>> _groupRunInfos = {};
  
  // 检测器数据
  final Map<String, Map<String, int>> _detectors = {};
  
  // 各种数据监听器（移除了日志监听器）
  final List<Function(Map<String, Map<String, dynamic>>)> _groupStateListeners = [];
  final List<Function(Map<String, Map<String, dynamic>>)> _groupRunInfoListeners = [];
  final List<Function(Map<String, Map<String, int>>)> _detectorListeners = [];
  final List<Function(Map<String, dynamic>)> _alarmListeners = [];

  // 图表配置管理器
  final ChartConfigManager _configManager = ChartConfigManager();
  
  // 当前选中的组名
  String? _selectedGroupName;

  SharedDataService._internal() {
    // 注册WebSocket监听器
    _wsManager.addListener(_handleWebSocketMessage);
    // 初始化时加载配置
    _loadConfig();
  }

  // 处理WebSocket消息
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    // 不再处理日志消息，因为日志功能已合并到报警页面
    // 处理type="alarm"的WebSocket消息
    if (message['type'] == 'alarm') {
      debugPrint('<Info> 收到报警消息: ${message.toString()}');
      // 通知所有报警监听器
      for (var listener in _alarmListeners) {
        listener(message);
      }
    }
    // 处理type=3的WebSocket消息
    else if (message.containsKey('type') && message['type'] == 3) {
      if (message.containsKey('data')) {
        final data = message['data'];
        
        // 确保数据是Map类型
        if (data is Map<String, dynamic>) {
          // 处理组状态和运行信息
          final Map<String, Map<String, dynamic>> newGroupStates = {};
          final Map<String, Map<String, dynamic>> newGroupRunInfos = {};
          
          data.forEach((groupKey, groupData) {
            if (groupData is Map<String, dynamic>) {
              // 确保是组数据
              if (groupKey.startsWith('juno_')) {
                // 提取组名(去掉juno_前缀)
                final group = groupKey.substring(5);
                
                // 获取状态
                if (groupData.containsKey('state')) {
                  final state = groupData['state'] as String;
                  
                  // 如果状态不是ShutDown，保存组状态
                  if (state != 'ShutDown') {
                    final String newState = state == 'Running' ? 'Running' : 'Abnormal';
                    final color = state == 'Running' ? Colors.blue : Colors.red;
                    
                    newGroupStates[group] = {
                      'state': newState,
                      'color': color,
                      'selected': _groupStates[group]?['selected'] ?? false,
                    };
                  }
                }
                
                // 获取run信息
                if (groupData.containsKey('run') && groupData['run'] is Map<String, dynamic>) {
                  final runData = groupData['run'];
                  newGroupRunInfos[group] = runData as Map<String, dynamic>;
                }
              }
            }
          });
          
          // 更新组状态
          _groupStates.clear();
          _groupStates.addAll(newGroupStates);
          
          // 更新组运行信息
          _groupRunInfos.clear();
          _groupRunInfos.addAll(newGroupRunInfos);
          
          // 通知所有组状态监听器
          for (var listener in _groupStateListeners) {
            listener(_groupStates);
          }
          
          // 通知所有组运行信息监听器
          for (var listener in _groupRunInfoListeners) {
            listener(_groupRunInfos);
          }
          
          // 处理检测器数据
          if (data.containsKey('juno_daq')) {
            final junoData = data['juno_daq'];
            
            if (junoData != null && junoData.containsKey('GCUs')) {
              final gcus = junoData['GCUs'];
              
              if (gcus is Map<String, dynamic>) {
                final Map<String, Map<String, int>> newDetectors = {};
                
                gcus.forEach((detectorName, detectorData) {
                  if (detectorData is Map<String, dynamic>) {
                    final Map<String, int> tags = {};
                    
                    detectorData.forEach((tagName, tagValue) {
                      if (tagValue is int) {
                        tags[tagName] = tagValue;
                      } else if (tagValue is num) {
                        tags[tagName] = tagValue.toInt();
                      } else if (tagValue is String) {
                        try {
                          tags[tagName] = int.parse(tagValue);
                        } catch (e) {
                          // 无法解析为int，跳过此标签
                        }
                      }
                    });
                    
                    if (tags.isNotEmpty) {
                      newDetectors[detectorName] = tags;
                    }
                  }
                });
                
                // 更新检测器数据
                _detectors.clear();
                _detectors.addAll(newDetectors);
                
                // 通知所有检测器监听器
                for (var listener in _detectorListeners) {
                  listener(_detectors);
                }
              }
            }
          }
        }
      }
    }
  }

  // 日志相关方法已移除，因为日志功能已合并到报警页面

  // 获取组状态数据
  Map<String, Map<String, dynamic>> getGroupStates() {
    return Map.unmodifiable(_groupStates);
  }

  // 获取组运行信息
  Map<String, Map<String, dynamic>> getGroupRunInfos() {
    return Map.unmodifiable(_groupRunInfos);
  }

  // 获取检测器数据
  Map<String, Map<String, int>> getDetectors() {
    return Map.unmodifiable(_detectors);
  }

  // 日志监听器相关方法已移除

  // 添加组状态监听器
  void addGroupStateListener(Function(Map<String, Map<String, dynamic>>) listener) {
    _groupStateListeners.add(listener);
    // 立即触发一次监听器，提供现有数据
    listener(_groupStates);
  }

  // 移除组状态监听器
  void removeGroupStateListener(Function(Map<String, Map<String, dynamic>>) listener) {
    _groupStateListeners.remove(listener);
  }

  // 添加组运行信息监听器
  void addGroupRunInfoListener(Function(Map<String, Map<String, dynamic>>) listener) {
    _groupRunInfoListeners.add(listener);
    // 立即触发一次监听器，提供现有数据
    listener(_groupRunInfos);
  }

  // 移除组运行信息监听器
  void removeGroupRunInfoListener(Function(Map<String, Map<String, dynamic>>) listener) {
    _groupRunInfoListeners.remove(listener);
  }

  // 添加检测器监听器
  void addDetectorListener(Function(Map<String, Map<String, int>>) listener) {
    _detectorListeners.add(listener);
    // 立即触发一次监听器，提供现有数据
    listener(_detectors);
  }

  // 移除检测器监听器
  void removeDetectorListener(Function(Map<String, Map<String, int>>) listener) {
    _detectorListeners.remove(listener);
  }

  // 添加报警监听器
  void addAlarmListener(Function(Map<String, dynamic>) listener) {
    _alarmListeners.add(listener);
  }

  // 移除报警监听器
  void removeAlarmListener(Function(Map<String, dynamic>) listener) {
    _alarmListeners.remove(listener);
  }
  
  // 更新组按钮选中状态
  void toggleGroupSelection(String groupName) {
    if (_selectedGroupName == groupName) {
      // 如果已经选中，取消选择
      _selectedGroupName = null;
      
      // 重置配置到默认
      _configManager.resetToDefaultGroup();
    } else {
      // 选择新组
      _selectedGroupName = groupName;
      
      // 设置配置管理器的选中组
      _configManager.setSelectedGroup(groupName);
      
      // 如果组不存在于配置中，显示提示
      if (!_configManager.hasGroupConfig(groupName)) {
        debugPrint('<Warn> 没有找到$groupName的配置，当前展示${_configManager.defaultGroup}的配置');
      }
    }
    
    // 更新所有组状态的选择状态
    for (final name in _groupStates.keys) {
      _groupStates[name]!['selected'] = (name == _selectedGroupName);
    }
    
    // 通知监听器
    _notifyGroupStateListeners();
  }

  // 加载配置
  Future<void> _loadConfig() async {
    try {
      await _configManager.loadConfig();
      debugPrint('<Info> 配置已加载，默认组: ${_configManager.defaultGroup}');
    } catch (e) {
      debugPrint('<Error> 加载配置失败: $e');
    }
  }
  
  // 获取组状态
  Map<String, Map<String, dynamic>> get groupStates => _groupStates;
  
  // 检查是否有选中的组
  bool get hasSelectedGroup => _selectedGroupName != null;
  
  // 获取当前选中的组名
  String? get selectedGroupName => _selectedGroupName;
  
  // 获取默认组名
  String? get defaultGroupName => _configManager.defaultGroup;
  
  // 更新组状态
  void updateGroupState(String groupName, String state) {
    // 标准化组名 - 如果接收到的格式是"juno_xxx"，转换为"xxx"
    final normalizedGroupName = _normalizeGroupName(groupName);
    
    // 确定按钮颜色
    final Color buttonColor = state == 'Running' ? Colors.blue : Colors.red;
    
    // 更新或创建状态
    _groupStates[normalizedGroupName] = {
      'state': state,
      'color': buttonColor,
      'selected': normalizedGroupName == _selectedGroupName,
    };
    
    // 通知监听器
    _notifyGroupStateListeners();
  }
  
  // 将组名标准化（如 "juno_daq" 转换为 "daq"）
  String _normalizeGroupName(String groupName) {
    if (groupName.startsWith('juno_')) {
      return groupName.substring(5); // 移除"juno_"前缀
    }
    return groupName;
  }
  
  // 批量更新组状态
  void updateGroupStates(Map<String, Map<String, dynamic>> newStates) {
    for (final entry in newStates.entries) {
      final groupName = entry.key;
      final state = entry.value['state'] as String;
      updateGroupState(groupName, state);
    }
  }
  
  // 清空所有组状态
  void clearGroupStates() {
    _groupStates.clear();
    _selectedGroupName = null;
    _configManager.resetToDefaultGroup();
    _notifyGroupStateListeners();
  }
  
  // 组状态监听器
  // final List<Function(Map<String, Map<String, dynamic>>)> _groupStateListeners = [];
  
  // 通知所有监听器
  void _notifyGroupStateListeners() {
    for (final listener in _groupStateListeners) {
      listener(_groupStates);
    }
  }

  // 应用销毁时清理资源
  void dispose() {
    _wsManager.removeListener(_handleWebSocketMessage);
    _groupStateListeners.clear();
    _groupRunInfoListeners.clear();
    _detectorListeners.clear();
    super.dispose();
  }
} 