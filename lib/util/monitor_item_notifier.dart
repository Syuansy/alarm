import 'package:flutter/foundation.dart';
import 'package:alarm_front/presentation/pages/monitor_models.dart';

/// 监控项目状态通知器 - 支持精细化状态更新
class MonitorItemNotifier extends ValueNotifier<MonitorItemData> {
  MonitorItemNotifier(MonitorItem initialItem) 
      : super(MonitorItemData.fromMonitorItem(initialItem));

  /// 更新监控状态（不影响其他数据）
  void updateStatus(MonitorStatus newStatus) {
    if (value.status != newStatus) {
      value = value.copyWith(status: newStatus);
    }
  }

  /// 更新监控值（不影响其他数据）  
  void updateValue(MonitorValue newValue) {
    if (value.monitorValue.displayText != newValue.displayText) {
      value = value.copyWith(monitorValue: newValue);
    }
  }

  /// 同时更新状态、值和过阈次数
  void updateStatusAndValue(MonitorStatus newStatus, MonitorValue newValue, {int? currentOverCount}) {
    if (value.status != newStatus || 
        value.monitorValue.displayText != newValue.displayText ||
        (currentOverCount != null && value.currentOverCount != currentOverCount)) {
      value = value.copyWith(
        status: newStatus,
        monitorValue: newValue,
        currentOverCount: currentOverCount,
      );
    }
  }

  /// 更新过阈次数
  void updateOverCount(int newOverCount) {
    if (value.currentOverCount != newOverCount) {
      value = value.copyWith(currentOverCount: newOverCount);
    }
  }

  /// 获取完整的MonitorItem（用于不变的部分）
  MonitorItem get monitorItem => value.originalItem;
}

/// 监控项目数据 - 分离可变和不可变部分
class MonitorItemData {
  final MonitorItem originalItem; // 不可变的原始数据
  final MonitorStatus status;     // 可变的状态
  final MonitorValue monitorValue; // 可变的值
  final int currentOverCount;     // 当前连续过阈次数

  const MonitorItemData({
    required this.originalItem,
    required this.status,
    required this.monitorValue,
    required this.currentOverCount,
  });

  /// 从MonitorItem创建
  factory MonitorItemData.fromMonitorItem(MonitorItem item) {
    return MonitorItemData(
      originalItem: item,
      status: item.monitorStatus,
      monitorValue: item.monitorValue,
      currentOverCount: 0, // 初始化为0
    );
  }

  /// 创建副本（只更新可变部分）
  MonitorItemData copyWith({
    MonitorStatus? status,
    MonitorValue? monitorValue,
    int? currentOverCount,
  }) {
    return MonitorItemData(
      originalItem: originalItem,
      status: status ?? this.status,
      monitorValue: monitorValue ?? this.monitorValue,
      currentOverCount: currentOverCount ?? this.currentOverCount,
    );
  }

  /// 转换为完整的MonitorItem
  MonitorItem toMonitorItem() {
    return originalItem.copyWith(
      monitorStatus: status,
      monitorValue: monitorValue,
    );
  }
}