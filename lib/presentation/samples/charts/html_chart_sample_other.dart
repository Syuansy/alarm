import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:alarm_front/presentation/resources/app_colors.dart';
import 'package:alarm_front/util/html_chart_manager.dart';

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
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = HtmlChartManager().getController(widget.htmlUrl);
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (String url) {
          setState(() {
            _isLoading = false;
          });
        },
        onWebResourceError: (error) {
          print('<Error> WebView 加载错误: \\${error.description}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChartTitle(
          onFullScreenPressed: _toggleFullScreen,
          chartTitle: widget.title ?? '嵌入式网页',
          isFullScreen: false,
        ),
        AspectRatio(
          aspectRatio: 1.4,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 20, 8),
                child: WebViewWidget(controller: _controller),
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
    );
  }

  void _toggleFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenWebView(
          controller: _controller,
          title: widget.title ?? 'Web View',
          htmlUrl: widget.htmlUrl,
        ),
      ),
    );
  }
}

class _FullScreenWebView extends StatefulWidget {
  final WebViewController controller;
  final String title;
  final String htmlUrl;

  const _FullScreenWebView({
    required this.controller,
    required this.title,
    required this.htmlUrl,
  });

  @override
  State<_FullScreenWebView> createState() => _FullScreenWebViewState();
}

class _FullScreenWebViewState extends State<_FullScreenWebView> {
  bool _isLoading = false;

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
            ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 20, 16),
                    child: WebViewWidget(controller: widget.controller),
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

class _ChartTitle extends StatefulWidget {
  final VoidCallback onFullScreenPressed;
  final String chartTitle;
  final bool isFullScreen;

  const _ChartTitle({
    required this.onFullScreenPressed,
    required this.chartTitle,
    required this.isFullScreen,
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
          Row(
            children: [
              const Spacer(),
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