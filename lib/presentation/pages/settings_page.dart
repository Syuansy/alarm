import 'package:flutter/material.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:alarm_front/presentation/pages/setting_detail_page.dart';
import 'package:alarm_front/presentation/pages/grafana_dashboard_page.dart'; // 导入新页面
import 'package:alarm_front/presentation/pages/permission_test_page.dart'; // 导入权限测试页面
import 'package:alarm_front/presentation/pages/config_page.dart'; // 导入配置页面
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_platform/universal_platform.dart';
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  static const String route = '/settings';
  
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  // Animation controller
  late TabController _tabController;
  
  // 存储每个模块的设置项数据
  final Map<String, List<SettingItem>> _settingsData = {
    'Base': [
      SettingItem(
        title: '深色模式',
        subtitle: '切换应用主题',
        icon: Icons.dark_mode,
        isSwitch: true, 
        switchValue: false
      ),
      SettingItem(
        title: '通知提醒',
        subtitle: '启用系统通知',
        icon: Icons.notifications,
        isSwitch: true, 
        switchValue: true
      ),
      SettingItem(
        title: '权限测试',
        subtitle: '测试应用权限和功能',
        icon: Icons.verified_user,
        isSwitch: false
      ),
      SettingItem(
        title: 'ConfigPage',
        subtitle: '配置页面设置',
        icon: Icons.settings_applications,
        isSwitch: false
      ),
      SettingItem(
        title: '语言设置',
        subtitle: '当前：简体中文',
        icon: Icons.language,
        isSwitch: false
      ),
    ],
    'Home': [
      SettingItem(
        title: '首页布局',
        subtitle: '网格视图',
        icon: Icons.grid_view,
        isSwitch: false
      ),
      SettingItem(
        title: '显示统计数据',
        subtitle: '在首页展示统计图表',
        icon: Icons.bar_chart,
        isSwitch: true, 
        switchValue: true
      ),
      SettingItem(
        title: '刷新间隔',
        subtitle: '每30秒',
        icon: Icons.refresh,
        isSwitch: false
      ),
    ],
    'Html': [
      SettingItem(
        title: '用户自定义图表',
        subtitle: '上传Grafana Dashboard配置文件',
        icon: Icons.dashboard_customize,
        isSwitch: false
      ),
      SettingItem(
        title: '预加载网页',
        subtitle: '提升加载速度',
        icon: Icons.web,
        isSwitch: true, 
        switchValue: false
      ),
      SettingItem(
        title: '默认浏览器',
        subtitle: '应用内浏览器',
        icon: Icons.open_in_browser,
        isSwitch: false
      ),
      SettingItem(
        title: 'JavaScript',
        subtitle: '允许执行JavaScript',
        icon: Icons.code,
        isSwitch: true, 
        switchValue: true
      ),
    ],
    'Logs': [
      SettingItem(
        title: '日志级别',
        subtitle: '信息',
        icon: Icons.info,
        isSwitch: false
      ),
      SettingItem(
        title: '自动清理',
        subtitle: '7天后自动删除',
        icon: Icons.auto_delete,
        isSwitch: true, 
        switchValue: true
      ),
      SettingItem(
        title: '导出日志',
        subtitle: '保存日志到本地文件',
        icon: Icons.download,
        isSwitch: false
      ),
    ],
    'Alarm': [
      SettingItem(
        title: '报警冷却控制',
        subtitle: '相同报警类型冷却时间',
        icon: Icons.timer,
        isDropdown: true,
        dropdownOptions: ['1min', '5min', '10min', '30min', '1h', '从不'],
        dropdownValue: '10min'
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _settingsData.keys.length, 
      vsync: this
    );
    _loadSettings();
  }

  // 加载设置
  Future<void> _loadSettings() async {
    // 仅在移动端加载设置
    if (!_isMobile()) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('app_settings');
      
      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        
        setState(() {
          // 遍历所有分类的设置项
          for (String category in _settingsData.keys) {
            if (settingsMap.containsKey(category)) {
              final categorySettings = settingsMap[category] as Map<String, dynamic>;
              
              for (int i = 0; i < _settingsData[category]!.length; i++) {
                final item = _settingsData[category]![i];
                final itemKey = item.title;
                
                if (categorySettings.containsKey(itemKey)) {
                  final itemData = categorySettings[itemKey] as Map<String, dynamic>;
                  
                  // 恢复开关状态
                  if (item.isSwitch && itemData.containsKey('switchValue')) {
                    item.switchValue = itemData['switchValue'] as bool;
                  }
                  
                  // 恢复下拉框选择
                  if (item.isDropdown && itemData.containsKey('dropdownValue')) {
                    final value = itemData['dropdownValue'] as String;
                    if (item.dropdownOptions!.contains(value)) {
                      item.dropdownValue = value;
                      if (item.title == '报警冷却控制') {
                        item.subtitle = '相同报警类型冷却时间: $value';
                      }
                    }
                  }
                }
              }
            }
          }
        });
      }
    } catch (e) {
      print('加载设置失败: $e');
    }
  }

  // 保存设置
  Future<void> _saveSettings() async {
    // 仅在移动端保存设置
    if (!_isMobile()) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 构建设置数据
      final settingsMap = <String, dynamic>{};
      
      for (String category in _settingsData.keys) {
        settingsMap[category] = <String, dynamic>{};
        
        for (final item in _settingsData[category]!) {
          settingsMap[category][item.title] = {
            'switchValue': item.switchValue,
            'dropdownValue': item.dropdownValue,
          };
        }
      }
      
      await prefs.setString('app_settings', json.encode(settingsMap));
    } catch (e) {
      print('保存设置失败: $e');
    }
  }

  // 判断是否为移动端
  bool _isMobile() {
    return UniversalPlatform.isAndroid || UniversalPlatform.isIOS;
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.white.withOpacity(0.2),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _settingsData.keys.map((String key) {
            return Tab(text: key);
          }).toList(),
          labelColor: AppColors.contentColorWhite,
          unselectedLabelColor: AppColors.mainTextColor1,
          indicatorColor: AppColors.primary,
        ),
      ),
      backgroundColor: AppColors.pageBackground,
      body: TabBarView(
        controller: _tabController,
        children: _settingsData.keys.map((String key) {
          return _buildSettingsList(key, _settingsData[key]!);
        }).toList(),
      ),
    );
  }
  
  Widget _buildSettingsList(String category, List<SettingItem> settings) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: settings.length,
      itemBuilder: (context, index) {
        final item = settings[index];
        final heroTag = '${category}_${item.title}_${index}';
        
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 100)),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            color: AppColors.itemsBackground,
            elevation: 2,
            child: ListTile(
              leading: Hero(
                tag: heroTag,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    color: AppColors.primary,
                  ),
                ),
              ),
              title: Text(
                item.title,
                style: const TextStyle(
                  color: AppColors.mainTextColor1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                style: TextStyle(
                  color: AppColors.mainTextColor1.withOpacity(0.7),
                ),
              ),
              trailing: item.isSwitch
                ? Switch(
                    value: item.switchValue,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() {
                        item.switchValue = value;
                      });
                      _saveSettings(); // 保存设置
                    },
                  )
                : item.isDropdown
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.itemsBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButton<String>(
                        value: item.dropdownValue,
                        style: const TextStyle(
                          color: AppColors.mainTextColor1,
                          fontSize: 14,
                        ),
                        dropdownColor: AppColors.itemsBackground,
                        underline: Container(),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.mainTextColor1,
                        ),
                        items: item.dropdownOptions!.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value,
                                style: const TextStyle(
                                  color: AppColors.mainTextColor1,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            item.dropdownValue = newValue;
                            // 更新subtitle显示当前选择的值
                            if (item.title == '报警冷却控制') {
                              item.subtitle = '相同报警类型冷却时间: $newValue';
                            }
                          });
                          _saveSettings(); // 保存设置
                        },
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.mainTextColor3,
                      size: 16,
                    ),
              onTap: (item.isSwitch || item.isDropdown)
                ? null
                : () {
                    // 导航到详情页
                    if (item.title == '用户自定义图表') {
                      // 导航到Grafana Dashboard上传页面
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => const GrafanaDashboardPage(),
                        ),
                      );
                    } else if (item.title == '权限测试') {
                      // 导航到权限测试页面
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => const PermissionTestPage(),
                        ),
                      );
                    } else if (item.title == 'ConfigPage') {
                      // 导航到配置页面
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => const ConfigPage(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => SettingDetailPage(
                            args: SettingDetailArgs(
                              title: item.title,
                              subtitle: item.subtitle,
                              icon: item.icon,
                              heroTag: heroTag,
                            ),
                          ),
                        ),
                      );
                    }
                  },
            ),
          ),
        );
      },
    );
  }
}

// 设置项数据模型
class SettingItem {
  final String title;
  String subtitle;  // 改为可变，以便更新下拉框显示
  final IconData icon;
  final bool isSwitch;
  final bool isDropdown;
  final List<String>? dropdownOptions;
  bool switchValue;
  String? dropdownValue;
  
  SettingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isSwitch = false,
    this.isDropdown = false,
    this.dropdownOptions,
    this.switchValue = false,
    this.dropdownValue,
  });
} 