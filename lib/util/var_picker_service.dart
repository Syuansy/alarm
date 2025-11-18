import 'package:flutter/material.dart';

/// 变量选择器服务
class VarPickerService extends ChangeNotifier {
  static final VarPickerService _instance = VarPickerService._internal();
  factory VarPickerService() => _instance;
  VarPickerService._internal();

  // 当前变量映射
  Map<String, String> _variables = {};
  
  Map<String, String> get variables => Map.unmodifiable(_variables);

  /// 初始化变量（只初始化那些还没有值的变量）
  void initVariables(Map<String, String> initialVariables) {
    bool hasChanges = false;
    for (final entry in initialVariables.entries) {
      if (_variables[entry.key] == null || _variables[entry.key]!.isEmpty) {
        _variables[entry.key] = entry.value;
        hasChanges = true;
      }
    }
    if (hasChanges) {
      notifyListeners();
    }
  }

  /// 更新单个变量
  void updateVariable(String key, String value) {
    if (_variables[key] != value) {
      _variables[key] = value;
      notifyListeners();
    }
  }

  /// 获取变量值
  String getVariable(String key) {
    return _variables[key] ?? '';
  }

  /// 替换URL中的变量占位符
  String replaceVariablesInUrl(String url) {
    String result = url;
    for (final entry in _variables.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  /// 批量替换多个URL中的变量占位符
  List<String> replaceVariablesInUrls(List<String> urls) {
    return urls.map((url) => replaceVariablesInUrl(url)).toList();
  }

  /// 清空所有变量
  void clearVariables() {
    if (_variables.isNotEmpty) {
      _variables.clear();
      notifyListeners();
    }
  }

  /// 检查是否有变量
  bool get hasVariables => _variables.isNotEmpty;

  /// 获取变量键列表
  List<String> get variableKeys => _variables.keys.toList();
}