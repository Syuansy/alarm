import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:alarm_front/presentation/resources/app_colors.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui' as ui;

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
  late final String _iframeViewType;

  @override
  void initState() {
    super.initState();
    _iframeViewType = 'iframe-${widget.htmlUrl.hashCode}';
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _iframeViewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.htmlUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
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
          child: HtmlElementView(viewType: _iframeViewType),
        ),
      ],
    );
  }

  void _toggleFullScreen() {
    html.window.open(widget.htmlUrl, '_blank');
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