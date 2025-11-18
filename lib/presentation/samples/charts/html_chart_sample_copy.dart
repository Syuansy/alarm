// 这段代码实现了一个HTML图表组件，用于在卡片中嵌入外部网页
// 通过平台无关的方式实现：Web端用iframe，非Web端用WebView
// 支持全屏显示功能

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:alarm_front/presentation/resources/app_colors.dart';
// 导入我们的条件实现
import 'html_chart_impl.dart';
import 'package:alarm_front/util/html_chart_manager.dart';
// 非Web环境下导入WebView
import 'package:webview_flutter/webview_flutter.dart';
// 导入WebSocket管理器
import 'package:alarm_front/util/websocket_manager.dart';

class HtmlChartSample extends StatefulWidget {
  const HtmlChartSample({
    super.key,
    this.title,
    required this.ipAddress,
  });

  final String? title;
  final String ipAddress;

  @override
  State<HtmlChartSample> createState() => _HtmlChartSampleState();
}

class _HtmlChartSampleState extends State<HtmlChartSample> {
  dynamic _controller;
  bool _isLoading = true;
  late final String _iframeViewType;
  double? _assemblyRate; // 存储组装率

  @override
  void initState() {
    super.initState();
    
    if (kIsWeb) {
      // Web平台：使用iframe嵌入
      _iframeViewType = 'iframe-${widget.ipAddress.hashCode}';
      WebHtmlChartImpl.registerIframe(_iframeViewType, widget.ipAddress);
      _isLoading = false;
    } else {
      // 非Web平台：使用WebView
      _controller = HtmlChartManager().getController(widget.ipAddress);
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
              
              // 添加超时处理 - 20秒后如果还在加载则显示超时提示
              Future.delayed(const Duration(seconds: 20), () {
                if (mounted && _isLoading) {
                  setState(() {
                    _isLoading = false; // 停止显示加载指示器
                  });
                  
                  // 输出详细日志
                  print('<Warn> WebView加载超时: $url');
                }
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              print('<Info> WebView加载完成: $url');
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false; // 停止显示加载指示器
              });
              // 输出详细错误信息
              print('<Error> WebView加载错误: 错误码=${error.errorCode}, 描述=${error.description}, URL=${error.url}');
            }
          },
        ),
      );
      
      // 尝试加载fallback URL (正式环境URL)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _isLoading && _controller != null) {
          final publicUrl = widget.ipAddress.replaceAll("10.3.171.241", "juno.myserver.com");
          print('<Info> 尝试加载公网URL: $publicUrl');
          _controller.loadRequest(Uri.parse(publicUrl));
        }
      });
    }
    
    // 订阅WebSocket消息，获取组装率
    WebSocketManager().addListener(_handleWebSocketMessage);
  }
  
  @override
  void dispose() {
    // 取消WebSocket消息订阅
    WebSocketManager().removeListener(_handleWebSocketMessage);
    super.dispose();
  }
  
  // 处理WebSocket消息
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    if (message['type'] == 'root_html' && message.containsKey('data')) {
      final dataList = message['data'];
      if (dataList is List) {
        // 查找匹配当前URL的数据项
        for (var item in dataList) {
          if (item is Map && item.containsKey('url') && item['url'] == widget.ipAddress) {
            if (item.containsKey('assembly_rate') && mounted) {
              setState(() {
                _assemblyRate = item['assembly_rate'] is num ? item['assembly_rate'].toDouble() : null;
              });
              break;
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 标题栏
        _ChartTitle(
          onFullScreenPressed: _toggleFullScreen,
          chartTitle: widget.title ?? '嵌入式网页',
          isFullScreen: false,
          assemblyRate: _assemblyRate,
        ),
        // 根据平台选择不同的实现
        AspectRatio(
          aspectRatio: 1.4,
          child: kIsWeb
              ? buildWebView(_iframeViewType)  // Web平台：使用iframe
              : Stack(                         // 非Web平台：使用WebView
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 20, 8),
                      child: _controller == null
                          ? const Center(child: Text('WebView未初始化'))
                          : WebViewWidget(controller: _controller),
                    ),
                    if (_isLoading)
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.contentColorYellow,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '正在加载网页，请稍候...',
                              style: TextStyle(
                                color: AppColors.contentColorYellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '如长时间无响应，请检查网络连接或URL',
                              style: TextStyle(
                                color: AppColors.contentColorYellow,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // 全屏切换
  void _toggleFullScreen() {
    if (kIsWeb) {
      // Web平台：在新窗口打开URL
      WebHtmlChartImpl.openInNewWindow(widget.ipAddress);
    } else {
      // 非Web平台：打开全屏WebView页面
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullScreenWebView(
            controller: _controller,
            title: widget.title ?? 'Web View',
            ipAddress: widget.ipAddress,
            assemblyRate: _assemblyRate,
          ),
        ),
      );
    }
  }
}

// 全屏网页视图（仅非Web平台）
class _FullScreenWebView extends StatefulWidget {
  final dynamic controller;
  final String title;
  final String ipAddress;
  final double? assemblyRate;

  const _FullScreenWebView({
    required this.controller,
    required this.title,
    required this.ipAddress,
    this.assemblyRate,
  });

  @override
  State<_FullScreenWebView> createState() => _FullScreenWebViewState();
}

class _FullScreenWebViewState extends State<_FullScreenWebView> {
  bool _isLoading = false;
  double? _assemblyRate;
  
  @override
  void initState() {
    super.initState();
    _assemblyRate = widget.assemblyRate;
    
    // 订阅WebSocket消息，获取组装率
    WebSocketManager().addListener(_handleWebSocketMessage);
  }
  
  @override
  void dispose() {
    // 取消WebSocket消息订阅
    WebSocketManager().removeListener(_handleWebSocketMessage);
    super.dispose();
  }
  
  // 处理WebSocket消息
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    if (message['type'] == 'root_html' && message.containsKey('data')) {
      final dataList = message['data'];
      if (dataList is List) {
        // 查找匹配当前URL的数据项
        for (var item in dataList) {
          if (item is Map && item.containsKey('url') && item['url'] == widget.ipAddress) {
            if (item.containsKey('assembly_rate') && mounted) {
              setState(() {
                _assemblyRate = item['assembly_rate'] is num ? item['assembly_rate'].toDouble() : null;
              });
              break;
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _ChartTitle(
              onFullScreenPressed: () => Navigator.of(context).pop(),
              chartTitle: widget.title,
              isFullScreen: true,
              assemblyRate: _assemblyRate,
            ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 20, 16),
                    child: widget.controller == null
                        ? const Center(child: Text('WebView未初始化'))
                        : WebViewWidget(controller: widget.controller),
                  ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.contentColorYellow,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 图表标题组件
class _ChartTitle extends StatefulWidget {
  final VoidCallback onFullScreenPressed;
  final String chartTitle;
  final bool isFullScreen;
  final double? assemblyRate;

  const _ChartTitle({
    required this.onFullScreenPressed,
    required this.chartTitle,
    required this.isFullScreen,
    this.assemblyRate,
  });

  @override
  State<_ChartTitle> createState() => _ChartTitleState();
}

class _ChartTitleState extends State<_ChartTitle> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一排：左侧显示组装率，右侧显示全屏按钮
          Row(
            children: [
              // 左侧：组装率标签
              if (widget.assemblyRate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.contentColorBlack.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.contentColorYellow.withOpacity(0.5)),
                  ),
                  child: Text(
                    '组装率: ${(widget.assemblyRate! * 100).toStringAsFixed(2)}%',
                    style: const TextStyle(
                      color: AppColors.contentColorYellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              const Spacer(),
              // 右侧：全屏按钮
              IconButton(
                icon: Icon(
                  widget.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: AppColors.contentColorYellow,
                  size: 20,
                ),
                onPressed: widget.onFullScreenPressed,
              ),
            ],
          ),
          // 第二排：标题居中
          Center(
            child: Text(
              widget.chartTitle,
              style: TextStyle(
                color: AppColors.contentColorYellow,
                fontWeight: FontWeight.bold,
                fontSize: widget.isFullScreen ? 22 : 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 