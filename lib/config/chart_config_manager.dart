import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ChartConfigManager
///
/// 图表配置管理器，负责加载和管理基于组的图表配置。
///
/// 功能：
/// 1. 在程序启动时加载默认组的配置
/// 2. 当点击GroupButtonCard组件中不同的按钮时，加载对应组的配置
/// 3. 当未选中GroupButtonCard中的按钮时，展示默认组的配置
/// 4. 当GroupButtonCard中没有按钮时，展示默认组的配置
/// 5. 当选中的组在配置文件中不存在时，提供警告并展示默认组的配置
///
/// 配置文件格式：
/// {
///   "menuItems": ["Home", "Page1", ...],
///   "default": "daq",
///   "daq": [ ... 配置项 ... ],
///   "test": [ ... 配置项 ... ],
///   "spmt": [ ... 配置项 ... ]
/// }
///
/// 其中：
/// - menuItems: 菜单项列表
/// - default: 默认组名
/// - daq, test, spmt等: 不同组的配置项数组
class ChartConfigManager {
  // Singleton instance
  static final ChartConfigManager _instance = ChartConfigManager._internal();
  
  factory ChartConfigManager() => _instance;
  
  ChartConfigManager._internal();
  
  // Configuration data from JSON file
  Map<String, dynamic>? _configData;
  
  // Currently selected group
  String? _selectedGroup;
  
  // Default group from config
  String? _defaultGroup;
  
  // Get selected group configuration
  List<Map<String, dynamic>>? get currentConfig {
    if (_configData == null) return null;
    
    // If a group is selected and exists in config, return its config
    if (_selectedGroup != null && _configData!.containsKey(_selectedGroup)) {
      return List<Map<String, dynamic>>.from(_configData![_selectedGroup]);
    }
    
    // Otherwise return default group config
    if (_defaultGroup != null && _configData!.containsKey(_defaultGroup)) {
      return List<Map<String, dynamic>>.from(_configData![_defaultGroup]);
    }
    
    return null;
  }
  
  // Selected group name
  String? get selectedGroup => _selectedGroup;
  
  // Default group name
  String? get defaultGroup => _defaultGroup;
  
  // Check if a group exists in the configuration
  bool hasGroupConfig(String groupName) {
    if (_configData == null) return false;
    return _configData!.containsKey(groupName);
  }
  
  // Load configuration from JSON file
  Future<void> loadConfig() async {
    try {
      final jsonString = await rootBundle.loadString('lib/config/chart_config.json');
      _configData = json.decode(jsonString);
      _defaultGroup = _configData?['default'];
      debugPrint('<Info> Chart config loaded successfully. Default group: $_defaultGroup');
    } catch (e) {
      debugPrint('<Error> Error loading chart config: $e');
      _configData = null;
      _defaultGroup = null;
    }
  }
  
  // Set selected group
  void setSelectedGroup(String? groupName) {
    if (groupName == null || _configData == null) {
      _selectedGroup = null;
      return;
    }
    
    if (_configData!.containsKey(groupName)) {
      _selectedGroup = groupName;
      debugPrint('<Info> Selected group set to: $groupName');
    } else {
      _selectedGroup = null;
      debugPrint('<Warn> Warning: No configuration found for group: $groupName. Using default group.');
    }
    
    // Notify listeners that the configuration has changed
    _notifyConfigChanged();
  }
  
  // Reset to default group
  void resetToDefaultGroup() {
    _selectedGroup = null;
    debugPrint('<Info> Reset to default group: $_defaultGroup');
    
    // Notify listeners that the configuration has changed
    _notifyConfigChanged();
  }
  
  // Configuration change listeners
  final List<Function()> _configListeners = [];
  
  // Add config change listener
  void addConfigListener(Function() listener) {
    _configListeners.add(listener);
  }
  
  // Remove config change listener
  void removeConfigListener(Function() listener) {
    _configListeners.remove(listener);
  }
  
  // Notify all listeners about config changes
  void _notifyConfigChanged() {
    for (final listener in _configListeners) {
      listener();
    }
  }
} 