// HTML解析工具类，用于处理HTML图表的数据

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HtmlParser {
  // WebView控制器缓存池，避免重复创建
  static final Map<String, WebViewController> _controllerPool = {};

  // 获取或创建WebView控制器
  static WebViewController getController(String url) {
    if (_controllerPool.containsKey(url)) {
      return _controllerPool[url]!;
    }
    
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('<Error> WebView加载错误: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
    
    _controllerPool[url] = controller;
    return controller;
  }
  
  // 清理控制器
  static void disposeController(String url) {
    _controllerPool.remove(url);
  }
  
  // 清理所有控制器
  static void disposeAllControllers() {
    _controllerPool.clear();
  }
  
  // 执行JavaScript并获取结果
  static Future<String?> evaluateJavascript(String url, String javaScript) async {
    try {
      final controller = getController(url);
      final result = await controller.runJavaScriptReturningResult(javaScript);
      return result.toString();
    } catch (e) {
      debugPrint('<Error> 执行JavaScript出错: $e');
      return null;
    }
  }
  
  // 刷新指定URL的WebView
  static void refreshWebView(String url) {
    if (_controllerPool.containsKey(url)) {
      _controllerPool[url]!.reload();
    }
  }
} 