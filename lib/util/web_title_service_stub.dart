// 移动平台占位实现
import 'package:flutter/foundation.dart';

/// 移动平台标题更新器（占位实现）
class PlatformTitleUpdater {
  /// 移动平台不需要更新浏览器标题
  void updateTitle(String title) {
    if (kDebugMode) {
      debugPrint('<Info> 移动平台跳过标题更新: $title');
    }
    // 移动平台不需要实际操作
  }
}