import 'package:flutter/material.dart';
import 'package:alarm_front/presentation/samples/chart_samples.dart';
import 'package:alarm_front/presentation/widgets/chart_holder.dart';
import 'package:alarm_front/presentation/samples/chart_sample.dart';
import 'package:alarm_front/util/shared_data_service.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';

import 'package:alarm_front/config/chart_config.dart';
import 'package:alarm_front/presentation/widgets/time_picker_widget.dart';
import 'package:alarm_front/presentation/widgets/var_picker_widget.dart';
import 'package:alarm_front/util/time_range_service.dart';
import 'package:alarm_front/util/var_picker_service.dart';

class MenuBarSamplesPage extends StatefulWidget {
  final String title;

  const MenuBarSamplesPage({
    super.key,
    required this.title,
  });

  @override
  State<MenuBarSamplesPage> createState() => _MenuBarSamplesPageState();
}

class _MenuBarSamplesPageState extends State<MenuBarSamplesPage> {
  // 共享数据服务
  final SharedDataService _dataService = SharedDataService();
  
  // 刷新计数器，用于强制刷新组件
  int _refreshCounter = 0;
  
  // 时间范围服务
  final TimeRangeService _timeRangeService = TimeRangeService();
  
  // 变量选择器服务
  final VarPickerService _varPickerService = VarPickerService();
  
  // 当前页面的菜单栏组配置
  MenuBarGroup? _currentMenuBarGroup;

  @override
  void initState() {
    super.initState();
    
    // 初始化上次选中的组名
    _lastSelectedGroup = _dataService.selectedGroupName;
    
    // 添加组状态监听器以便在组选择变化时刷新页面
    _dataService.addGroupStateListener(_handleGroupStateUpdate);
    
    // 加载当前页面的配置
    _loadMenuBarConfiguration();
  }
  
  @override
  void dispose() {
    // 移除组状态监听器
    _dataService.removeGroupStateListener(_handleGroupStateUpdate);
    super.dispose();
  }
  
  // 处理组状态更新
  void _handleGroupStateUpdate(Map<String, Map<String, dynamic>> groupStates) {
    // 获取当前选中的组
    final selectedGroup = _dataService.selectedGroupName;
    
    // 仅当选中组变化时才刷新页面
    if (selectedGroup != _lastSelectedGroup) {
      _lastSelectedGroup = selectedGroup;
      setState(() {
        _refreshCounter++;
      });
      // 重新加载配置
      _loadMenuBarConfiguration();
    }
  }
  
  // 存储上次选中的组名，用于比较是否发生变化
  String? _lastSelectedGroup;
  
  // 加载菜单栏配置
  Future<void> _loadMenuBarConfiguration() async {
    try {
      final menuBarGroups = await ChartConfigManager.loadMenuBarGroups();
      final targetGroup = menuBarGroups.firstWhere(
        (group) => group.menuBar == widget.title,
        orElse: () => MenuBarGroup(menuBar: widget.title, content: []),
      );
      
      if (mounted) {
        setState(() {
          _currentMenuBarGroup = targetGroup;
          // 初始化时间范围服务的默认值
          if (targetGroup.timeRange.isNotEmpty) {
            _timeRangeService.updateTimeRange(targetGroup.timeRange);
          }
          // 只初始化那些还没有值的变量，避免覆盖用户输入
          for (final entry in targetGroup.varPicker.entries) {
            final currentValue = _varPickerService.getVariable(entry.key);
            if (currentValue.isEmpty) {
              _varPickerService.updateVariable(entry.key, entry.value);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading menu bar configuration: $e');
    }
  }
  
  // 处理选择器变化（时间范围或变量）
  void _handlePickerChanged() {
    setState(() {
      _refreshCounter++;
    });
    // 触发图表重新加载
    ChartSamples.reloadForGroup(_dataService.selectedGroupName);
  }

  @override
  Widget build(BuildContext context) {
    // 通过 key 强制刷新整个组件树
    final key = ValueKey('menu_samples_${widget.title}_$_refreshCounter');
    
    // 获取当前菜单的图表样本
    final menuBarSamples = ChartSamples.menuBarSamples[widget.title] ?? [];

    if (menuBarSamples.isEmpty) {
      return _buildPageWithPickers(_buildEmptyPage());
    }

    return KeyedSubtree(
      key: key,
      child: _buildPageWithPickers(_buildSamplesList(menuBarSamples)),
    );
  }
  
  // 构建带选择器的页面（变量选择器 + 时间选择器）
  Widget _buildPageWithPickers(Widget content) {
    final shouldShowTimePicker = _currentMenuBarGroup?.timePicker == "1";
    final variables = _currentMenuBarGroup?.varPicker ?? {};
    
    // 如果都不显示，直接返回内容
    if (!shouldShowTimePicker && variables.isEmpty) {
      return content;
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选择器行（变量选择器 + 时间选择器）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Row(
            children: [
              // 左侧：变量选择器
              if (variables.isNotEmpty)
                VarPickerRow(
                  variables: variables,
                  onVariableChanged: _handlePickerChanged,
                ),
              
              // 占据剩余空间，将时间选择器推到右侧
              const Spacer(),
              
              // 右侧：时间选择器
              if (shouldShowTimePicker)
                SizedBox(
                  width: 120,
                  child: TimePickerWidget(
                    onTimeRangeChanged: _handlePickerChanged,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 图表内容 - 直接显示内容，不使用Flexible
        content,
      ],
    );
  }

  // 构建空页面
  Widget _buildEmptyPage() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '没有图表配置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请在配置文件中为"${widget.title}"菜单添加图表',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建图表列表 - 使用响应式网格布局
  Widget _buildSamplesList(List<ChartSample> samples) {
    // 确保按position排序
    final sortedSamples = List.from(samples)
      ..sort((a, b) => a.number.compareTo(b.number));

    return MasonryGridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedSamples.length,
      padding: const EdgeInsets.only(
        left: AppDimens.chartSamplesSpace,
        right: AppDimens.chartSamplesSpace,
        top: 8.0, // 减少顶部padding
        bottom: AppDimens.chartSamplesSpace + 68,
      ),
      crossAxisSpacing: AppDimens.chartSamplesSpace,
      mainAxisSpacing: AppDimens.chartSamplesSpace,
      itemBuilder: (BuildContext context, int index) {
        return ChartHolder(chartSample: sortedSamples[index]);
      },
      gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 600, // 每个图表最大宽度600px
      ),
    );
  }
} 