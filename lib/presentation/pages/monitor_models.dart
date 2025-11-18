/// 监测算法类型枚举
enum MonitorAlgorithm {
  absoluteThreshold('绝对阈值'),
  threeSigma('3σ'),
  TimesNet('TimesNet'),
  FEDformer('FEDformer'),
  Autoformer('Autoformer'),
  LightTS('LightTS'),
  ETSformer('ETSformer'),
  Informer('Informer'),
  DLinear('DLinear'),
  Crossformer('Crossformer'),
  FiLM('FiLM'),
  Transformer('Transformer'),
  iTransformer('iTransformer'),
  MICN('MICN'),
  Pyraformer('Pyraformer'),
  Reformer('Reformer'),
  KANAD('KANAD');

  const MonitorAlgorithm(this.displayName);
  final String displayName;
  
  /// 是否为AI模型算法
  bool get isAIModel {
    return this != absoluteThreshold && this != threeSigma;
  }
}

/// 监测状态枚举
enum MonitorStatus {
  normal('正常'),
  keyNotFound('数据库中未找到key'),
  valueGetFailed('获取值失败'),
  alarmFailed('报警失败'),
  unknown('未知状态');

  const MonitorStatus(this.displayName);
  final String displayName;
}

/// 监测频率类型枚举
enum MonitorFrequency {
  every1Second('每1秒'),
  every5Seconds('每5秒'),
  every10Seconds('每10秒'),
  every1Minute('每1分钟');

  const MonitorFrequency(this.displayName);
  final String displayName;
}

/// 监测值数据模型
class MonitorValue {
  final double? value;
  final DateTime? timestamp;

  const MonitorValue({
    this.value,
    this.timestamp,
  });

  /// 格式化显示为 "value(time)" 格式
  String get displayText {
    if (value == null || timestamp == null) {
      return '暂无数据';
    }
    
    final timeStr = '${timestamp!.hour.toString().padLeft(2, '0')}:'
                   '${timestamp!.minute.toString().padLeft(2, '0')}:'
                   '${timestamp!.second.toString().padLeft(2, '0')}';
    
    return '${value!.toStringAsFixed(2)}($timeStr)';
  }

  /// 从Map创建MonitorValue
  factory MonitorValue.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MonitorValue();
    
    return MonitorValue(
      value: map['value']?.toDouble(),
      timestamp: map['timestamp'] != null 
          ? DateTime.parse(map['timestamp'])
          : null,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
}

/// Monitor项目数据模型
class MonitorItem {
  final String id;
  final String title;
  final String description;
  final String key;
  final MonitorAlgorithm algorithm;
  final MonitorFrequency frequency;
  final double? upperThreshold;
  final double? lowerThreshold;
  final int? consecutiveTriggerCount;
  final int? consecutiveDeviationCount;
  final String? grafanaUrl; // Grafana图表链接
  final DateTime createdTime;
  final MonitorStatus monitorStatus; // 监测状态
  final MonitorValue monitorValue; // 监测值

  MonitorItem({
    required this.id,
    required this.title,
    required this.description,
    required this.key,
    required this.algorithm,
    required this.frequency,
    this.upperThreshold,
    this.lowerThreshold,
    this.consecutiveTriggerCount,
    this.consecutiveDeviationCount,
    this.grafanaUrl,
    DateTime? createdTime,
    this.monitorStatus = MonitorStatus.unknown,
    this.monitorValue = const MonitorValue(),
  }) : createdTime = createdTime ?? DateTime.now();

  /// 从Map创建MonitorItem
  factory MonitorItem.fromMap(Map<String, dynamic> map) {
    return MonitorItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      key: map['key'] ?? '',
      algorithm: MonitorAlgorithm.values.firstWhere(
        (e) => e.name == map['algorithm'],
        orElse: () => MonitorAlgorithm.absoluteThreshold,
      ),
      frequency: MonitorFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => MonitorFrequency.every1Second,
      ),
      upperThreshold: map['upperThreshold']?.toDouble(),
      lowerThreshold: map['lowerThreshold']?.toDouble(),
      consecutiveTriggerCount: map['consecutiveTriggerCount']?.toInt(),
      consecutiveDeviationCount: map['consecutiveDeviationCount']?.toInt(),
      grafanaUrl: map['grafanaUrl'],
      createdTime: map['createdTime'] != null 
          ? DateTime.parse(map['createdTime'])
          : DateTime.now(),
      monitorStatus: MonitorStatus.values.firstWhere(
        (e) => e.name == map['monitorStatus'],
        orElse: () => MonitorStatus.unknown,
      ),
      monitorValue: MonitorValue.fromMap(map['monitorValue']),
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'key': key,
      'algorithm': algorithm.name,
      'frequency': frequency.name,
      'upperThreshold': upperThreshold,
      'lowerThreshold': lowerThreshold,
      'consecutiveTriggerCount': consecutiveTriggerCount,
      'consecutiveDeviationCount': consecutiveDeviationCount,
      'grafanaUrl': grafanaUrl,
      'createdTime': createdTime.toIso8601String(),
      'monitorStatus': monitorStatus.name,
      'monitorValue': monitorValue.toMap(),
    };
  }

  /// 创建副本
  MonitorItem copyWith({
    String? id,
    String? title,
    String? description,
    String? key,
    MonitorAlgorithm? algorithm,
    MonitorFrequency? frequency,
    double? upperThreshold,
    double? lowerThreshold,
    int? consecutiveTriggerCount,
    int? consecutiveDeviationCount,
    String? grafanaUrl,
    DateTime? createdTime,
    MonitorStatus? monitorStatus,
    MonitorValue? monitorValue,
  }) {
    return MonitorItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      key: key ?? this.key,
      algorithm: algorithm ?? this.algorithm,
      frequency: frequency ?? this.frequency,
      upperThreshold: upperThreshold ?? this.upperThreshold,
      lowerThreshold: lowerThreshold ?? this.lowerThreshold,
      consecutiveTriggerCount: consecutiveTriggerCount ?? this.consecutiveTriggerCount,
      consecutiveDeviationCount: consecutiveDeviationCount ?? this.consecutiveDeviationCount,
      grafanaUrl: grafanaUrl ?? this.grafanaUrl,
      createdTime: createdTime ?? this.createdTime,
      monitorStatus: monitorStatus ?? this.monitorStatus,
      monitorValue: monitorValue ?? this.monitorValue,
    );
  }
}