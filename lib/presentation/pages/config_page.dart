import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';

class ConfigPage extends StatefulWidget {
  static const String route = '/config';
  
  const ConfigPage({Key? key}) : super(key: key);

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  String? _configContent;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _textController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfigFile();
  }
  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigFile() async {
    try {
      final String jsonString = await rootBundle.loadString('lib/config/chart_config.json');
      // 使用JsonEncoder格式化JSON字符串
      final jsonObject = jsonDecode(jsonString);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonObject);
      
      setState(() {
        _configContent = prettyJson;
        _textController.text = prettyJson;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfigFile() async {
    if (_textController.text.isEmpty) {
      _showSnackBar('配置内容不能为空');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 验证JSON格式是否有效
      final jsonObject = jsonDecode(_textController.text);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonObject);
      
      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/chart_config.json';
      
      // 创建文件并写入内容
      final file = File(path);
      await file.writeAsString(prettyJson);
      
      // 显示保存成功的提示
      _showSnackBar('配置已保存到: $path');
      
      // 更新编辑器内容为格式化后的JSON
      _textController.text = prettyJson;
      
      // 显示保存成功对话框，询问是否应用更改
      _showSaveSuccessDialog(path);
    } catch (e) {
      _showSnackBar('保存失败: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  void _showSaveSuccessDialog(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存成功'),
        content: Text('配置已保存到: $path\n\n注意: 要使更改生效，您需要重启应用。'),
        backgroundColor: AppColors.itemsBackground,
        titleTextStyle: const TextStyle(
          color: AppColors.contentColorWhite,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.mainTextColor1,
          fontSize: 14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.2),
        iconTheme: const IconThemeData(color: AppColors.contentColorWhite),
        // 恢复普通标题
        title: const Text('配置文件', style: TextStyle(color: AppColors.contentColorWhite)),
        // 保留默认的返回按钮
        automaticallyImplyLeading: true,
        // 将保存按钮放在最右侧
        actions: [
          IconButton(
            icon: _isSaving 
              ? const SizedBox(
                  width: 24, 
                  height: 24, 
                  child: CircularProgressIndicator(
                    color: AppColors.contentColorWhite,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save),
            tooltip: '保存配置',
            onPressed: _isSaving ? null : _saveConfigFile,
          ),
        ],
      ),
      backgroundColor: AppColors.pageBackground,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          '加载配置文件失败: $_error',
          style: const TextStyle(color: AppColors.contentColorRed),
        ),
      );
    }

    if (_configContent == null) {
      return const Center(
        child: Text(
          '没有配置数据',
          style: TextStyle(color: AppColors.mainTextColor1),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.itemsBackground,
          borderRadius: BorderRadius.circular(AppDimens.defaultRadius),
          border: Border.all(color: AppColors.borderColor.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _textController,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppColors.mainTextColor1,
            fontSize: 14,
          ),
          maxLines: null, // 允许无限行数
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '在此编辑配置...',
            hintStyle: TextStyle(color: AppColors.mainTextColor3),
          ),
        ),
      ),
    );
  }
} 