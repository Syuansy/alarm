// Web平台特定实现
import 'dart:html' as html;

/// Web平台标题更新器
class PlatformTitleUpdater {
  /// 更新浏览器标题
  void updateTitle(String title) {
    try {
      html.document.title = title;
    } catch (e) {
      print('<Error> Web平台更新标题失败: $e');
    }
  }
}