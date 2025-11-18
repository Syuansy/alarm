import 'package:flutter/material.dart';
import 'package:alarm_front/config/app_config.dart';
import 'package:alarm_front/presentation/resources/app_colors.dart';
import 'package:alarm_front/util/web_title_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// 报警数据项的抽象类
abstract class AlarmItem {
  bool isExpanded = false;
  Widget build(BuildContext context, Function(AlarmItem) onTap);
}

// 单个报警项
class SingleAlarm extends AlarmItem {
  final Map<String, dynamic> alarm;
  final _AlarmPageState pageState;
  
  SingleAlarm(this.alarm, this.pageState);
  
  @override
  Widget build(BuildContext context, Function(AlarmItem) onTap) {
    return pageState._buildAlarmCard(context, alarm, null, onTap, this);
  }
}

// 合并的报警组
class MergedAlarmGroup extends AlarmItem {
  final List<Map<String, dynamic>> alarms;
  final _AlarmPageState pageState;
  
  MergedAlarmGroup(this.alarms, this.pageState);
  
  @override
  Widget build(BuildContext context, Function(AlarmItem) onTap) {
    // 按时间排序，取最新的作为展示
    alarms.sort((a, b) => (b['start_time'] ?? '').compareTo(a['start_time'] ?? ''));
    return pageState._buildAlarmCard(context, alarms.first, alarms.length, onTap, this);
  }
}

// 时间格式化函数
String formatAlarmTime(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return '';
  try {
    // 假设时间格式是 "2024-01-01 12:00:00"
    DateTime dateTime = DateTime.parse(timeStr);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  } catch (e) {
    return timeStr; // 如果解析失败，返回原字符串
  }
}

// 获取报警级别对应的日志等级数字
int getLogLevel(String? alarmLevel) {
  if (alarmLevel == null) return 1;
  switch (alarmLevel.toLowerCase()) {
    case '5':
      return 5; // Fatal
    case '4':
      return 4; // Fatal
    case 'critical':
    case 'alarm_lv1':
      return 5; // Fatal
    case 'warning':
    case 'alarm_lv2':
      return 3; // Warn
    case 'info':
      return 2; // Info
    default:
      return 1; // Debug
  }
}

// 获取日志等级颜色
Color getLevelColor(int level) {
  switch (level) {
    case 1: return Colors.orange; // Debug
    case 2: return Colors.green; // Info
    case 3: return Colors.yellow; // Warn
    case 4: return Colors.purple; // Error
    case 5: return Colors.red; // Fatal
    default: return Colors.grey;
  }
}

// 获取日志等级名称
String getLevelName(int level) {
  switch (level) {
    case 1: return 'Debug';
    case 2: return 'Info';
    case 3: return 'Warn';
    case 4: return 'Error';
    case 5: return 'Fatal';
    default: return 'Unknown';
  }
}

// 构建报警卡片（需要在类内部访问，所以移到类内部）

class AlarmPage extends StatefulWidget {
  static const String route = '/alarm';
  
  const AlarmPage({Key? key}) : super(key: key);

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> with TickerProviderStateMixin {
  String selectedTimeRange = 'Last 30min';
  String selectedAlarmSource = 'ALL';
  String selectedType = 'ALL';
  String selectedKeyword = '';
  List<Map<String, dynamic>> alarmData = [];
  List<AlarmItem> alarmItems = [];
  bool isLoading = false;
  
  // 分页相关状态
  int currentPage = 1;
  int totalPages = 1;
  int totalCount = 0;
  int pageSize = 100;
  
  // 页面跳转控制器
  final TextEditingController _pageJumpController = TextEditingController();
  
  // 关键词文本框控制器和历史记录
  final TextEditingController _keywordController = TextEditingController();
  List<String> _keywordHistory = [];
  
  // 选中状态管理
  AlarmItem? selectedItem;
  MergedAlarmGroup? expandedGroup;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  final List<String> timeRangeOptions = [
    'Last 30min',
    'Last 6h', 
    'Today',
    'Last 2days',
    'Last 7days'
  ];
  
  final List<String> alarmSourceOptions = [
    'ALL',
    'juno-Logs',
    'tao-Logs',
    'system',
    'dataMonitor',
    'Monitor-absThreshold',
    'Monitor-3Sigma',
    'Monitor-AI'
  ];
  
  List<String> typeOptions = [
    'ALL',
    // 动态添加的类型选项
  ];
  
  // 移除keywordOptions，改用历史记录

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    // 循环播放呼吸动画
    _glowController.repeat(reverse: true);
    
    // 初始加载数据
    _fetchAlarmData();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _keywordController.dispose();
    _pageJumpController.dispose();
    super.dispose();
  }

  // 添加关键词到历史记录
  void _addKeywordToHistory(String keyword) {
    if (keyword.trim().isEmpty) return;
    
    // 移除重复的关键词
    _keywordHistory.remove(keyword);
    // 添加到开头
    _keywordHistory.insert(0, keyword);
    // 只保留最近5个
    if (_keywordHistory.length > 5) {
      _keywordHistory = _keywordHistory.take(5).toList();
    }
  }

  // 将报警数据分组，相邻相同type的进行合并
  List<AlarmItem> _groupAlarmData(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];
    
    List<AlarmItem> items = [];
    List<Map<String, dynamic>> currentGroup = [data[0]];
    String currentType = data[0]['alarm_type'] ?? '';
    
    for (int i = 1; i < data.length; i++) {
      String type = data[i]['alarm_type'] ?? '';
      
      if (type == currentType) {
        // 相同类型，加入当前分组
        currentGroup.add(data[i]);
      } else {
        // 不同类型，结束当前分组
        if (currentGroup.length == 1) {
          items.add(SingleAlarm(currentGroup[0], this));
        } else {
          items.add(MergedAlarmGroup(currentGroup, this));
        }
        
        // 开始新分组
        currentGroup = [data[i]];
        currentType = type;
      }
    }
    
    // 处理最后一个分组
    if (currentGroup.length == 1) {
      items.add(SingleAlarm(currentGroup[0], this));
    } else {
      items.add(MergedAlarmGroup(currentGroup, this));
    }
    
    return items;
  }

  // 处理报警项点击事件
  void _handleAlarmItemTap(AlarmItem item) {
    setState(() {
      if (item is MergedAlarmGroup) {
        // 如果点击的是已展开的组，则折叠
        if (expandedGroup == item) {
          _collapseExpandedGroup();
        } else {
          // 先折叠之前展开的组
          if (expandedGroup != null) {
            _collapseExpandedGroup();
          }
          
          // 展开新的组
          final index = alarmItems.indexOf(item);
          if (index != -1) {
            alarmItems.removeAt(index);
            // 将组中的每个报警作为单独项插入
            for (int i = 0; i < item.alarms.length; i++) {
              alarmItems.insert(index + i, SingleAlarm(item.alarms[i], this));
            }
            expandedGroup = item;
            selectedItem = item;
          }
        }
      } else if (item is SingleAlarm) {
        // 检查是否属于展开的组
        if (expandedGroup != null && _isItemInExpandedGroup(item)) {
          // 属于展开组，保持组选中状态
          item.isExpanded = !item.isExpanded;
        } else {
          // 不属于展开组，选中单个项目
          if (expandedGroup != null) {
            _collapseExpandedGroup();
          }
          selectedItem = selectedItem == item ? null : item;
          item.isExpanded = !item.isExpanded;
        }
      }
    });
  }

  // 折叠已展开的组
  void _collapseExpandedGroup() {
    if (expandedGroup == null) return;
    
    // 找到展开组的第一个项目的索引
    int startIndex = -1;
    for (int i = 0; i < alarmItems.length; i++) {
      if (alarmItems[i] is SingleAlarm) {
        SingleAlarm singleItem = alarmItems[i] as SingleAlarm;
        if (expandedGroup!.alarms.contains(singleItem.alarm)) {
          startIndex = i;
          break;
        }
      }
    }
    
    if (startIndex >= 0) {
      // 移除展开的单个项目
      for (int i = 0; i < expandedGroup!.alarms.length; i++) {
        if (startIndex < alarmItems.length) {
          alarmItems.removeAt(startIndex);
        }
      }
      // 重新插入合并的组
      alarmItems.insert(startIndex, expandedGroup!);
    }
    
    expandedGroup = null;
    selectedItem = null;
  }

  // 检查单个项目是否属于展开的组
  bool _isItemInExpandedGroup(SingleAlarm item) {
    if (expandedGroup == null) return false;
    return expandedGroup!.alarms.contains(item.alarm);
  }

  // 构建报警卡片
  Widget _buildAlarmCard(BuildContext context, Map<String, dynamic> alarm, int? alarmsCount, Function(AlarmItem) onTap, [AlarmItem? currentAlarmItem]) {
    final bool isMerged = alarmsCount != null && alarmsCount > 1;
    final int logLevel = getLogLevel(alarm['alarm_level']);
    final Color levelColor = getLevelColor(logLevel);
    
    return GestureDetector(
      onTap: currentAlarmItem != null ? () {
        if (currentAlarmItem is SingleAlarm) {
          currentAlarmItem.isExpanded = !currentAlarmItem.isExpanded;
        }
        onTap(currentAlarmItem);
      } : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _buildCardWithGlow(levelColor, currentAlarmItem, alarm, alarmsCount, isMerged),
      ),
    );
  }

  // 构建带光晕效果的卡片
  Widget _buildCardWithGlow(Color levelColor, AlarmItem? currentAlarmItem, Map<String, dynamic> alarm, int? alarmsCount, bool isMerged) {
    // 判断是否应该显示光晕效果
    bool shouldGlow = false;
    
    if (selectedItem != null) {
      if (selectedItem is MergedAlarmGroup && expandedGroup != null) {
        // 展开的组中的所有项目都应该有光晕
        if (currentAlarmItem is SingleAlarm && _isItemInExpandedGroup(currentAlarmItem)) {
          shouldGlow = true;
        }
      } else if (selectedItem == currentAlarmItem) {
        // 单个选中的项目
        shouldGlow = true;
      }
    }

    Widget card = Container(
      decoration: BoxDecoration(
        color: levelColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: levelColor,
          width: shouldGlow ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: levelColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：报警来源、报警类型、开始时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 报警来源
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alarm['alarm_source'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // 报警类型
                Flexible(
                  child: Text(
                    alarm['alarm_type'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 开始时间
                Text(
                  formatAlarmTime(alarm['start_time']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 第二行：报警描述和计数（如果有）
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 报警描述，根据展开状态决定是否显示完整内容
                Expanded(
                  child: Text(
                    alarm['description'] ?? '',
                    maxLines: currentAlarmItem is SingleAlarm && currentAlarmItem.isExpanded ? null : 2,
                    overflow: currentAlarmItem is SingleAlarm && currentAlarmItem.isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                // 如果是合并报警，显示数量标识
                if (isMerged)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+$alarmsCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    // 如果需要光晕效果，包装在动画构建器中
    if (shouldGlow) {
      return AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                // 外层光晕效果 - 更淡、只在外部
                BoxShadow(
                  color: levelColor.withOpacity(_glowAnimation.value * 0.4),
                  blurRadius: 12 * _glowAnimation.value,
                  spreadRadius: 0, // 不向内扩散
                  offset: Offset.zero,
                ),
                BoxShadow(
                  color: levelColor.withOpacity(_glowAnimation.value * 0.2),
                  blurRadius: 20 * _glowAnimation.value,
                  spreadRadius: 0, // 不向内扩散
                  offset: Offset.zero,
                ),
              ],
            ),
            child: card,
          );
        },
      );
    }

    return card;
  }

  // 将显示文本转换为API参数
  String _getTimeRangeParam(String displayText) {
    switch (displayText) {
      case 'Last 30min':
        return '30min';
      case 'Last 6h':
        return '6h';
      case 'Today':
        return 'today';
      case 'Last 2days':
        return '2days';
      case 'Last 7days':
        return '7days';
      default:
        return '30min';
    }
  }

  // 获取报警数据
  Future<void> _fetchAlarmData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final timeParam = _getTimeRangeParam(selectedTimeRange);
      
      // 构建查询参数
      List<String> queryParams = [
        'limit=$pageSize',
        'page=$currentPage',
        'time_range=$timeParam'
      ];
      
      // 如果alarm_source不是ALL，添加alarm_source参数
      if (selectedAlarmSource != 'ALL' && selectedAlarmSource.isNotEmpty) {
        queryParams.add('alarm_source=$selectedAlarmSource');
      }
      
      // 如果alarm_type不是ALL，添加alarm_type参数
      if (selectedType != 'ALL' && selectedType.isNotEmpty) {
        queryParams.add('alarm_type=$selectedType');
      }
      
      // 获取文本框中的关键词
      String keyword = _keywordController.text.trim();
      if (keyword.isNotEmpty) {
        queryParams.add('keyword=$keyword');
        // 添加到历史记录
        _addKeywordToHistory(keyword);
      }
      
      final url = '${AppConfig().alarmHistoryUrl}?${queryParams.join('&')}';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          final data = List<Map<String, dynamic>>.from(jsonData['data']);
          
          // 解析分页信息
          final pagination = jsonData['pagination'];
          if (pagination != null) {
            totalPages = pagination['total_pages'] ?? 1;
            totalCount = pagination['total_count'] ?? 0;
          } else {
            // 兼容旧版本API
            totalPages = 1;
            totalCount = data.length;
          }
          
          // 动态更新报警类型选项
          Set<String> uniqueTypes = {'ALL'};
          for (var alarm in data) {
            String alarmType = alarm['alarm_type'] ?? '';
            if (alarmType.isNotEmpty) {
              uniqueTypes.add(alarmType);
            }
          }
          
          setState(() {
            alarmData = data;
            alarmItems = _groupAlarmData(data);
            typeOptions = uniqueTypes.toList();
            
            // 如果当前选中的类型不在新列表中，重置为ALL
            if (!typeOptions.contains(selectedType)) {
              selectedType = 'ALL';
            }
            
            // 清除选中状态
            selectedItem = null;
            expandedGroup = null;
          });
        } else {
          _showError('获取数据失败: ${jsonData['message']}');
        }
      } else {
        _showError('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _showError('请求失败: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 显示错误信息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // 分页相关方法
  void _goToPage(int page) {
    if (page >= 1 && page <= totalPages && page != currentPage && !isLoading) {
      setState(() {
        currentPage = page;
      });
      _fetchAlarmData();
    }
  }

  void _goToPreviousPage() {
    if (currentPage > 1) {
      _goToPage(currentPage - 1);
    }
  }

  void _goToNextPage() {
    if (currentPage < totalPages) {
      _goToPage(currentPage + 1);
    }
  }

  void _goToFirstPage() {
    _goToPage(1);
  }

  void _goToLastPage() {
    _goToPage(totalPages);
  }

  // 跳转到指定页面
  void _jumpToPage() {
    final pageText = _pageJumpController.text.trim();
    if (pageText.isEmpty) return;
    
    final page = int.tryParse(pageText);
    if (page != null && page >= 1 && page <= totalPages) {
      _goToPage(page);
      _pageJumpController.clear();
      // 隐藏键盘
      FocusScope.of(context).unfocus();
    } else {
      _showError('请输入有效的页码 (1-$totalPages)');
    }
  }

  // 重置分页状态
  void _resetPagination() {
    setState(() {
      currentPage = 1;
      totalPages = 1;
      totalCount = 0;
    });
  }

  // 构建关键词文本框
  Widget _buildKeywordTextField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: AppColors.itemsBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _keywordController,
              style: TextStyle(
                color: AppColors.mainTextColor1,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: '关键词搜索',
                hintStyle: TextStyle(
                  color: AppColors.mainTextColor2,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (value) {
                // 回车时触发搜索
                if (!isLoading) {
                  _resetPagination();
                  _fetchAlarmData();
                }
              },
            ),
          ),
          // 历史记录按钮
          if (_keywordHistory.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.history,
                color: AppColors.mainTextColor2,
                size: 20,
              ),
              offset: const Offset(0, 40),
              color: AppColors.itemsBackground,
              onSelected: (String value) {
                _keywordController.text = value;
              },
              itemBuilder: (BuildContext context) {
                return _keywordHistory.map((String keyword) {
                  return PopupMenuItem<String>(
                    value: keyword,
                    child: Text(
                      keyword,
                      style: TextStyle(
                        color: AppColors.mainTextColor1,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
        ],
      ),
    );
  }

  // 构建分页组件
  Widget _buildPaginationWidget() {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      // margin: const EdgeInsets.symmetric(horizontal: 8.0),
      // padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        // borderRadius: BorderRadius.circular(8),
        // border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          // 显示统计信息
          Text(
            '共 $totalCount 条记录，第 $currentPage/$totalPages 页',
            style: TextStyle(
              color: AppColors.mainTextColor2,
              fontSize: 12,
            ),
          ),
          // const SizedBox(height: 12),
          // 分页按钮区域
          Column(
            children: [
              // 主分页按钮行
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 首页按钮
                  _buildPageButton(
                    icon: Icons.first_page,
                    onPressed: currentPage > 1 ? _goToFirstPage : null,
                    tooltip: '首页',
                  ),
                  // const SizedBox(width: 8),
                  // 上一页按钮
                  _buildPageButton(
                    icon: Icons.chevron_left,
                    onPressed: currentPage > 1 ? _goToPreviousPage : null,
                    tooltip: '上一页',
                  ),
                  // const SizedBox(width: 16),
                  // 页码按钮
                  ..._buildPageNumbers(),
                  // const SizedBox(width: 16),
                  // 下一页按钮
                  _buildPageButton(
                    icon: Icons.chevron_right,
                    onPressed: currentPage < totalPages ? _goToNextPage : null,
                    tooltip: '下一页',
                  ),
                  // const SizedBox(width: 8),
                  // 末页按钮
                  _buildPageButton(
                    icon: Icons.last_page,
                    onPressed: currentPage < totalPages ? _goToLastPage : null,
                    tooltip: '末页',
                  ),
                ],
              ),
              // const SizedBox(height: 12),
              // 页面跳转输入行
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '跳转到',
                    style: TextStyle(
                      color: AppColors.mainTextColor2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 60,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.pageBackground,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: TextField(
                      controller: _pageJumpController,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: AppColors.mainTextColor1,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: currentPage.toString(),
                        hintStyle: TextStyle(
                          color: AppColors.mainTextColor2,
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        isCollapsed: true,
                      ),
                      onSubmitted: (_) => _jumpToPage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '页',
                    style: TextStyle(
                      color: AppColors.mainTextColor2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTap: _jumpToPage,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          '跳转',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建页码按钮
  Widget _buildPageButton({
    IconData? icon,
    String? text,
    VoidCallback? onPressed,
    bool isSelected = false,
    String? tooltip,
  }) {
    final widget = Material(
      color: isSelected 
          ? AppColors.primary 
          : (onPressed != null ? AppColors.itemsBackground : AppColors.borderColor),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: isSelected 
                      ? Colors.white 
                      : (onPressed != null ? AppColors.mainTextColor1 : AppColors.mainTextColor2),
                )
              : Text(
                  text ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected 
                        ? Colors.white 
                        : (onPressed != null ? AppColors.mainTextColor1 : AppColors.mainTextColor2),
                  ),
                ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: widget,
      );
    }
    return widget;
  }

  // 构建页码数字按钮
  List<Widget> _buildPageNumbers() {
    List<Widget> widgets = [];
    
    // 计算要显示的页码范围
    int start = (currentPage - 1).clamp(1, totalPages);
    int end = (currentPage + 1).clamp(1, totalPages);
    
    // 确保至少显示5个页码（如果总页数允许）
    if (end - start < 3) {
      if (start == 1) {
        end = (start + 3).clamp(1, totalPages);
      } else if (end == totalPages) {
        start = (end - 3).clamp(1, totalPages);
      }
    }
    
    // 如果开始页码大于1，显示第一页和省略号
    if (start > 1) {
      widgets.add(_buildPageButton(
        text: '1',
        onPressed: () => _goToPage(1),
      ));
      if (start > 2) {
        widgets.add(Container(
          width: 20,
          // width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Text(
            '...',
            style: TextStyle(
              color: AppColors.mainTextColor2,
              fontSize: 14,
            ),
          ),
        ));
      }
      widgets.add(const SizedBox(width: 4));
    }
    
    // 显示页码范围
    for (int i = start; i <= end; i++) {
      widgets.add(_buildPageButton(
        text: i.toString(),
        isSelected: i == currentPage,
        onPressed: i == currentPage ? null : () => _goToPage(i),
      ));
      if (i < end) {
        widgets.add(const SizedBox(width: 4));
      }
    }
    
    // 如果结束页码小于总页数，显示省略号和最后一页
    if (end < totalPages) {
      widgets.add(const SizedBox(width: 4));
      if (end < totalPages - 1) {
        widgets.add(Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Text(
            '...',
            style: TextStyle(
              color: AppColors.mainTextColor2,
              fontSize: 14,
            ),
          ),
        ));
      }
      widgets.add(_buildPageButton(
        text: totalPages.toString(),
        onPressed: () => _goToPage(totalPages),
      ));
    }
    
    return widgets;
  }

  // 构建下拉框的辅助方法
  Widget _buildDropdown({
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
    required String hint,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: AppColors.itemsBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: DropdownButton<String>(
        value: options.contains(value) ? value : options.first,
        isExpanded: true,
        underline: Container(),
        dropdownColor: AppColors.itemsBackground,
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: AppColors.mainTextColor1,
        ),
        style: TextStyle(
          color: AppColors.mainTextColor1,
          fontSize: 14,
        ),
        onChanged: onChanged,
        items: options.map<DropdownMenuItem<String>>((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Text(
                option.isEmpty ? '请选择$hint' : option,
                style: TextStyle(
                  color: option.isEmpty 
                      ? AppColors.mainTextColor2 
                      : AppColors.mainTextColor1,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部查询区域
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.itemsBackground,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  // 单行：alarmSource、Type、时间范围、关键词、查询按钮、清除按钮
                  Row(
                    children: [
                      // alarmSource下拉框
                      Expanded(
                        flex: 2,
                        child: _buildDropdown(
                          value: selectedAlarmSource,
                          options: alarmSourceOptions,
                          hint: '报警源',
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedAlarmSource = newValue;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Type下拉框
                      Expanded(
                        flex: 2,
                        child: _buildDropdown(
                          value: selectedType,
                          options: typeOptions,
                          hint: '类型',
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedType = newValue;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 时间范围下拉框
                      Expanded(
                        flex: 2,
                        child: _buildDropdown(
                          value: selectedTimeRange,
                          options: timeRangeOptions,
                          hint: '时间范围',
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedTimeRange = newValue;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 关键词文本框
                      Expanded(
                        flex: 2,
                        child: _buildKeywordTextField(),
                      ),
                      const SizedBox(width: 12),
                      // 查询按钮
                      Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8.0),
                        child: InkWell(
                          onTap: isLoading ? null : () {
                            _resetPagination();
                            _fetchAlarmData();
                          },
                          borderRadius: BorderRadius.circular(8.0),
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(
                                    Icons.search,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 清除报警计数按钮
                      Material(
                        color: AppColors.contentColorOrange,
                        borderRadius: BorderRadius.circular(8.0),
                        child: InkWell(
                          onTap: () {
                            WebTitleService().clearAlarmCount();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('报警计数已清除'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8.0),
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            child: const Icon(
                              Icons.clear_all,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 数据列表
            Expanded(
              child: alarmItems.isEmpty && !isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 64,
                            color: Colors.white60,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂无报警记录',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: alarmItems.length + (totalPages > 1 ? 1 : 0),
                      itemBuilder: (context, index) {
                        // 如果是最后一项且有分页，显示分页组件
                        if (index == alarmItems.length && totalPages > 1) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: _buildPaginationWidget(),
                          );
                        }
                        // 否则显示报警项
                        return alarmItems[index].build(context, _handleAlarmItemTap);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}