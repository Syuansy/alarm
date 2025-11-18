// iframe管理工具，用于处理Web和非Web平台的条件导入
import 'iframe_manager_stub.dart'
    if (dart.library.html) 'iframe_manager_web.dart';

// 统一的iframe管理接口
class IframeManager {
  // 禁用所有iframe的点击事件
  static void disableAllIframes() {
    IframeManagerImpl.disableAllIframes();
  }
  
  // 重新启用所有iframe的点击事件
  static void enableAllIframes() {
    IframeManagerImpl.enableAllIframes();
  }
}