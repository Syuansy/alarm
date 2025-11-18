import 'package:flutter/material.dart';
import 'package:alarm_front/util/permission_service.dart';
import 'package:alarm_front/util/simple_alarm_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PermissionTestPage extends StatefulWidget {
  static const String route = '/permission_test';
  
  const PermissionTestPage({Key? key}) : super(key: key);

  @override
  State<PermissionTestPage> createState() => _PermissionTestPageState();
}

class _PermissionTestPageState extends State<PermissionTestPage> {
  final PermissionService _permissionService = PermissionService();
  final SimpleAlarmService _simpleAlarmService = SimpleAlarmService();
  Map<String, bool> _permissionStatus = {};
  String _appVersion = '';
  String _appName = '';
  bool _isLoading = true;
  String? _errorMessage;
  
  // 用于跟踪测试功能的状态
  final Map<String, bool> _testInProgress = {
    '悬浮窗': false,
    '提示音': false,
    '震动': false,
    '通知': false,
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // 使用单一函数统一初始化，以便于错误处理
  Future<void> _initialize() async {
    try {
      // 首先初始化通知服务和简单报警服务
      await _permissionService.initNotifications();
      await _simpleAlarmService.initialize();

      // 然后加载应用信息和权限状态
      await Future.wait([
        _loadAppInfo(),
        _loadPermissions(),
      ]);
    } catch (e) {
      debugPrint('<Error> 初始化发生错误: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '加载出错: $e';
          _isLoading = false;
        });
      }
    } finally {
      // 无论成功还是失败，确保退出加载状态
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAppInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appName = packageInfo.appName;
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('<Error> 加载应用信息出错: $e');
      if (mounted) {
        setState(() {
          _appName = 'Unknown';
          _appVersion = 'Unknown';
        });
      }
    }
  }

  Future<void> _loadPermissions() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      final Map<String, bool> statuses = await _permissionService.getAllPermissionStatus();
      
      if (mounted) {
        setState(() {
          _permissionStatus = statuses;
        });
      }
    } catch (e) {
      debugPrint('<Error> 加载权限状态出错: $e');
      // 出错时至少提供一些默认状态
      if (mounted) {
        setState(() {
          _permissionStatus = {
            '通知': false,
            '悬浮窗': false,
            '震动': false,
            '闹钟': false,
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestAllPermissions() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      await _permissionService.requestAllPermissions();
      await _loadPermissions();
    } catch (e) {
      debugPrint('<Error> 请求权限出错: $e');
      setState(() {
        _errorMessage = '请求权限出错: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 测试悬浮窗功能 - 纯悬浮窗，无声音无震动
  Future<void> _testOverlay() async {
    if (_testInProgress['悬浮窗']!) return;

    setState(() {
      _testInProgress['悬浮窗'] = true;
    });

    try {
      await _simpleAlarmService.showSystemOverlay();
      debugPrint('<Info> 纯悬浮窗测试完成 - 应该只显示横幅，无声音无震动');

      // 2秒后重置状态
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _testInProgress['悬浮窗'] = false;
          });
        }
      });
    } catch (e) {
      debugPrint('<Error> 测试悬浮窗出错: $e');
      setState(() {
        _testInProgress['悬浮窗'] = false;
      });
    }
  }
  
  // 测试提示音功能 - 纯提示音，无UI无震动
  Future<void> _testSound() async {
    if (_testInProgress['提示音']!) return;

    setState(() {
      _testInProgress['提示音'] = true;
    });

    try {
      await _simpleAlarmService.playAlarmSound();
      debugPrint('<Info> 纯提示音测试完成 - 应该只播放声音，无UI无震动');

      // 3秒后重置状态（给声音播放时间）
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _testInProgress['提示音'] = false;
          });
        }
      });
    } catch (e) {
      debugPrint('<Error> 测试提示音出错: $e');
      setState(() {
        _testInProgress['提示音'] = false;
      });
    }
  }
  
  // 测试震动功能 - 纯震动2秒，无声音无UI
  Future<void> _testVibration() async {
    if (_testInProgress['震动']!) return;

    setState(() {
      _testInProgress['震动'] = true;
    });

    try {
      await _simpleAlarmService.vibrateDevice(duration: 2000); // 震动2秒
      debugPrint('<Info> 纯震动测试完成 - 应该只震动2秒，无声音无UI');

      // 2.5秒后重置状态（给震动完成时间）
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _testInProgress['震动'] = false;
          });
        }
      });
    } catch (e) {
      debugPrint('<Error> 测试震动出错: $e');
      setState(() {
        _testInProgress['震动'] = false;
      });
    }
  }
  
  // 测试系统通知功能 - 组合功能：悬浮窗+提示音+震动
  Future<void> _testNotification() async {
    if (_testInProgress['通知']!) return;

    setState(() {
      _testInProgress['通知'] = true;
    });

    try {
      await _simpleAlarmService.triggerFullAlarm();
      debugPrint('<Info> 组合功能测试完成 - 应该同时显示悬浮窗、播放声音、震动');

      // 3秒后重置状态（给所有功能完成时间）
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _testInProgress['通知'] = false;
          });
        }
      });
    } catch (e) {
      debugPrint('<Error> 测试组合功能出错: $e');
      setState(() {
        _testInProgress['通知'] = false;
      });
    }
  }

  // 停止所有报警
  Future<void> _stopAllAlarms() async {
    try {
      await _simpleAlarmService.stopAllAlarms();
      debugPrint('<Info> 所有报警已停止');

      // 重置所有测试状态
      setState(() {
        _testInProgress.updateAll((key, value) => false);
      });
    } catch (e) {
      debugPrint('<Error> 停止报警出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('权限测试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadPermissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildPermissionList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '发生未知错误',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initialize,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionList() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 应用信息卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _appName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '版本: $_appVersion',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 权限请求按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestAllPermissions,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('请求所有权限'),
              ),
            ),
            const SizedBox(height: 20),
            
            // 权限状态列表
            const Text(
              '权限状态',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 10),
            
            // 生成权限列表
            _permissionStatus.isEmpty
                ? const Center(
                    child: Text('无权限数据', style: TextStyle(color: Colors.grey)),
                  )
                : Column(
                    children: _permissionStatus.entries.map(
                      (entry) => _buildPermissionItem(entry.key, entry.value),
                    ).toList(),
                  ),
            
            const SizedBox(height: 20),
            
            // 功能测试按钮组
            const Text(
              '独立报警功能测试',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 10),

            // 测试悬浮窗
            _buildTestButton(
              title: '测试悬浮窗',
              subtitle: '纯悬浮窗显示（无声音无震动）',
              icon: Icons.picture_in_picture,
              onPressed: _testOverlay,
              isEnabled: _permissionStatus['悬浮窗'] ?? false,
              isLoading: _testInProgress['悬浮窗'] ?? false,
            ),

            // 测试提示音
            _buildTestButton(
              title: '测试提示音',
              subtitle: '纯提示音播放（无UI无震动）',
              icon: Icons.music_note,
              onPressed: _testSound,
              isEnabled: _permissionStatus['闹钟'] ?? false,
              isLoading: _testInProgress['提示音'] ?? false,
            ),

            // 测试震动
            _buildTestButton(
              title: '测试震动',
              subtitle: '纯震动2秒（无声音无UI）',
              icon: Icons.vibration,
              onPressed: _testVibration,
              isEnabled: true, // 震动不需要特殊权限
              isLoading: _testInProgress['震动'] ?? false,
            ),

            // 测试系统通知
            _buildTestButton(
              title: '测试系统通知',
              subtitle: '组合功能：悬浮窗+提示音+震动',
              icon: Icons.notifications_active,
              onPressed: _testNotification,
              isEnabled: _permissionStatus['通知'] ?? false,
              isLoading: _testInProgress['通知'] ?? false,
            ),

            const SizedBox(height: 20),

            // 停止所有报警按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _stopAllAlarms,
                icon: const Icon(Icons.stop, color: Colors.white),
                label: const Text('停止所有报警', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(String permissionName, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel,
            color: isGranted ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Text(
            permissionName,
            style: const TextStyle(fontSize: 16),
          ),
          const Spacer(),
          Text(
            isGranted ? '已授权' : '未授权',
            style: TextStyle(
              color: isGranted ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isEnabled,
    required bool isLoading,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: isEnabled ? null : Colors.grey,
          size: 28,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isEnabled ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isEnabled ? null : Colors.grey[600],
          ),
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                ),
              )
            : Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: isEnabled ? null : Colors.grey,
              ),
        enabled: isEnabled && !isLoading,
        onTap: isEnabled && !isLoading ? onPressed : null,
      ),
    );
  }
} 