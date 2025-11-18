// 组表卡GroupTableCard

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:alarm_front/util/shared_data_service.dart';

class _GroupRunInfo {
  final String group;
  final String runNumber;
  final String startTime;
  final String stopTime;
  final String duration;
  final String state;  // 添加state字段
  
  const _GroupRunInfo({
    required this.group,
    required this.runNumber,
    required this.startTime,
    required this.stopTime,
    required this.duration,
    required this.state,   // 初始化state字段
  });
}

class GroupTableCard extends StatefulWidget {
  final List<String> groupList;
  const GroupTableCard({Key? key, required this.groupList}) : super(key: key);

  @override
  State<GroupTableCard> createState() => _GroupTableCardState();
}

class _GroupTableCardState extends State<GroupTableCard> {
  late Timer _timer;
  Map<String, _GroupRunInfo> _groupInfoMap = {};
  Map<String, Map<String, dynamic>> _groupRunInfos = {};
  Map<String, Map<String, dynamic>> _groupStates = {};
  bool _loading = true;
  
  // 共享数据服务
  final SharedDataService _dataService = SharedDataService();

  @override
  void initState() {
    super.initState();
    // 添加组状态和运行信息监听器
    _dataService.addGroupStateListener(_handleGroupStateUpdate);
    _dataService.addGroupRunInfoListener(_handleGroupRunInfoUpdate);
    
    // 开始定时更新UI（主要是用于更新运行时间）
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        // 更新运行中任务的持续时间
        _updateDurations();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    // 移除监听器
    _dataService.removeGroupStateListener(_handleGroupStateUpdate);
    _dataService.removeGroupRunInfoListener(_handleGroupRunInfoUpdate);
    super.dispose();
  }

  // 处理组状态更新
  void _handleGroupStateUpdate(Map<String, Map<String, dynamic>> groupStates) {
    setState(() {
      _groupStates = groupStates;
      _processGroupData();
      _loading = false;
    });
  }

  // 处理组运行信息更新
  void _handleGroupRunInfoUpdate(Map<String, Map<String, dynamic>> groupRunInfos) {
    setState(() {
      _groupRunInfos = groupRunInfos;
      _processGroupData();
      _loading = false;
    });
  }
  
  // 处理组数据，合并状态和运行信息
  void _processGroupData() {
    Map<String, _GroupRunInfo> newGroupInfoMap = {};
    
    // 处理所有有状态的组
    for (final groupName in _groupStates.keys) {
      final state = _groupStates[groupName]!['state'] as String;
      
      // 获取运行信息
      final runData = _groupRunInfos[groupName];
      
      String runNumber = '-';
      String startTime = '-';
      String stopTime = '-';
      String duration = '-';
      
      if (runData != null) {
        runNumber = runData['runNumber']?.toString() ?? '-';
        
        if (runData['startTime'] != null) {
          final startTimestamp = runData['startTime'] is int 
              ? runData['startTime'] as int 
              : int.tryParse(runData['startTime'].toString()) ?? 0;
          
          if (startTimestamp > 0) {
            startTime = _formatTimestamp(startTimestamp);
            
            // 检查stopTime：null、"null"字符串或其他falsy值都视为未停止
            var hasStopTime = runData['stopTime'] != null && 
                              runData['stopTime'] != "null" && 
                              runData['stopTime'].toString() != "0";
            
            if (!hasStopTime) {
              stopTime = '-';
              // 计算至今的持续时间
              final now = DateTime.now();
              final startDt = DateTime.fromMillisecondsSinceEpoch(startTimestamp);
              final diff = now.difference(startDt);
              duration = _formatDuration(diff);
            } else {
              final stopTimestamp = runData['stopTime'] is int 
                  ? runData['stopTime'] as int 
                  : int.tryParse(runData['stopTime'].toString()) ?? 0;
                  
              if (stopTimestamp > 0) {
                stopTime = _formatTimestamp(stopTimestamp);
                // 计算开始到结束的持续时间
                final startDt = DateTime.fromMillisecondsSinceEpoch(startTimestamp);
                final stopDt = DateTime.fromMillisecondsSinceEpoch(stopTimestamp);
                final diff = stopDt.difference(startDt);
                duration = _formatDuration(diff);
              }
            }
          }
        }
      }
      
      // 添加到Map
      newGroupInfoMap[groupName] = _GroupRunInfo(
        group: groupName,
        runNumber: runNumber,
        startTime: startTime,
        stopTime: stopTime,
        duration: duration,
        state: state,
      );
    }
    
    _groupInfoMap = newGroupInfoMap;
  }
  
  // 时间戳转为可读日期时间
  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${dt.year}/${_two(dt.month)}/${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}";
  }
  
  // 更新所有正在运行的任务的持续时间
  void _updateDurations() {
    Map<String, _GroupRunInfo> updatedMap = {};
    
    _groupInfoMap.forEach((group, info) {
      // 只更新没有stopTime的任务（正在运行的）
      if (info.stopTime == '-') {
        // 尝试解析startTime
        final pattern = RegExp(r'(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})');
        final match = pattern.firstMatch(info.startTime);
        
        if (match != null) {
          final year = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);
          final hour = int.parse(match.group(4)!);
          final minute = int.parse(match.group(5)!);
          final second = int.parse(match.group(6)!);
          
          final startDt = DateTime(year, month, day, hour, minute, second);
          final now = DateTime.now();
          final diff = now.difference(startDt);
          
          // 创建新的信息对象，更新duration
          updatedMap[group] = _GroupRunInfo(
            group: info.group,
            runNumber: info.runNumber,
            startTime: info.startTime,
            stopTime: info.stopTime,
            duration: _formatDuration(diff),
            state: info.state,
          );
        } else {
          updatedMap[group] = info;
        }
      } else {
        // 已停止的任务不需要更新
        updatedMap[group] = info;
      }
    });
    
    if (mounted) {
      setState(() {
        _groupInfoMap = updatedMap;
      });
    }
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';
  
  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // 获取要显示的组信息列表
    final List<_GroupRunInfo> groupInfoList = _groupInfoMap.values.toList();
    
    // 构建表格行
    final rows = <DataRow>[];
    for (final info in groupInfoList) {
      // 根据状态选择行颜色
      Color? rowColor;
      if (info.state == 'Running') {
        rowColor = Colors.blue.withOpacity(0.8); // 与按钮背景色保持一致
      } else if (info.state == 'Abnormal') {
        rowColor = Colors.red.withOpacity(0.8); // 与按钮背景色保持一致
      }
      
      rows.add(DataRow(
        color: rowColor != null ? MaterialStateProperty.all(rowColor) : null,
        cells: [
          DataCell(Center(child: Text(info.group, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)))),
          DataCell(Center(child: Text(info.runNumber, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))),
          DataCell(Center(child: Text(info.startTime, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))),
          DataCell(Center(child: Text(info.stopTime, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))),
          DataCell(Center(child: Text(info.duration, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))),
        ]
      ));
    }
    
    // 始终显示表格
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                groupInfoList.isEmpty 
                  ? "运行状态表 (当前无正在运行的任务)"
                  : "运行状态表", 
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold
                ),
              ),
              SizedBox(width: 12),
              if (_loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.white.withOpacity(0.2)),
                  dataRowColor: MaterialStateProperty.all(Colors.white.withOpacity(0.05)),
                  columnSpacing: 32,
                  dividerThickness: 0.5,
                  columns: const [
                    DataColumn(label: Center(child: Text('Group', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))), numeric: false, tooltip: 'Group'),
                    DataColumn(label: Center(child: Text('RunNumber', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))), numeric: false, tooltip: 'RunNumber'),
                    DataColumn(label: Center(child: Text('Run Start Time', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))), numeric: false, tooltip: 'Run Start Time'),
                    DataColumn(label: Center(child: Text('Run Stop Time', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))), numeric: false, tooltip: 'Run Stop Time'),
                    DataColumn(label: Center(child: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))), numeric: false, tooltip: 'Duration'),
                  ],
                  rows: rows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 