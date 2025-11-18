import 'package:alarm_front/presentation/pages/home_page.dart';
import 'package:alarm_front/presentation/pages/profile_page.dart';
import 'package:alarm_front/presentation/pages/permission_test_page.dart';
import 'package:alarm_front/presentation/pages/config_page.dart';
import 'package:alarm_front/presentation/pages/settings_page.dart';
import 'package:alarm_front/presentation/pages/monitor_page.dart';
import 'package:alarm_front/presentation/pages/llm_page.dart';
import 'package:alarm_front/presentation/resources/app_colors.dart';
import 'package:alarm_front/util/app_helper.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouterConfig = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Container(color: AppColors.pageBackground),
      redirect: (context, state) {
        // 如果菜单项为空，仍然尝试重定向到Home页面
        final defaultMenu = menuItems.isNotEmpty ? menuItems[0] : 'Home';
        return '/menu/$defaultMenu';
      },
    ),
    GoRoute(
      path: '/menu/:menuName',
      pageBuilder: (BuildContext context, GoRouterState state) {
        final menuName = state.pathParameters['menuName'] ?? 
            (menuItems.isNotEmpty ? menuItems[0] : 'Home');
        return MaterialPage<void>(
          key: const ValueKey('home_page'),
          child: HomePage(menuName: menuName),
        );
      },
    ),
    GoRoute(
      path: ProfilePage.route,
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: PermissionTestPage.route,
      builder: (context, state) => const PermissionTestPage(),
    ),
    GoRoute(
      path: ConfigPage.route,
      builder: (context, state) => const ConfigPage(),
    ),
    GoRoute(
      path: SettingsPage.route,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: MonitorPage.route,
      builder: (context, state) => const MonitorPage(),
    ),
    GoRoute(
      path: '/llm',
      builder: (context, state) => const LLMPage(),
    ),
    GoRoute(
      path: '/:any',
      builder: (context, state) => Container(color: AppColors.pageBackground),
      redirect: (context, state) {
        // Unsupported path, we redirect it to /
        return '/';
      },
    ),
  ],
);
