// 非Web平台的桩实现
import 'package:flutter/material.dart';

// 桩实现，防止编译器报错
class WebHtmlChartImpl {
  // 空的注册方法
  static void registerIframe(String viewType, String url) {
    // 非Web平台不做任何事
  }
  
  // 空的打开方法
  static void openInNewWindow(String url) {
    // 非Web平台不做任何事
  }
}

// 返回空Widget，因为非Web平台不支持
Widget buildWebView(String viewType) {
  return const SizedBox();
} 