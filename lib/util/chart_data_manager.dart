import 'package:flutter/material.dart';
import 'package:alarm_front/presentation/samples/charts/line_chart_sample.dart';

/// 图表数据模型管理器单例类
/// 
/// 用于管理所有图表的数据模型，确保不同图表可以共享相同的数据模型实例
class ChartDataModelManager {
  // 单例实例
  static final ChartDataModelManager _instance = ChartDataModelManager._internal();
  
  // 工厂构造函数返回单例实例
  factory ChartDataModelManager() {
    return _instance;
  }
  
  // 私有构造函数
  ChartDataModelManager._internal();
  
  // 存储所有数据模型的Map，key是图表的正则表达式模式
  final Map<String, ChartDataModel> _dataModels = {};
  
  // 获取数据模型实例，如果不存在则创建
  ChartDataModel getDataModel(String pattern) {
    if (!_dataModels.containsKey(pattern)) {
      print('<Info> 创建新的数据模型: $pattern');
      final dataModel = ChartDataModel(pattern);
      _dataModels[pattern] = dataModel;
    } else {
      print('<Info> 使用已有数据模型: $pattern');
    }
    
    return _dataModels[pattern]!;
  }
  
  // 预加载所有可能的数据模型
  void preloadDataModels(List<String> patterns) {
    for (final pattern in patterns) {
      getDataModel(pattern);
    }
    print('<Info> 预加载了 ${patterns.length} 个数据模型');
  }
} 