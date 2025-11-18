// 这段代码实现了一个HTML图表组件，用于在卡片中嵌入外部网页
// 通过平台无关的方式实现：Web端用iframe，非Web端用WebView
// 支持全屏显示功能

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:alarm_front/presentation/resources/app_colors.dart';
// 导入我们的条件实现
import 'html_chart_impl.dart';
// 非Web环境下导入WebView
import 'package:webview_flutter/webview_flutter.dart';

class HtmlChartSample extends StatefulWidget {
  const HtmlChartSample({
    super.key,
    this.title,
    required this.htmlUrl,
  });

  final String? title;
  final String htmlUrl;

  @override
  State<HtmlChartSample> createState() => _HtmlChartSampleState();
}

class _HtmlChartSampleState extends State<HtmlChartSample> {
  WebViewController? _controller;
  bool _isLoading = true;
  late final String _iframeViewType;

  @override
  void initState() {
    super.initState();
    
    // 确保每个URL都有唯一的视图类型标识符，添加随机数和时间戳
    _iframeViewType = 'iframe-${widget.htmlUrl.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    if (kIsWeb) {
      // Web平台：使用iframe嵌入
      WebHtmlChartImpl.registerIframe(_iframeViewType, widget.htmlUrl);
    } else {
      // 非Web平台：使用WebView - 创建新的控制器而不是复用
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse(widget.htmlUrl));
        
      _controller!.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      );
    }
  }
  
  @override
  void dispose() {
    // 移动平台释放资源
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 适应网格布局约束，使用固定长宽比
    return AspectRatio(
      aspectRatio: 1.3, // 长宽比1.3:1
      child: kIsWeb
          ? _buildWebContent() // Web平台：使用iframe
          : _buildMobileContent(), // 非Web平台：使用WebView
    );
  }

  // Web平台内容构建
  Widget _buildWebContent() {
    return buildWebView(_iframeViewType);
  }

  // 移动平台内容构建
  Widget _buildMobileContent() {
    return Stack(
      children: [
        Positioned.fill(
          child: _controller == null
              ? _buildErrorState()
              : WebViewWidget(controller: _controller!),
        ),
        if (_isLoading) _buildLoadingState(),
      ],
    );
  }

  // 错误状态构建
  Widget _buildErrorState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.contentColorYellow,
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            'WebView未初始化',
            style: TextStyle(
              color: AppColors.contentColorYellow,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '请检查网络连接或重试',
            style: TextStyle(
              color: AppColors.contentColorYellow,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // 加载状态构建
  Widget _buildLoadingState() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.contentColorYellow,
            ),
            SizedBox(height: 8),
            Text(
              '正在加载网页...',
              style: TextStyle(
                color: AppColors.contentColorYellow,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }


}

// 全屏网页视图（仅非Web平台）
class _FullScreenWebView extends StatefulWidget {
  final WebViewController controller;
  final String title;

  const _FullScreenWebView({
    super.key,
    required this.controller,
    this.title = '全屏查看',
  });

  @override
  State<_FullScreenWebView> createState() => _FullScreenWebViewState();
}

class _FullScreenWebViewState extends State<_FullScreenWebView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              widget.controller.reload();
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: widget.controller),
    );
  }
}

// 全屏HTML页面组件 - 不使用卡片包装，直接嵌入完整网页界面
class FullPageHtmlSample extends StatefulWidget {
  const FullPageHtmlSample({
    super.key,
    required this.htmlUrl,
  });

  final String htmlUrl;

  @override
  State<FullPageHtmlSample> createState() => _FullPageHtmlSampleState();
}

class _FullPageHtmlSampleState extends State<FullPageHtmlSample> {
  WebViewController? _controller;
  bool _isLoading = true;
  late final String _iframeViewType;
  late final String _actualUrl;

  @override
  void initState() {
    super.initState();
    
    // 打印当前正在加载的URL，用于调试
    print('<Info> 正在加载全屏HTML页面，URL: ${widget.htmlUrl}');
    
    // 确保使用正确的URL
    _actualUrl = widget.htmlUrl;

    if (kIsWeb) {
      // Web平台：使用iframe嵌入
      // 确保每个URL都有唯一的视图类型标识符，添加随机数和时间戳
      _iframeViewType = 'iframe-fullpage-${_actualUrl.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
      print('<Info> 为URL创建iframe: $_iframeViewType => $_actualUrl');
      WebHtmlChartImpl.registerIframe(_iframeViewType, _actualUrl);
      _isLoading = false;
    } else {
      // 非Web平台：使用WebView
      // 每次创建新的控制器，而不是复用
      print('<Info> 为URL创建WebView控制器: $_actualUrl');
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse(_actualUrl));
      
      _controller!.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
            print('<Info> WebView开始加载: $url');
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            print('<Info> WebView加载完成: $url');
          },
          onWebResourceError: (WebResourceError error) {
            print('<Error> WebView加载错误: ${error.description}');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      );
    }
  }
  
  @override
  void dispose() {
    // 移动平台释放资源
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 适应网格布局约束，使用固定长宽比
    return AspectRatio(
      aspectRatio: 1.3, // 长宽比1.3:1
      child: Stack(
        children: [
          // 根据平台选择不同的实现
          Positioned.fill(
            child: kIsWeb
                ? _buildWebContent() // Web平台：使用iframe
                : _buildMobileContent(), // 移动平台：使用WebView
          ),
          // 加载指示器（仅在移动端显示）
          if (!kIsWeb && _isLoading) _buildLoadingState(),
        ],
      ),
    );
  }

  // Web平台内容构建 - 使用iframe嵌入网页，占用全部可用空间
  Widget _buildWebContent() {
    return buildWebView(_iframeViewType);
  }

  // 移动平台内容构建 - 使用WebView嵌入网页，占用全部可用空间
  Widget _buildMobileContent() {
    return _controller == null
        ? _buildErrorState()
        : WebViewWidget(controller: _controller!);
  }

  // 加载状态构建
  Widget _buildLoadingState() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.contentColorYellow,
            ),
            SizedBox(height: 16),
            Text(
              '正在加载网页...',
              style: TextStyle(
                color: AppColors.contentColorYellow,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 错误状态构建
  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              'WebView初始化失败',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '请检查网络连接或联系管理员',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}