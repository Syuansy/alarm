import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:alarm_front/presentation/resources/app_colors.dart';
import 'package:alarm_front/presentation/resources/app_dimens.dart';
import 'package:alarm_front/presentation/pages/monitor_models.dart';
import 'package:alarm_front/presentation/pages/monitor_form_page.dart';
import 'package:alarm_front/presentation/widgets/monitor_card.dart';
import 'package:alarm_front/util/monitor_status_service.dart';
import 'package:alarm_front/util/monitor_item_notifier.dart';
import 'package:alarm_front/util/monitor_local_storage.dart';

class MonitorPage extends StatefulWidget {
  static const String route = '/monitor';
  
  const MonitorPage({Key? key}) : super(key: key);

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> with WidgetsBindingObserver {
  List<MonitorItemNotifier> monitorItemNotifiers = [];
  
  // 轮询相关
  Timer? _pollingTimer;
  final MonitorStatusService _statusService = MonitorStatusService();
  bool _isPageVisible = true;
  bool _isPollingActive = false;
  
  // 动态轮询间隔（基于监控频率的最小值）
  Duration _currentPollingInterval = const Duration(seconds: 5);
  
  // 本地存储服务
  MonitorLocalStorage? _localStorage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 初始化本地存储并加载数据
    _initializeStorage();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    
    // 清理MonitorItemNotifier资源
    for (final notifier in monitorItemNotifiers) {
      notifier.dispose();
    }
    monitorItemNotifiers.clear();
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 根据应用生命周期状态调整轮询
    switch (state) {
      case AppLifecycleState.resumed:
        _isPageVisible = true;
        _startPolling();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _isPageVisible = false;
        _stopPolling();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// 初始化本地存储
  Future<void> _initializeStorage() async {
    try {
      _localStorage = await MonitorLocalStorage.getInstance();
      await _loadMonitorItems();
      
      // 启动轮询
      _startPolling();
    } catch (e) {
      debugPrint('<Error> 初始化存储失败: $e');
      // 如果存储初始化失败，加载默认样例
      _loadDefaultSamples();
      _startPolling();
    }
  }

  /// 从本地存储加载监控项目
  Future<void> _loadMonitorItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_localStorage == null) {
        debugPrint('<Warning> 本地存储未初始化，加载默认样例');
        _loadDefaultSamples();
        return;
      }

      // 从本地存储加载数据
      final storedItems = await _localStorage!.loadMonitorItems();
      
      List<MonitorItem> itemsToLoad;
      
      if (storedItems.isEmpty) {
        debugPrint('<Info> 本地存储为空，加载默认样例');
        itemsToLoad = _createDefaultSamples();
        // 自动保存默认样例到本地存储
        await _localStorage!.saveMonitorItems(itemsToLoad);
      } else {
        debugPrint('<Info> 从本地存储加载了${storedItems.length}个监控项目');
        itemsToLoad = storedItems;
      }

      setState(() {
        // 清除现有的notifiers
        for (final notifier in monitorItemNotifiers) {
          notifier.dispose();
        }
        monitorItemNotifiers.clear();
        
        // 为每个MonitorItem创建对应的MonitorItemNotifier
        monitorItemNotifiers.addAll(
          itemsToLoad.map((item) => MonitorItemNotifier(item)).toList()
        );
        _isLoading = false;
      });
      
      // 加载完监控项目后，重新计算轮询间隔
      _updatePollingInterval();
      
    } catch (e) {
      debugPrint('<Error> 加载监控项目失败: $e');
      _loadDefaultSamples();
    }
  }

  /// 加载默认样例（fallback方法）
  void _loadDefaultSamples() {
    final defaultItems = _createDefaultSamples();
    setState(() {
      // 清除现有的notifiers
      for (final notifier in monitorItemNotifiers) {
        notifier.dispose();
      }
      monitorItemNotifiers.clear();
      
      // 为每个MonitorItem创建对应的MonitorItemNotifier
      monitorItemNotifiers.addAll(
        defaultItems.map((item) => MonitorItemNotifier(item)).toList()
      );
      _isLoading = false;
    });
    
    // 加载完监控项目后，重新计算轮询间隔
    _updatePollingInterval();
  }
  
  /// 启动轮询
  void _startPolling() {
    if (!_isPageVisible || _isPollingActive) return;
    
    _isPollingActive = true;
    debugPrint('<Info> 启动监控状态轮询，间隔: ${_currentPollingInterval.inSeconds}秒');
    
    // 立即执行一次
    _pollMonitorStatus();
    
    // 启动定时器
    _pollingTimer = Timer.periodic(_currentPollingInterval, (timer) {
      _pollMonitorStatus();
    });
  }
  
  /// 停止轮询
  void _stopPolling() {
    if (!_isPollingActive) return;
    
    _isPollingActive = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('<Info> 停止监控状态轮询');
  }
  
  /// 更新轮询间隔（基于监控项目的最小频率）
  void _updatePollingInterval() {
    if (monitorItemNotifiers.isEmpty) {
      _currentPollingInterval = const Duration(seconds: 5);
      return;
    }
    
    // 找到最短的监控频率作为轮询间隔
    int minSeconds = 60; // 默认最大1分钟
    
    for (final notifier in monitorItemNotifiers) {
      int frequencySeconds;
      switch (notifier.monitorItem.frequency) {
        case MonitorFrequency.every1Second:
          frequencySeconds = 1;
          break;
        case MonitorFrequency.every5Seconds:
          frequencySeconds = 5;
          break;
        case MonitorFrequency.every10Seconds:
          frequencySeconds = 10;
          break;
        case MonitorFrequency.every1Minute:
          frequencySeconds = 60;
          break;
      }
      
      if (frequencySeconds < minSeconds) {
        minSeconds = frequencySeconds;
      }
    }
    
    // 轮询间隔设为最小监控频率的一半，但不少于1秒
    final pollingSeconds = (minSeconds / 2).ceil().clamp(1, 30);
    _currentPollingInterval = Duration(seconds: pollingSeconds);
    
    debugPrint('<Info> 更新轮询间隔: ${pollingSeconds}秒 (基于最小监控频率: ${minSeconds}秒)');
    
    // 如果正在轮询，重新启动以应用新间隔
    if (_isPollingActive) {
      _stopPolling();
      _startPolling();
    }
  }
  
  /// 执行监控状态轮询（精确更新，避免Grafana图表重新加载）
  Future<void> _pollMonitorStatus() async {
    if (!_isPageVisible || !mounted) return;
    
    try {
      final statusMap = await _statusService.getMonitorStatuses();
      
      if (!mounted) return;
      
      // 精确更新监控项目的状态和值，不触发整个Widget重建
      int updatedCount = 0;
      
      for (final notifier in monitorItemNotifiers) {
        final statusData = statusMap[notifier.monitorItem.id];
        
        if (statusData != null) {
          // 使用MonitorItemNotifier的精确更新方法
          // 这只会更新状态相关的ValueListenableBuilder，不会重建整个MonitorCard
          final currentData = notifier.value;
          bool needsUpdate = false;
          
          if (currentData.status != statusData.status || 
              currentData.monitorValue.displayText != statusData.value.displayText ||
              currentData.currentOverCount != statusData.currentOverCount) {
            
            notifier.updateStatusAndValue(
              statusData.status, 
              statusData.value, 
              currentOverCount: statusData.currentOverCount
            );
            needsUpdate = true;
            updatedCount++;
          }
          
          if (needsUpdate) {
            debugPrint('<Info> 精确更新监控状态: ${notifier.monitorItem.id} -> ${statusData.status.displayName}');
          }
        }
        // 注意：这里不处理未找到状态数据的情况，保持当前状态不变
      }
      
      if (updatedCount > 0) {
        debugPrint('<Info> 监控状态轮询完成: 更新了${updatedCount}个项目，共${statusMap.length}个项目返回');
      }
      
    } catch (e) {
      debugPrint('<Error> 轮询监控状态失败: $e');
    }
  }

  // 创建三个默认样例
  List<MonitorItem> _createDefaultSamples() {
    final now = DateTime.now();
    
    return [
      // 样例1：绝对阈值算法
      MonitorItem(
        id: 'sample_absolute_${now.millisecondsSinceEpoch}',
        title: '8inch触发率监测',
        description: '监测8inchPMT触发率的情况',
        key: 'top-PMT-dcr.VME1.triggerRate',
        algorithm: MonitorAlgorithm.absoluteThreshold,
        frequency: MonitorFrequency.every5Seconds,
        upperThreshold: 85.0,
        lowerThreshold: 0.0,
        consecutiveTriggerCount: 3,
        grafanaUrl: 'http://10.3.192.122:3000/d-solo/0c284af2/juno?orgId=1&from=now-2min&to=now&timezone=browser&var-namespace=juno&var-group=daq&refresh=5s&&panelId=1&kiosk&__feature.dashboardSceneSolo',
        createdTime: now.subtract(const Duration(days: 2, hours: 3)),
        monitorStatus: MonitorStatus.normal,
        monitorValue: MonitorValue(
          value: 42.35,
          timestamp: now.subtract(const Duration(seconds: 15)),
        ),
      ),
      
      // 样例2：3σ算法
      MonitorItem(
        id: 'sample_threesigma_${now.millisecondsSinceEpoch + 1}',
        title: '带宽监测',
        description: '基于3σ统计算法检测带宽异常波动',
        key: 'Rate_hit.bec.12',
        algorithm: MonitorAlgorithm.threeSigma,
        frequency: MonitorFrequency.every10Seconds,
        consecutiveTriggerCount: 5,
        grafanaUrl: 'http://10.3.192.122:3000/d-solo/0c284af2/juno?orgId=1&from=now-10m&to=now&timezone=browser&var-namespace=juno&var-group=daq&refresh=10s&&panelId=100&kiosk&__feature.dashboardSceneSolo',
        createdTime: now.subtract(const Duration(days: 1, hours: 12)),
        monitorStatus: MonitorStatus.keyNotFound,
        monitorValue: const MonitorValue(), // 无数据
      ),
      
      // 样例3：Informer算法
      MonitorItem(
        id: 'sample_informer_${now.millisecondsSinceEpoch + 2}',
        title: 'ctu监控',
        description: '使用AI深度学习模型监测ctu数值的异常状况',
        key: 'Rate_cd_raw.ctu',
        algorithm: MonitorAlgorithm.Informer,
        frequency: MonitorFrequency.every1Minute,
        consecutiveDeviationCount: 2,
        grafanaUrl: 'http://10.3.192.122:3000/d/15b64697-94c0-4653-a004-a1192c16af37/junodaq-oec-shiyuan5555-shiyuanshiyuan?orgId=1&from=now-15m&to=now&timezone=browser&var-namespace=juno&var-group=cc&refresh=5s&viewPanel=panel-124&kiosk&__feature.dashboardSceneSolo',
        createdTime: now.subtract(const Duration(hours: 8)),
        monitorStatus: MonitorStatus.valueGetFailed,
        monitorValue: MonitorValue(
          value: 1048576.0, // 1MB/s
          timestamp: now.subtract(const Duration(minutes: 2)),
        ),
      ),
    ];
  }

  /// 自动保存监控项目到本地存储
  Future<void> _saveMonitorItems() async {
    try {
      if (_localStorage == null) {
        debugPrint('<Warning> 本地存储未初始化，无法保存');
        return;
      }

      // 将当前的MonitorItemNotifier列表转换为MonitorItem列表
      final currentItems = monitorItemNotifiers
          .map((notifier) => notifier.monitorItem)
          .toList();

      // 保存到本地存储
      final success = await _localStorage!.saveMonitorItems(currentItems);
      
      if (success) {
        debugPrint('<Info> 监控项目已自动保存到本地存储');
      } else {
        debugPrint('<Error> 自动保存监控项目失败');
      }
    } catch (e) {
      debugPrint('<Error> 保存监控项目异常: $e');
    }
  }

  /// 添加新的监控项目（自动保存）
  Future<void> _addMonitorItem(MonitorItem item) async {
    setState(() {
      monitorItemNotifiers.add(MonitorItemNotifier(item));
    });
    
    // 自动保存到本地存储
    await _saveMonitorItems();
    _updatePollingInterval(); // 重新计算轮询间隔
    
    // 显示成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('监控项目 "${item.title}" 已添加并自动保存'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 删除监控项目（自动保存）
  Future<void> _removeMonitorItem(String itemId) async {
    // 找到要删除的项目信息（用于显示提示）
    final index = monitorItemNotifiers.indexWhere((notifier) => notifier.monitorItem.id == itemId);
    String itemTitle = '监控项目';
    
    if (index != -1) {
      itemTitle = monitorItemNotifiers[index].monitorItem.title;
      
      setState(() {
        // 先dispose再移除
        monitorItemNotifiers[index].dispose();
        monitorItemNotifiers.removeAt(index);
      });
      
      // 自动保存到本地存储
      await _saveMonitorItems();
      _updatePollingInterval(); // 重新计算轮询间隔
      
      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('监控项目 "$itemTitle" 已删除'),
            backgroundColor: AppColors.contentColorOrange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 编辑监控项目（自动保存）
  Future<void> _editMonitorItem(MonitorItem item) async {
    setState(() {
      final index = monitorItemNotifiers.indexWhere((notifier) => notifier.monitorItem.id == item.id);
      if (index != -1) {
        // 先dispose旧的notifier，再创建新的
        monitorItemNotifiers[index].dispose();
        monitorItemNotifiers[index] = MonitorItemNotifier(item);
      }
    });
    
    // 自动保存到本地存储
    await _saveMonitorItems();
    _updatePollingInterval(); // 重新计算轮询间隔
    
    // 显示成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('监控项目 "${item.title}" 已更新并自动保存'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 导航到表单页面
  void _navigateToForm([MonitorItem? editItem]) async {
    final result = await Navigator.push<MonitorItem>(
      context,
      MaterialPageRoute(
        builder: (context) => MonitorFormPage(editItem: editItem),
      ),
    );

    if (result != null) {
      if (editItem != null) {
        await _editMonitorItem(result);
      } else {
        await _addMonitorItem(result);
      }
    }
  }
  
  /// 重置为默认样例（清除本地存储）
  Future<void> _resetToDefaultSamples() async {
    try {
      if (_localStorage != null) {
        await _localStorage!.clearMonitorItems();
      }
      
      // 重新加载默认样例
      await _loadMonitorItems();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已重置为默认样例，本地存储已清除'),
            backgroundColor: AppColors.contentColorOrange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('<Error> 重置默认样例失败: $e');
    }
  }
  
  /// 显示重置确认对话框
  void _showResetConfirmDialog() {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.itemsBackground,
          title: Text(
            '重置确认',
            style: TextStyle(color: AppColors.mainTextColor1),
          ),
          content: Text(
            '确定要重置为默认样例吗？这将清除所有自定义的监控配置。',
            style: TextStyle(color: AppColors.mainTextColor1),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '取消',
                style: TextStyle(color: AppColors.mainTextColor2),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                _resetToDefaultSamples();
              },
              child: Text(
                '重置',
                style: TextStyle(color: AppColors.contentColorRed),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.itemsBackground,
        title: Text(
          'Monitor',
          style: TextStyle(
            color: AppColors.mainTextColor1,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // 重置按钮
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: AppColors.mainTextColor1,
            ),
            tooltip: '重置为默认样例',
            onPressed: _showResetConfirmDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : (monitorItemNotifiers.isEmpty
                ? _buildEmptyState()
                : _buildMonitorList()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// 构建加载状态UI
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            '正在加载监控配置...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.mainTextColor2,
            ),
          ),
        ],
      ),
    );
  }

  // 构建空状态UI
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.monitor_heart,
            size: 80,
            color: AppColors.mainTextColor2,
          ),
          const SizedBox(height: 24),
          Text(
            '暂无监控项目',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.mainTextColor2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '点击右下角的 + 按钮添加新的监控项目',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mainTextColor2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 构建监控项目列表 - 使用响应式网格布局
  Widget _buildMonitorList() {
    return MasonryGridView.builder(
      padding: const EdgeInsets.only(
        left: AppDimens.chartSamplesSpace,
        right: AppDimens.chartSamplesSpace,
        top: AppDimens.chartSamplesSpace,
        bottom: AppDimens.chartSamplesSpace + 68,
      ),
      crossAxisSpacing: AppDimens.chartSamplesSpace,
      mainAxisSpacing: AppDimens.chartSamplesSpace,
      itemCount: monitorItemNotifiers.length,
      itemBuilder: (context, index) {
        final itemNotifier = monitorItemNotifiers[index];
        return MonitorCard(
          // 使用稳定的Key确保MonitorCard不会因为列表顺序变化而重建
          key: ValueKey('monitor_card_${itemNotifier.monitorItem.id}'),
          itemNotifier: itemNotifier,
          onEdit: () => _navigateToForm(itemNotifier.monitorItem),
          onDelete: () => _showDeleteConfirmDialog(itemNotifier.monitorItem),
        );
      },
      gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 1000, // 每个卡片最大宽度600px
      ),
    );
  }

  // 显示删除确认对话框
  void _showDeleteConfirmDialog(MonitorItem item) {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.itemsBackground,
          title: Text(
            '确认删除',
            style: TextStyle(color: AppColors.mainTextColor1),
          ),
          content: Text(
            '确定要删除监控项目 "${item.title}" 吗？\n\n删除后将自动保存到本地存储。',
            style: TextStyle(color: AppColors.mainTextColor1),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '取消',
                style: TextStyle(color: AppColors.mainTextColor2),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                await _removeMonitorItem(item.id);
              },
              child: Text(
                '删除',
                style: TextStyle(color: AppColors.contentColorRed),
              ),
            ),
          ],
        );
      },
    );
  }
}
