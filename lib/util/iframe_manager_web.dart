// Web平台的iframe管理实现
import '../presentation/samples/charts/html_chart_web_impl.dart';

class IframeManagerImpl {
  // 禁用所有iframe的点击事件
  static void disableAllIframes() {
    WebHtmlChartImpl.disableAllIframes();
  }
  
  // 重新启用所有iframe的点击事件
  static void enableAllIframes() {
    WebHtmlChartImpl.enableAllIframes();
  }
}