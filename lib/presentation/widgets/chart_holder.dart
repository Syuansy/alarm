import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:alarm_front/presentation/samples/chart_sample.dart';
import 'package:flutter/material.dart';

class ChartHolder extends StatelessWidget {
  final ChartSample chartSample;

  const ChartHolder({
    super.key,
    required this.chartSample,
  });

  @override
  Widget build(BuildContext context) {
    // 统一处理所有类型的图表，包括htmlPage类型
    final widget = chartSample.builder(context);

    return Column(
      mainAxisSize: MainAxisSize.min,// 垂直方向：收缩包裹内容
      crossAxisAlignment: CrossAxisAlignment.stretch,// 水平方向：拉伸子组件
      children: [
        // Row(
        //   children: [    //标题行
        //     const SizedBox(width: 6),
        //     Text(
        //       chartSample.name,
        //       style: const TextStyle(
        //         color: AppColors.primary,
        //         fontSize: 18,
        //         fontWeight: FontWeight.bold,
        //       ),
        //     ),
        //     Expanded(child: Container()),
        //     IconButton(
        //       onPressed: () => AppUtils().tryToLaunchUrl(chartSample.url),
        //       icon: const Icon(
        //         Icons.code,
        //         color: AppColors.primary,
        //       ),
        //       tooltip: 'Source code',
        //     ),
        //   ],
        // ),
        // const SizedBox(height: 2),//标题与图表容器的间距
        Container(    //图表容器 - 统一处理所有图表类型
          decoration: const BoxDecoration(
            color: AppColors.itemsBackground,// 背景色
            borderRadius:
                BorderRadius.all(Radius.circular(AppDimens.defaultRadius)),// 圆角
          ),
          child: widget,// 动态构建图表
        ),
      ],
    );
  }
}
