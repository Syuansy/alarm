// Web端的HtmlChartSample实现
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

// 暴露Web端的实现接口
class WebHtmlChartImpl {
  // 存储已注册的iframe视图类型和对应的URL
  static final Map<String, String> _registeredViews = {};
  
  // 注册iframe
  static void registerIframe(String viewType, String url) {
    // 打印正在注册的视图和URL
    print('<Info> 注册iframe: viewType=$viewType, url=$url');
    
    // 检查是否已注册相同的视图类型
    if (_registeredViews.containsKey(viewType)) {
      print('<Warn> 已有相同的viewType注册: ${_registeredViews[viewType]}');
      // 确保不同URL使用不同的viewType
      if (_registeredViews[viewType] != url) {
        print('<Warn> 注册的URL与之前不同，使用新的viewType');
      }
    }
    
    // 记录新注册的视图类型和URL
    _registeredViews[viewType] = url;
    
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        // 创建新的iframe元素，确保每个URL都有独立的iframe实例
        print('<Info> 为viewType=$viewType创建iframe, viewId=$viewId, url=$url');
        final iframe = html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.zIndex = '1'  // 设置较低的层级，确保下拉框能显示在上方
          ..style.position = 'relative'
          ..className = 'flutter-iframe'  // 添加统一的class便于管理
          // 添加唯一标识符属性，以便在DOM中区分
          ..id = 'iframe-$viewType-$viewId';
        return iframe;
      },
    );
  }
  
  // 禁用所有iframe的点击事件
  static void disableAllIframes() {
    final iframes = html.document.querySelectorAll('.flutter-iframe');
    for (final iframe in iframes) {
      iframe.style.pointerEvents = 'none';
      iframe.style.zIndex = '0';  // 进一步降低层级
    }
  }
  
  // 重新启用所有iframe的点击事件
  static void enableAllIframes() {
    final iframes = html.document.querySelectorAll('.flutter-iframe');
    for (final iframe in iframes) {
      iframe.style.pointerEvents = 'auto';
      iframe.style.zIndex = '1';  // 恢复正常层级
    }
  }
  
  // 在新窗口打开URL
  static void openInNewWindow(String url) {
    html.window.open(url, '_blank');
  }
}

// 构建HtmlElementView
Widget buildWebView(String viewType) {
  // 确保每次创建新的HtmlElementView实例
  return HtmlElementView(
    viewType: viewType,
    // 添加唯一的key，确保Flutter正确重建
    key: UniqueKey(),
  );
} 