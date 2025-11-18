import 'package:flutter/material.dart';
import 'package:alarm_front/util/var_picker_service.dart';
import 'package:alarm_front/presentation/resources/app_colors.dart';

/// 单个变量选择器组件
class VarPickerWidget extends StatefulWidget {
  final String variableKey;
  final String initialValue;
  final VoidCallback? onVariableChanged;

  const VarPickerWidget({
    super.key,
    required this.variableKey,
    required this.initialValue,
    this.onVariableChanged,
  });

  @override
  State<VarPickerWidget> createState() => _VarPickerWidgetState();
}

class _VarPickerWidgetState extends State<VarPickerWidget> {
  final VarPickerService _varPickerService = VarPickerService();
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    
    // 从变量服务获取当前值，如果没有则使用初始值
    final currentValue = _varPickerService.getVariable(widget.variableKey);
    final displayValue = currentValue.isNotEmpty ? currentValue : widget.initialValue;
    
    _controller = TextEditingController(text: displayValue);
    _focusNode = FocusNode();
    
    // 监听焦点变化，失去焦点时触发更新
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _handleValueSubmit(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  // 处理值提交（失去焦点或按回车时）
  void _handleValueSubmit(String value) {
    // 更新变量服务
    _varPickerService.updateVariable(widget.variableKey, value);
    
    // 回调通知父组件（触发页面刷新）
    if (widget.onVariableChanged != null) {
      widget.onVariableChanged!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 变量标签
          Text(
            '${widget.variableKey}: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mainTextColor2,
            ),
          ),
          const SizedBox(width: 4),
          // 变量输入框
          Container(
            width: 80,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.itemsBackground,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(
                color: AppColors.borderColor.withOpacity(0.3),
                width: 1.0,
              ),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mainTextColor1,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                isDense: true,
              ),
              onChanged: (value) {
                // 只更新变量服务，不触发页面刷新
                _varPickerService.updateVariable(widget.variableKey, value);
              },
              onSubmitted: (value) {
                // 当按下回车键时触发更新和刷新
                _handleValueSubmit(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 变量选择器行组件 - 显示所有变量选择器
class VarPickerRow extends StatefulWidget {
  final Map<String, String> variables;
  final VoidCallback? onVariableChanged;

  const VarPickerRow({
    super.key,
    required this.variables,
    this.onVariableChanged,
  });

  @override
  State<VarPickerRow> createState() => _VarPickerRowState();
}

class _VarPickerRowState extends State<VarPickerRow> {
  final VarPickerService _varPickerService = VarPickerService();

  @override
  void initState() {
    super.initState();
    // 只初始化那些还没有值的变量，避免覆盖用户输入
    for (final entry in widget.variables.entries) {
      final currentValue = _varPickerService.getVariable(entry.key);
      if (currentValue.isEmpty) {
        _varPickerService.updateVariable(entry.key, entry.value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variables.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // 变量选择器列表
        ...widget.variables.entries.map((entry) {
          return VarPickerWidget(
            variableKey: entry.key,
            initialValue: entry.value,
            onVariableChanged: widget.onVariableChanged,
          );
        }).toList(),
      ],
    );
  }
}

