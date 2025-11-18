
import 'package:alarm_front/config/app_config.dart';
import 'package:alarm_front/config/chart_config_manager.dart';
import 'package:alarm_front/cubits/app/app_cubit.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:alarm_front/presentation/samples/chart_samples.dart';
import 'package:alarm_front/util/permission_service.dart';
import 'package:alarm_front/util/app_helper.dart';
import 'package:alarm_front/util/simple_alarm_service.dart';
import 'package:alarm_front/util/shared_data_service.dart';
import 'package:alarm_front/util/web_title_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'presentation/router/app_router.dart';

void main() async {
  // 确保Flutter框架初始化完成
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 首先加载应用配置
    await AppConfig().load();
    AppConfig().printConfig(); // 打印配置信息用于调试
    
    // 加载菜单项
    await loadMenuItems();
    
    // 初始化图表样本
    await ChartSamples.init();
    
    // 初始化图表配置管理器
    await ChartConfigManager().loadConfig();
    
    // 初始化报警服务
    await SimpleAlarmService().initialize().catchError((error) {
      debugPrint('<Error> 初始化报警服务出错: $error');
      // 允许应用继续运行，即使报警服务初始化失败
    });
    
    // 初始化共享数据服务（仅访问一次单例即可激活WebSocket连接）
    SharedDataService();
    
    // 初始化Web标题服务（用于在浏览器标题中显示报警数量）
    WebTitleService().initialize();
    
    // 尝试初始化权限服务，但不等待它完成（在需要时再初始化）
    PermissionService().initNotifications().catchError((error) {
      debugPrint('<Error> 初始化权限服务出错: $error');
      // 允许应用继续运行，即使权限服务初始化失败
    });
  } catch (e) {
    debugPrint('<Error> 应用初始化发生错误: $e');
    // 允许应用继续运行，即使初始化过程出现问题
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppCubit>(create: (BuildContext context) => AppCubit()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,    // 隐藏debug标志
        title: AppTexts.appName,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          textTheme: GoogleFonts.assistantTextTheme(
            Theme.of(context).textTheme.apply(
                  bodyColor: AppColors.mainTextColor3,
                ),
          ),
          scaffoldBackgroundColor: AppColors.pageBackground,
        ),
        routerConfig: appRouterConfig,
      ),
    );
  }
}
