import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:alarm_front/presentation/samples/chart_samples.dart';
import 'package:alarm_front/presentation/widgets/chart_holder.dart';
import 'package:alarm_front/util/app_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class ChartSamplesPage extends StatelessWidget {
  final ChartType chartType;

  final samples = ChartSamples.samples;

  ChartSamplesPage({
    super.key,
    required this.chartType,
  });

  @override
  Widget build(BuildContext context) {
    final chartSamples = samples[chartType]!;

    // 统一使用网格布局，包括htmlPage类型图表
    return MasonryGridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
        itemCount: chartSamples.length,
        key: ValueKey(chartType),
        padding: const EdgeInsets.only(
          left: AppDimens.chartSamplesSpace,
          right: AppDimens.chartSamplesSpace,
          top: AppDimens.chartSamplesSpace,
          bottom: AppDimens.chartSamplesSpace + 68,
        ),
        crossAxisSpacing: AppDimens.chartSamplesSpace,
        mainAxisSpacing: AppDimens.chartSamplesSpace,
        itemBuilder: (BuildContext context, int index) {
          return ChartHolder(chartSample: chartSamples[index]);
        },
        gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 600,
      ),
    );
  }
}
