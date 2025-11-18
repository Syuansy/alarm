import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:alarm_front/presentation/resources/app_colors.dart';
import 'package:alarm_front/presentation/pages/monitor_models.dart';
import 'package:alarm_front/urls.dart';




// 不同监测算法发送监控配置到后端的表单详情
// 绝对阈值：
//   "id": "monitor_001",
//   "title": "CPU使用率监控",
//   "description": "监控系统CPU使用率",
//   "key": "system.cpu.usage",
//   "algorithm": "absoluteThreshold",
//   "frequency": "every1Minute",      // 监测频率
//   "upperThreshold": 85.0,           // 上限
//   "lowerThreshold": 0.0,            // 下限
//   "consecutiveTriggerCount": 3,     // ✅连续过阈次数触发报警
//   "consecutiveDeviationCount": null,
//   "ratio": null,
//   "grafanaUrl": "http://grafana.example.com/dashboard"
//
// 3σ算法：
//   "id": "monitor_002", 
//   "title": "DAQ输入速率监控",
//   "description": "使用3σ算法监控DAQ输入速率",
//   "key": "juno_daq.df.da:da-001.input_ros_volume.rate",
//   "algorithm": "threeSigma",
//   "frequency": "every1Minute",
//   "upperThreshold": null,           // 系统动态计算
//   "lowerThreshold": null,           // 系统动态计算
//   "consecutiveTriggerCount": 5,     // ✅连续过阈次数触发报警
//   "consecutiveDeviationCount": null,
//   "ratio": 3,                       // ✅监测幅度 μ±xσ
//   "grafanaUrl": "http://grafana.example.com/dashboard"
//
// AI模型算法（Informer、TimesNet、Autoformer等）：
//   "id": "monitor_003",
//   "title": "网络流量异常检测", 
//   "description": "使用AI模型检测网络流量异常",
//   "key": "Rate_cd_raw.ctu",
//   "algorithm": "Informer",  // 或 TimesNet, Autoformer, DLinear 等
//   "frequency": "every1Minute",
//   "upperThreshold": null,
//   "lowerThreshold": null,
//   "consecutiveTriggerCount": null,
//   "consecutiveDeviationCount": 3,   // ✅连续偏离次数触发报警
//   "ratio": null,
//   "grafanaUrl": "http://grafana.example.com/dashboard"














class MonitorFormPage extends StatefulWidget {
  final MonitorItem? editItem;
  
  const MonitorFormPage({Key? key, this.editItem}) : super(key: key);

  @override
  State<MonitorFormPage> createState() => _MonitorFormPageState();
}

class _MonitorFormPageState extends State<MonitorFormPage> {
  final _formKey = GlobalKey<FormState>();
  
  // 表单控制器
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _keyController = TextEditingController();
  final _upperThresholdController = TextEditingController();
  final _lowerThresholdController = TextEditingController();
  final _consecutiveTriggerController = TextEditingController();
  final _consecutiveDeviationController = TextEditingController();
  final _ratioController = TextEditingController();
  final _grafanaUrlController = TextEditingController();
  
  // 下拉框选择值
  MonitorAlgorithm _selectedAlgorithm = MonitorAlgorithm.absoluteThreshold;
  MonitorFrequency _selectedFrequency = MonitorFrequency.every1Second;

  @override
  void initState() {
    super.initState();
    // 设置默认值
    _ratioController.text = '3.0';
    // 如果是编辑模式，填入已有数据
    if (widget.editItem != null) {
      _initializeWithEditData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _keyController.dispose();
    _upperThresholdController.dispose();
    _lowerThresholdController.dispose();
    _consecutiveTriggerController.dispose();
    _consecutiveDeviationController.dispose();
    _ratioController.dispose();
    _grafanaUrlController.dispose();
    super.dispose();
  }

  // 使用编辑数据初始化表单
  void _initializeWithEditData() {
    final item = widget.editItem!;
    _titleController.text = item.title;
    _descriptionController.text = item.description;
    _keyController.text = item.key;
    _selectedAlgorithm = item.algorithm;
    _selectedFrequency = item.frequency;
    
    if (item.upperThreshold != null) {
      _upperThresholdController.text = item.upperThreshold.toString();
    }
    if (item.lowerThreshold != null) {
      _lowerThresholdController.text = item.lowerThreshold.toString();
    }
    if (item.consecutiveTriggerCount != null) {
      _consecutiveTriggerController.text = item.consecutiveTriggerCount.toString();
    }
    if (item.consecutiveDeviationCount != null) {
      _consecutiveDeviationController.text = item.consecutiveDeviationCount.toString();
    }
    if (item.grafanaUrl != null) {
      _grafanaUrlController.text = item.grafanaUrl!;
    }
  }

  // 重置表单
  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    _keyController.clear();
    _upperThresholdController.clear();
    _lowerThresholdController.clear();
    _consecutiveTriggerController.clear();
    _consecutiveDeviationController.clear();
    _ratioController.clear();
    _grafanaUrlController.clear();
    
    setState(() {
      _selectedAlgorithm = MonitorAlgorithm.absoluteThreshold;
      _selectedFrequency = MonitorFrequency.every1Second;
    });
    
    // 重置ratio默认值
    _ratioController.text = '3.0';
  }

  // 提交表单
  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final monitorItem = MonitorItem(
        id: widget.editItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        key: _keyController.text.trim(),
        algorithm: _selectedAlgorithm,
        frequency: _selectedFrequency,
        upperThreshold: _selectedAlgorithm == MonitorAlgorithm.absoluteThreshold
            ? double.tryParse(_upperThresholdController.text.trim())
            : null,
        lowerThreshold: _selectedAlgorithm == MonitorAlgorithm.absoluteThreshold
            ? double.tryParse(_lowerThresholdController.text.trim())
            : null,
        consecutiveTriggerCount: _selectedAlgorithm == MonitorAlgorithm.absoluteThreshold ||
                _selectedAlgorithm == MonitorAlgorithm.threeSigma
            ? int.tryParse(_consecutiveTriggerController.text.trim()) ?? 1
            : null,
        consecutiveDeviationCount: _selectedAlgorithm.isAIModel
            ? int.tryParse(_consecutiveDeviationController.text.trim()) ?? 3
            : null,
        grafanaUrl: _grafanaUrlController.text.trim().isEmpty 
            ? null 
            : _grafanaUrlController.text.trim(),
      );

      // 发送到后端
      final success = await _sendMonitorConfigToBackend(monitorItem);
      
      if (success) {
        // 成功后返回上一页
        Navigator.of(context).pop(monitorItem);
        
        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('监控配置已成功提交到后端！'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // 显示错误消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('提交监控配置到后端失败，请检查网络连接'),
            backgroundColor: AppColors.contentColorRed,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 发送监控配置到后端
  Future<bool> _sendMonitorConfigToBackend(MonitorItem monitorItem) async {
    try {
      // 准备请求数据
      final requestData = {
        'id': monitorItem.id,
        'title': monitorItem.title,
        'description': monitorItem.description,
        'key': monitorItem.key,
        'algorithm': monitorItem.algorithm.name,
        'frequency': monitorItem.frequency.name,
        'upperThreshold': monitorItem.upperThreshold,
        'lowerThreshold': monitorItem.lowerThreshold,
        'consecutiveTriggerCount': monitorItem.consecutiveTriggerCount,
        'consecutiveDeviationCount': monitorItem.consecutiveDeviationCount,
        'ratio': _selectedAlgorithm == MonitorAlgorithm.threeSigma 
            ? double.tryParse(_ratioController.text.trim()) ?? 3.0
            : null,
        'grafanaUrl': monitorItem.grafanaUrl,
      };

      print('发送监控配置到后端: ${json.encode(requestData)}');

      // 发送HTTP POST请求
      final response = await http.post(
        Uri.parse('${Urls.alarmApiBase}/monitor/configure'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('后端响应状态: ${response.statusCode}');
      print('后端响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['status'] == 'success';
      } else {
        print('后端返回错误状态码: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('发送监控配置到后端时发生错误: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.itemsBackground,
        title: Text(
          widget.editItem != null ? '编辑监控项目' : '添加监控项目',
          style: TextStyle(
            color: AppColors.mainTextColor1,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.mainTextColor1,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  controller: _titleController,
                  label: 'Title',
                  hint: '请输入监控项目标题',
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return '请输入Title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: '请输入监控项目描述',
                  maxLines: 3,
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return '请输入Description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _keyController,
                  label: 'Key',
                  hint: '请输入监控键值',
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return '请输入Key';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                _buildDropdownField<MonitorAlgorithm>(
                  label: '监测算法',
                  value: _selectedAlgorithm,
                  items: MonitorAlgorithm.values,
                  itemBuilder: (algorithm) => algorithm.displayName,
                  onChanged: (value) {
                    setState(() {
                      _selectedAlgorithm = value!;
                      // 切换算法时清理相关字段
                      _clearAlgorithmSpecificFields();
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                _buildDropdownField<MonitorFrequency>(
                  label: '监测频率',
                  value: _selectedFrequency,
                  items: MonitorFrequency.values,
                  itemBuilder: (frequency) => frequency.displayName,
                  onChanged: (value) {
                    setState(() {
                      _selectedFrequency = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Grafana图表链接
                _buildTextField(
                  label: 'Grafana图表链接',
                  controller: _grafanaUrlController,
                  hint: '输入Grafana图表的URL (可选)',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),
                
                // 根据选择的算法显示不同的字段
                ..._buildAlgorithmSpecificFields(),
                
                const SizedBox(height: 32),
                
                // 按钮行
                Row(
                  children: [
                    Expanded(
                      child: _buildButton(
                        text: '重置',
                        onPressed: _resetForm,
                        backgroundColor: AppColors.contentColorOrange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildButton(
                        text: '提交',
                        onPressed: _submitForm,
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 清理算法特定字段
  void _clearAlgorithmSpecificFields() {
    _upperThresholdController.clear();
    _lowerThresholdController.clear();
    _consecutiveTriggerController.clear();
    _consecutiveDeviationController.clear();
    _ratioController.clear();
  }

  // 构建文本输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.mainTextColor1,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(color: AppColors.mainTextColor1),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.mainTextColor2),
            filled: true,
            fillColor: AppColors.itemsBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.contentColorRed),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  // 构建下拉选择框
  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.mainTextColor1,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.itemsBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: Container(),
            dropdownColor: AppColors.itemsBackground,
            style: TextStyle(color: AppColors.mainTextColor1),
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<T>>((T item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(itemBuilder(item)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 构建算法特定字段
  List<Widget> _buildAlgorithmSpecificFields() {
    switch (_selectedAlgorithm) {
      case MonitorAlgorithm.absoluteThreshold:
        return [
          _buildTextField(
            controller: _upperThresholdController,
            label: '阈值上限',
            hint: '请输入阈值上限',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return '请输入阈值上限';
              }
              if (double.tryParse(value!) == null) {
                return '请输入有效的数字';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _lowerThresholdController,
            label: '阈值下限',
            hint: '请输入阈值下限',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return '请输入阈值下限';
              }
              if (double.tryParse(value!) == null) {
                return '请输入有效的数字';
              }
              final upper = double.tryParse(_upperThresholdController.text.trim());
              final lower = double.tryParse(value);
              if (upper != null && lower != null && lower >= upper) {
                return '阈值下限必须小于上限';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _consecutiveTriggerController,
            label: '连续过阈次数触发报警',
            hint: '请输入连续过阈次数',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return '请输入连续过阈次数';
              }
              final count = int.tryParse(value!);
              if (count == null || count <= 0) {
                return '请输入有效的正整数';
              }
              return null;
            },
          ),
        ];
        
      case MonitorAlgorithm.threeSigma:
        return [
          _buildTextField(
            controller: _ratioController,
            label: '监测幅度(±xσ)',
            hint: '请输入监测幅度倍数，默认3.0',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (value) {
              final trimmedValue = value?.trim() ?? '';
              if (trimmedValue.isEmpty) {
                // 如果为空，使用默认值3.0
                _ratioController.text = '3.0';
                return null;
              }
              final ratio = double.tryParse(trimmedValue);
              if (ratio == null || ratio <= 0) {
                return '请输入有效的正数';
              }
              if (ratio > 10) {
                return '监测幅度不能超过10σ';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _consecutiveTriggerController,
            label: '连续过阈次数触发报警',
            hint: '请输入连续过阈次数',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return '请输入连续过阈次数';
              }
              final count = int.tryParse(value!);
              if (count == null || count <= 0) {
                return '请输入有效的正整数';
              }
              return null;
            },
          ),
        ];
        
      default:
        // AI模型算法（Informer, Autoformer, TimesNet等）
        return [
          _buildTextField(
            controller: _consecutiveDeviationController,
            label: '连续偏离次数触发报警',
            hint: '请输入连续偏离次数（默认3次）',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return '请输入连续偏离次数';
              }
              final count = int.tryParse(value!);
              if (count == null || count <= 0) {
                return '请输入有效的正整数';
              }
              return null;
            },
          ),
        ];
    }
  }

  // 构建按钮
  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}