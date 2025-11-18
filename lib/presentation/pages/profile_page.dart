import 'package:flutter/material.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);
  
  // 定义路由常量
  static const String route = '/profile';

  @override
  Widget build(BuildContext context) {
    // 模拟用户登录状态，实际项目中应该从状态管理或本地存储中获取
    final bool isLoggedIn = false;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        backgroundColor: Colors.white.withOpacity(0.2),
      ),
      body: isLoggedIn ? _buildProfileView(context) : _buildLoginView(context),
    );
  }
  
  Widget _buildLoginView(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.contentColorBlue,
            child: Icon(
              Icons.person,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // 忘记密码逻辑
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('重置密码功能开发中')),
                );
              },
              child: const Text('忘记密码？'),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              // 登录逻辑
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('登录功能开发中')),
              );
            },
            child: const Text(
              '登录',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              // 注册逻辑
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('注册功能开发中')),
              );
            },
            child: const Text(
              '注册新账户',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileView(BuildContext context) {
    // 模拟用户数据，实际应该从API或状态管理获取
    const userName = '测试用户';
    const userEmail = 'test@example.com';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户头像和基本信息
          Row(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.contentColorBlue,
                child: Text(
                  'TU',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // 编辑资料
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('编辑资料功能开发中')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 菜单列表
          _buildMenuTile(
            icon: Icons.person,
            title: '个人资料',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('个人资料功能开发中')),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.settings,
            title: '设置',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置功能开发中')),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.notifications,
            title: '通知',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('通知功能开发中')),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.help,
            title: '帮助中心',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('帮助中心功能开发中')),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // 退出登录按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                // 退出登录逻辑
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认退出'),
                    content: const Text('您确定要退出登录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已退出登录')),
                          );
                        },
                        child: const Text('确认'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                '退出登录',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
} 