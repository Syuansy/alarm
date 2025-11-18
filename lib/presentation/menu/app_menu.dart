import 'package:dartx/dartx.dart';
import 'package:alarm_front/cubits/app/app_cubit.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:alarm_front/presentation/pages/profile_page.dart';


import 'package:alarm_front/presentation/pages/settings_page.dart';

import 'fl_chart_banner.dart';
import 'menu_row.dart';

class AppMenu extends StatelessWidget {
  final List<MenuItem> menuItems;
  final int currentSelectedIndex;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final Function(int, MenuItem) onItemSelected;
  final VoidCallback? onBannerClicked;

  const AppMenu({
    super.key,
    required this.menuItems,
    required this.currentSelectedIndex,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onItemSelected,
    this.onBannerClicked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isCollapsed ? 80 : 280, // 折叠时宽度80，展开时宽度280
      child: Container(
        color: AppColors.itemsBackground,
        child: Column(
          children: [
            if (!isCollapsed)
              SafeArea(
                child: AspectRatio(
                  aspectRatio: 3,
                  child: Center(
                    child: const FlChartBanner(),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemBuilder: (context, position) {
                  final menuItem = menuItems[position];
                  return MenuRow(
                    text: menuItem.text,
                    svgPath: menuItem.iconPath,
                    isSelected: currentSelectedIndex == position,
                    isCollapsed: isCollapsed,
                    onTap: () {
                      onItemSelected(position, menuItem);
                    },
                  );
                },
                itemCount: menuItems.length,
              ),
            ),
            _AppVersionRow(
              isCollapsed: isCollapsed,
              onToggleCollapse: kIsWeb ? onToggleCollapse : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppVersionRow extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  
  const _AppVersionRow({
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppState>(builder: (context, state) {
      if (state.appVersion.isNullOrBlank) {
        return Container();
      }
      return Container(
        margin: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 折叠按钮 - 只在web端显示
            if (onToggleCollapse != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: onToggleCollapse,
                    icon: Icon(
                      isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                      color: AppColors.primary,
                    ),
                    tooltip: isCollapsed ? '展开侧边栏' : '折叠侧边栏',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // 使用LayoutBuilder确保布局适应实际可用空间
            LayoutBuilder(
              builder: (context, constraints) {
                final actuallyCollapsed = isCollapsed || constraints.maxWidth < 120;
                
                if (actuallyCollapsed) {
                  // 折叠状态：只显示一个居中的小图标
                  return Center(
                    child: state.availableVersionToUpdate.isNotBlank
                        ? Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              'U',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : IconButton(
                            onPressed: () => GoRouter.of(context).push(ProfilePage.route),
                            icon: const Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            tooltip: '个人主页',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                  );
                } else {
                  // 展开状态：显示完整布局
                  return Row(
                    children: [
                      state.availableVersionToUpdate.isNotBlank
                          ? Flexible(
                              child: TextButton(
                                onPressed: () {},
                                child: Text(
                                  'Update to ${state.availableVersionToUpdate}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => GoRouter.of(context).push(ProfilePage.route),
                                  icon: const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: '个人主页',
                                ),
                                IconButton(
                                  onPressed: () => GoRouter.of(context).push(SettingsPage.route),
                                  icon: const Icon(
                                    Icons.settings,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: '设置',
                                ),
                              ],
                            ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: RichText(
                            textAlign: TextAlign.right,
                            text: TextSpan(
                              text: '',
                              style: DefaultTextStyle.of(context).style,
                              children: <TextSpan>[
                                const TextSpan(text: 'App version: '),
                                TextSpan(
                                  text: 'v${state.appVersion!}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (state.usingFlChartVersion.isNotBlank) ...[
                                  const TextSpan(
                                    text: '\nfl_chart: ',
                                  ),
                                  TextSpan(
                                    text: 'v${state.usingFlChartVersion}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      );
    });
  }
}

class MenuItem {
  final String text;
  final String iconPath;

  const MenuItem(this.text, this.iconPath);
}
