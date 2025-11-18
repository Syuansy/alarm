// 组按钮卡GroupButtonCard

import 'package:flutter/material.dart';
import 'package:alarm_front/util/shared_data_service.dart';
import 'package:alarm_front/util/simple_alarm_service.dart';
import 'package:alarm_front/util/alarm_cooling_manager.dart';
import 'package:alarm_front/config/chart_config.dart';
import 'package:alarm_front/presentation/samples/chart_samples.dart';

class GroupButtonCard extends StatefulWidget {
  const GroupButtonCard({Key? key}) : super(key: key);

  @override
  State<GroupButtonCard> createState() => _GroupButtonCardState();
}

class _GroupButtonCardState extends State<GroupButtonCard> {
  // 维护一个Map存储按钮状态：key是组名，value是{status, color, selected}
  Map<String, Map<String, dynamic>> _buttonStates = {};
  
  // 共享数据服务
  final SharedDataService _dataService = SharedDataService();
  
  // 报警服务
  final SimpleAlarmService _alarmService = SimpleAlarmService();
  
  // 报警冷却管理器
  final AlarmCoolingManager _coolingManager = AlarmCoolingManager();

  // 是否已显示过配置警告
  final Map<String, bool> _configWarningShown = {};

  @override
  void initState() {
    super.initState();
    
    // 添加组状态监听器
    _dataService.addGroupStateListener(_handleGroupStateUpdate);
    
    // 添加报警监听器
    _dataService.addAlarmListener(_handleAlarmMessage);
  }
  
  @override
  void dispose() {
    // 移除组状态监听器
    _dataService.removeGroupStateListener(_handleGroupStateUpdate);
    
    // 移除报警监听器
    _dataService.removeAlarmListener(_handleAlarmMessage);
    super.dispose();
  }
  
  // 处理组状态更新
  void _handleGroupStateUpdate(Map<String, Map<String, dynamic>> groupStates) {
    // 只更新状态，不再检测异常
    setState(() {
      _buttonStates = groupStates;
    });
  }
  
  // 处理报警消息
  void _handleAlarmMessage(Map<String, dynamic> alarmMessage) async {
    try {
      if (alarmMessage['type'] == 'alarm' && alarmMessage['data'] != null) {
        final alarmData = alarmMessage['data'] as Map<String, dynamic>;
        final alarmId = alarmData['id'] as int;
        final alarmType = alarmData['alarm_type'] as String;
        final startTime = alarmData['start_time'] as String;
        
        // 检查报警冷却状态
        final shouldTrigger = await _coolingManager.shouldTriggerAlarm(alarmId);
        
        if (shouldTrigger) {
          // 统一的报警格式: title=Alarm, subtitle="$alarm_type $start_time"
          await _alarmService.triggerFullAlarm(
            title: 'Alarm',
            subtitle: '$alarmType $startTime',
          );
          
          debugPrint('<Info> 已触发后端报警: $alarmType, 时间: $startTime, ID: $alarmId');
        } else {
          debugPrint('<Info> 报警在冷却期内，不触发: $alarmType, ID: $alarmId');
        }
      }
    } catch (e) {
      debugPrint('<Error> 处理报警消息失败: $e');
    }
  }
  
  // 切换按钮选中状态并重新加载图表配置
  void _toggleSelection(String groupName) async {
    // 切换按钮选中状态
    _dataService.toggleGroupSelection(groupName);
    
    // 获取当前选中的组名
    final selectedGroup = _dataService.selectedGroupName;
    
    if (selectedGroup != null) {
      // 检查配置是否存在
      if (!ChartConfigManager.hasGroup(selectedGroup) && !_configWarningShown[selectedGroup]!) {
        // 显示警告消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('没有找到$selectedGroup的配置，当前展示${ChartConfigManager.defaultGroup}的配置'),
            duration: const Duration(seconds: 3),
          ),
        );
        _configWarningShown[selectedGroup] = true;
      }
    }
    
    // 重新加载图表配置
    await ChartSamples.reloadForGroup(selectedGroup);
  }

  @override
  Widget build(BuildContext context) {
    // 获取所有要显示的按钮组名列表
    final visibleGroups = _buttonStates.keys.toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 靠左对齐
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.start, // 靠左对齐
                  children: visibleGroups.map((groupName) {
                    final buttonState = _buttonStates[groupName]!;
                    final bool isSelected = buttonState['selected'] as bool;
                    final Color buttonColor = buttonState['color'] as Color;
                    
                    // 确保已初始化警告状态跟踪
                    _configWarningShown[groupName] ??= false;
                    
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _toggleSelection(groupName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: buttonColor.withOpacity(0.8),
                          border: Border.all(
                            color: isSelected ? Colors.amber : Colors.transparent,
                            width: 5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          groupName,
                          style: const TextStyle(
                            fontSize: 16, 
                            color: Colors.white,
                            fontWeight: FontWeight.w600
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // 图例
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,  // 居中对齐
                children: [
                  _LegendDot(color: Colors.blue),
                  const SizedBox(width: 4),
                  const Text('running', style: TextStyle(fontSize: 12, color: Colors.white)),
                  const SizedBox(width: 16),
                  _LegendDot(color: Colors.red),
                  const SizedBox(width: 4),
                  const Text('abnormal', style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
} 