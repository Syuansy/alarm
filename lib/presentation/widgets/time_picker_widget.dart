import 'package:flutter/material.dart';
import 'package:alarm_front/util/time_range_service.dart';
import 'package:alarm_front/presentation/resources/app_colors.dart';
import 'package:alarm_front/util/iframe_manager.dart';

/// 时间选择器组件
class TimePickerWidget extends StatefulWidget {
  final VoidCallback? onTimeRangeChanged;

  const TimePickerWidget({
    super.key,
    this.onTimeRangeChanged,
  });

  @override
  State<TimePickerWidget> createState() => _TimePickerWidgetState();
}

class _TimePickerWidgetState extends State<TimePickerWidget> {
  final TimeRangeService _timeRangeService = TimeRangeService();
  late String _selectedDisplayText;
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();
  bool _isDropdownOpen = false;
  bool _isDisposing = false; // 标记组件是否正在销毁
  
  // 安全地执行状态更新的辅助方法
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposing) {
      try {
        setState(fn);
      } catch (e) {
        // 捕获任何setState异常，防止崩溃
        debugPrint('TimePickerWidget setState error: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // 初始化显示文本
    _selectedDisplayText = _timeRangeService.getDisplayText(_timeRangeService.selectedTimeRange);
  }

  @override
  void dispose() {
    // 标记组件正在销毁，防止任何setState调用
    _isDisposing = true;
    
    // 确保清理所有资源，但不更新状态
    _removeOverlay(updateState: false);
    
    // 在组件销毁时重新启用所有iframe，防止页面被锁定
    IframeManager.enableAllIframes();
    
    super.dispose();
  }

  void _toggleDropdown() {
    if (!mounted || _isDisposing) return; // 检查组件是否还在挂载状态且未销毁
    
    if (_isDropdownOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (!mounted || _isDisposing) return; // 检查组件是否还在挂载状态且未销毁
    
    final overlay = Overlay.of(context);
    final buttonContext = _buttonKey.currentContext;
    if (buttonContext == null || !buttonContext.mounted) {
      return; // 确保 context 存在且已挂载
    }
    
    final renderBox = buttonContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) {
      return; // 确保 renderBox 存在且已附加
    }

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // 禁用所有iframe的点击事件
    IframeManager.disableAllIframes();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // 在 builder 中也检查 mounted 状态和销毁状态
        if (!mounted || _isDisposing) {
          return const SizedBox.shrink();
        }
        
        return Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _removeOverlay,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned(
                    left: offset.dx,
                    top: offset.dy + size.height + 4,
                    width: size.width,
                    child: GestureDetector(
                      onTap: () {}, // 阻止事件冒泡
                      child: Material(
                        elevation: 1000, // 极高的elevation确保在最顶层
                        borderRadius: BorderRadius.circular(6.0),
                        color: AppColors.itemsBackground,
                        shadowColor: Colors.black.withOpacity(0.3),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(
                              color: AppColors.borderColor.withOpacity(0.3),
                              width: 1.0,
                            ),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: TimeRangeService.timeRangeOptions.keys.map((String displayText) {
                              return InkWell(
                                onTap: () => _selectOption(displayText),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                  child: Text(
                                    displayText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: displayText == _selectedDisplayText 
                                          ? AppColors.primary 
                                          : AppColors.mainTextColor1,
                                      fontWeight: displayText == _selectedDisplayText 
                                          ? FontWeight.w500 
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
    _safeSetState(() {
      _isDropdownOpen = true;
    });
  }

  void _removeOverlay({bool updateState = true}) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    
    // 重新启用所有iframe的点击事件
    IframeManager.enableAllIframes();
    
    // 只在需要时更新状态
    if (updateState) {
      _safeSetState(() {
        _isDropdownOpen = false;
      });
    } else {
      // 直接更新变量，不触发setState
      _isDropdownOpen = false;
    }
  }

  void _selectOption(String newValue) {
    if (!mounted || _isDisposing) return; // 检查组件是否还在挂载状态且未销毁
    
    if (newValue != _selectedDisplayText) {
      _safeSetState(() {
        _selectedDisplayText = newValue;
      });
      
      // 更新时间范围服务
      final timeRangeValue = _timeRangeService.getTimeRangeValue(newValue);
      _timeRangeService.updateTimeRange(timeRangeValue);
      
      // 回调通知父组件
      if (widget.onTimeRangeChanged != null) {
        widget.onTimeRangeChanged!();
      }
    }
    _removeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    // 如果组件不再挂载或正在销毁，返回空容器防止错误
    if (!mounted || _isDisposing) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: _toggleDropdown,
      child: Container(
        key: _buttonKey,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: AppColors.itemsBackground,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: _isDropdownOpen 
                ? AppColors.primary.withOpacity(0.5)
                : AppColors.borderColor.withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                _selectedDisplayText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mainTextColor1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: AppColors.mainTextColor2,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// 时间选择器行组件 - 显示在页面右侧
class TimePickerRow extends StatelessWidget {
  final VoidCallback? onTimeRangeChanged;

  const TimePickerRow({
    super.key,
    this.onTimeRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Text(
          //   'Time Range: ',
          //   style: TextStyle(
          //     fontSize: 13,
          //     fontWeight: FontWeight.w500,
          //     color: AppColors.mainTextColor2,
          //   ),
          // ),
          const SizedBox(width: 6),
          SizedBox(
            width: 120,
            child: TimePickerWidget(
              onTimeRangeChanged: onTimeRangeChanged,
            ),
          ),
        ],
      ),
    );
  }
}