// HTML图表管理工具类，用于管理HTML图表的WebView控制器和相关配置

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'dart:convert';

class HtmlChartManager {
  // 单例模式
  static final HtmlChartManager _instance = HtmlChartManager._internal();
  factory HtmlChartManager() => _instance;
  HtmlChartManager._internal();
  
  // WebView控制器池
  final Map<String, WebViewController> _controllers = {};
  
  // 预加载指定IP地址的WebView控制器
  WebViewController preloadWebView(String htmlUrl) {
    if (_controllers.containsKey(htmlUrl)) {
      return _controllers[htmlUrl]!;
    }
    
    print('<Info> 创建WebViewController: $htmlUrl');
    
    // 创建更加健壮的WebViewController，解决Android平台HTTP网页无法显示问题
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      // 设置自定义用户代理，模拟常规浏览器
      ..setUserAgent('Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.91 Mobile Safari/537.36')
      // 增强的HTTP允许策略
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('<Error> WebView加载错误[${htmlUrl}]: 错误码=${error.errorCode}, 描述=${error.description}');
            
            // 错误处理 - 尝试重新加载或降级策略
            if (error.errorCode == -1 || // 通用错误
                error.errorCode == -2 || // 服务器错误
                error.errorCode == -6) { // 连接错误
              final WebViewController errorController = _controllers[htmlUrl]!;
              Future.delayed(const Duration(seconds: 2), () {
                try {
                  errorController.reload();
                } catch (e) {
                  debugPrint('<Error> 重新加载失败: $e');
                }
              });
            }
          },
          // 允许所有URL导航
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('<Info> WebView导航请求: ${request.url}');
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            debugPrint('<Info> WebView URL变更: ${change.url}');
          },
          onProgress: (int progress) {
            debugPrint('<Info> WebView加载进度: $progress%');
          },
        ),
      );

    // 注入JavaScript代码支持混合内容
    controller.runJavaScript('''
      // 尝试处理混合内容问题
      document.addEventListener('DOMContentLoaded', function() {
        // 将所有HTTP资源重写为HTTPS
        var meta = document.createElement('meta');
        meta.httpEquiv = 'Content-Security-Policy';
        meta.content = 'upgrade-insecure-requests';
        document.head.appendChild(meta);
      });
    ''').catchError((error) {
      debugPrint('<Error> JavaScript注入错误: $error');
    });
    
    try {
      // 确保使用有效的URL格式
      final uri = Uri.parse(htmlUrl);
      debugPrint('<Info> WebView加载URL: ${uri.toString()}');
      controller.loadRequest(uri);
    } catch (e) {
      debugPrint('<Error> WebView URL解析错误: $e');
    }
      
    _controllers[htmlUrl] = controller;
    return controller;
  }
  
  // 获取WebView控制器（如果不存在则创建）
  WebViewController getController(String htmlUrl) {
    return preloadWebView(htmlUrl);
  }
  
  // 刷新指定IP地址的WebView
  void refreshWebView(String htmlUrl) {
    if (_controllers.containsKey(htmlUrl)) {
      _controllers[htmlUrl]!.reload();
    }
  }
  
  // 执行JavaScript脚本
  Future<dynamic> executeJavaScript(String htmlUrl, String script) async {
    if (!_controllers.containsKey(htmlUrl)) {
      return null;
    }
    
    try {
      return await _controllers[htmlUrl]!.runJavaScriptReturningResult(script);
    } catch (e) {
      debugPrint('<Error> 执行JavaScript失败: $e');
      return null;
    }
  }
  
  // 关闭所有WebView
  void disposeAll() {
    _controllers.clear();
  }
  
  // 注册自定义JavaScript通信通道
  void registerJavaScriptChannel(
    String htmlUrl, 
    String channelName, 
    void Function(JavaScriptMessage) onMessageReceived
  ) {
    if (!_controllers.containsKey(htmlUrl)) {
      preloadWebView(htmlUrl);
    }
    
    _controllers[htmlUrl]!.addJavaScriptChannel(
      channelName,
      onMessageReceived: onMessageReceived,
    );
  }
} 