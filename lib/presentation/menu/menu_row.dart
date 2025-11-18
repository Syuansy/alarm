import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MenuRow extends StatefulWidget {
  final String text;
  final String svgPath;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const MenuRow({
    super.key,
    required this.text,
    required this.svgPath,
    required this.isSelected,
    this.isCollapsed = false,
    required this.onTap,
  });

  @override
  State<MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<MenuRow> {
  bool get _showSelectedState => widget.isSelected;

  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onHover: (bool hovered) {
          setState(() {
            isHovered = hovered;
          });
        },
        onTap: widget.onTap,
        child: SizedBox(
          height: AppDimens.menuRowHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 使用 LayoutBuilder 来确保布局适应实际可用空间
              final isNarrow = constraints.maxWidth < 160; // 如果宽度小于160px，强制使用折叠布局
              final shouldCollapse = widget.isCollapsed || isNarrow;
              
              if (shouldCollapse) {
                return Center(
                  child: Tooltip(
                    message: widget.text,
                    child: SvgPicture.asset(
                      widget.svgPath,
                      width: AppDimens.menuIconSize,
                      height: AppDimens.menuIconSize,
                      colorFilter: ColorFilter.mode(
                        _showSelectedState ? AppColors.primary : Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                );
              } else {
                return Row(
                  children: [
                    const SizedBox(width: 36),
                    SvgPicture.asset(
                      widget.svgPath,
                      width: AppDimens.menuIconSize,
                      height: AppDimens.menuIconSize,
                      colorFilter:
                          const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          color: _showSelectedState ? AppColors.primary : Colors.white,
                          fontSize: AppDimens.menuTextSize,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}


