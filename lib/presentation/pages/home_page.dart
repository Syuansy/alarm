import 'package:dartx/dartx.dart';
import 'package:alarm_front/presentation/menu/app_menu.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:alarm_front/util/app_helper.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../widgets/group_button_card.dart';
import '../widgets/group_table_card.dart';
import '../widgets/group_button_card_detectorsNum.dart';
import 'package:alarm_front/presentation/pages/alarm_page.dart';
import 'package:alarm_front/presentation/pages/monitor_page.dart';
import 'package:alarm_front/presentation/pages/llm_page.dart';
import 'package:alarm_front/util/shared_data_service.dart';
import 'package:alarm_front/util/alarm_toast_service.dart';
import 'package:alarm_front/util/iframe_manager.dart';

import 'menu_bar_samples_page.dart';

class HomePage extends StatefulWidget {
  final String menuName;
  
  const HomePage({
    Key? key,
    required this.menuName,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Map<String, int> _menuItemsIndices;
  late List<MenuItem> _menuItems;
  int _refreshCounter = 0;
  bool _isMenuCollapsed = false; // 添加折叠状态管理
  
  // 共享数据服务
  final SharedDataService _dataService = SharedDataService();
  
  // 监听 Drawer 状态变化
  void _onDrawerChanged(bool isOpened) {
    if (isOpened) {
      // Drawer 打开时禁用所有 iframe
      IframeManager.disableAllIframes();
    } else {
      // Drawer 关闭时重新启用所有 iframe
      IframeManager.enableAllIframes();
    }
  }
  
  // 切换菜单折叠状态
  void _toggleMenuCollapse() {
    setState(() {
      _isMenuCollapsed = !_isMenuCollapsed;
    });
  }
  
  @override
  void initState() {
    super.initState();
    _initMenuItems();
    
    // 初始化上次选中的组名
    _lastSelectedGroup = _dataService.selectedGroupName;
    
    // 添加组状态监听器
    _dataService.addGroupStateListener(_handleGroupStateUpdate);
    
    // 在下一帧初始化报警提示框服务
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlarmToastService().initialize(context);
    });
  }
  
  @override
  void dispose() {
    // 移除组状态监听器
    _dataService.removeGroupStateListener(_handleGroupStateUpdate);
    // 确保在页面销毁时重新启用所有 iframe
    IframeManager.enableAllIframes();
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
    }
  }
  
  // 存储上次选中的组名，用于比较是否发生变化
  String? _lastSelectedGroup;
  
  void _initMenuItems() {   // 初始化菜单项
    _menuItemsIndices = {};
    _menuItems = menuItems.mapIndexed(
      (int index, String name) {
        _menuItemsIndices[name] = index;
        return MenuItem(
          name,
          _getMenuIcon(name),
        );
      },
    ).toList();
  }
  
  // 获取菜单图标
  String _getMenuIcon(String name) {
    // 特殊处理home和logs
    if (name.toLowerCase() == 'home') {
      return MenuIcons.home;
    }
    if (name.toLowerCase() == 'logs') {
      return MenuIcons.logs;
    }
    if (name.toLowerCase() == 'alarm') {
      return MenuIcons.alarm;
    }
    if (name.toLowerCase() == 'monitor') {
      return MenuIcons.monitor;
    }
    if (name.toLowerCase() == 'llm') {
      return MenuIcons.page7; // 使用page7图标作为LLM图标
    }

    
    // 对于其他菜单项，根据在menuItems中的位置动态分配图标
    final index = menuItems.indexOf(name);
    if (index == -1) {
      return MenuIcons.logs; // 默认图标
    }
    
    // 根据位置分配对应的page图标
    switch (index) {
      case 0: return MenuIcons.home; // 通常第一项是Home
      case 1: return MenuIcons.page1;
      case 2: return MenuIcons.page2;
      case 3: return MenuIcons.page3;
      case 4: return MenuIcons.page4;
      case 5: return MenuIcons.page5;
      case 6: return MenuIcons.page6;
      case 7: return MenuIcons.page7;
      case 8: return MenuIcons.page8;
      case 9: return MenuIcons.page9;
      case 10: return MenuIcons.page10;
      case 11: return MenuIcons.page11;
      case 12: return MenuIcons.page12;
      default: return MenuIcons.page12; // 默认图标
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMenuIndex = _menuItemsIndices[widget.menuName]!;
    
    // 使用key让页面在组选择变化时重新构建
    final key = ValueKey('home_page_${widget.menuName}_$_refreshCounter');
    
    return KeyedSubtree(
      key: key,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 创建所需的组件实例
          const Widget groupButtonWidget = GroupButtonCard();
          const Widget readoutLinkWidget = ReadoutLinkCard();
          
          // 加载GroupTableCard数据（如果需要）
          FutureBuilder<List<String>> groupTableFuture = FutureBuilder<List<String>>(
            future: _loadGroupTableData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                return GroupTableCard(groupList: snapshot.data!);
              }
              return const SizedBox.shrink();
            },
          );
          
          final needsDrawer = constraints.maxWidth <=
              AppDimens.menuMaxNeededWidth + AppDimens.chartBoxMinWidth;
              
          final appMenuWidget = AppMenu(
            menuItems: _menuItems,
            currentSelectedIndex: selectedMenuIndex,
            isCollapsed: _isMenuCollapsed,
            onToggleCollapse: _toggleMenuCollapse,
            onItemSelected: (newIndex, menuItem) {
              // 移除特殊处理，统一使用菜单导航方式
              context.go('/menu/${menuItem.text}');
              if (needsDrawer) {
                /// to close the drawer
                Navigator.of(context).pop();
                /// 确保在关闭 drawer 后重新启用所有 iframe
                IframeManager.enableAllIframes();
              }
            },
          );
              
          // 使用menuName作为当前显示的菜单栏名称
          // 为MenuBarSamplesPage添加key，确保在组选择变化时重建
          final samplesSectionWidget = MenuBarSamplesPage(
            title: widget.menuName,
            key: ValueKey('menu_bar_${widget.menuName}_$_refreshCounter'),
          );
          
          final body = needsDrawer
                  ? (widget.menuName == 'alarm'
                      ? const AlarmPage() // 只有Alarm页面使用AlarmPage
                      : widget.menuName.toLowerCase() == 'monitor'
                      ? const MonitorPage() // Monitor页面使用MonitorPage
                      : widget.menuName.toLowerCase() == 'llm'
                      ? const LLMPage() // LLM页面使用LLMPage
                          : Align(
                              alignment: Alignment.topLeft,
                              child: SingleChildScrollView(
                                padding: EdgeInsets.zero, // 移除内边距，避免顶部空白
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.stretch, // 让子组件水平拉伸
                                  children: [
                                    if (widget.menuName == 'RunInfo') ...[
                                      groupButtonWidget,
                                      groupTableFuture,
                                      readoutLinkWidget,
                                    ],
                                    if (widget.menuName != 'alarm' && widget.menuName.toLowerCase() != 'monitor' && widget.menuName.toLowerCase() != 'llm') samplesSectionWidget,
                                  ],
                                ),
                              ),
                            ))
                  : Row(
                      children: [
                        appMenuWidget,
                        Expanded(
                          child: widget.menuName == 'alarm'
                              ? const AlarmPage() // 只有Alarm页面使用AlarmPage
                              : widget.menuName.toLowerCase() == 'monitor'
                              ? const MonitorPage() // Monitor页面使用MonitorPage
                              : widget.menuName.toLowerCase() == 'llm'
                              ? const LLMPage() // LLM页面使用LLMPage
                                  : Align(
                                      alignment: Alignment.topLeft,
                                      child: SingleChildScrollView(
                                        padding: EdgeInsets.zero, // 移除内边距，避免顶部空白
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.stretch, // 让子组件水平拉伸
                                          children: [
                                            if (widget.menuName == 'RunInfo') ...[
                                              groupButtonWidget,
                                              groupTableFuture,
                                              readoutLinkWidget,
                                            ],
                                            if (widget.menuName != 'alarm' && widget.menuName.toLowerCase() != 'monitor' && widget.menuName.toLowerCase() != 'llm') samplesSectionWidget,
                                          ],
                                        ),
                                      ),
                                    ),
                        )
                      ],
                    );
  
              return Scaffold(
                body: body,
                drawer: needsDrawer
                        ? Drawer(
                        child: appMenuWidget,
                      )
                    : null,
                onDrawerChanged: needsDrawer ? _onDrawerChanged : null,
                appBar: needsDrawer
                        ? AppBar(
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        title: Text(widget.menuName),
                      )
                    : null,
              );
        },
      ),
    );
  }

  // 只为GroupTableCard加载配置数据
  Future<List<String>> _loadGroupTableData() async {
    final String jsonString = await rootBundle.loadString('lib/config/chart_config.json');
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    if (jsonData.containsKey('group')) {
      final groupList = jsonData['group'] as List;
      if (groupList.isNotEmpty && groupList[0]['content'] is List) {
        return List<String>.from(groupList[0]['content']);
      }
    }
    return [];
  }
}
