import 'package:flutter/material.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';

class SettingDetailPage extends StatefulWidget {
  final SettingDetailArgs args;
  
  const SettingDetailPage({
    Key? key,
    required this.args,
  }) : super(key: key);
  
  @override
  State<SettingDetailPage> createState() => _SettingDetailPageState();
}

class _SettingDetailPageState extends State<SettingDetailPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // 淡入动画
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );
    
    // 滑入动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // 启动动画
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title),
        backgroundColor: Colors.white.withOpacity(0.2),
      ),
      backgroundColor: AppColors.pageBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部的Hero动画元素
            Center(
              child: Hero(
                tag: widget.args.heroTag,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.args.icon,
                    color: AppColors.primary,
                    size: 50,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 标题和描述
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        widget.args.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.contentColorWhite,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        widget.args.subtitle,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.mainTextColor1.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 设置选项（假数据）
                    _buildSettingOption(
                      '选项 1',
                      '这是选项1的描述文本',
                      Icons.check_circle,
                    ),
                    _buildSettingOption(
                      '选项 2',
                      '这是选项2的描述文本',
                      Icons.favorite,
                    ),
                    _buildSettingOption(
                      '选项 3',
                      '这是选项3的描述文本',
                      Icons.star,
                    ),
                    
                    // 保存按钮
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          // 显示保存成功提示
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('设置已保存')),
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('保存设置'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingOption(String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.itemsBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.mainTextColor1,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: AppColors.mainTextColor1.withOpacity(0.7),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: AppColors.primary,
          size: 16,
        ),
        onTap: () {
          // 点击选项的操作
        },
      ),
    );
  }
}

// 设置详情页面参数
class SettingDetailArgs {
  final String title;
  final String subtitle;
  final IconData icon;
  final String heroTag;
  
  SettingDetailArgs({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.heroTag,
  });
} 