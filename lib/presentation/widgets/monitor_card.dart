import 'package:flutter/material.dart';
import 'package:alarm_front/presentation/resources/app_colors.dart';
import 'package:alarm_front/presentation/pages/monitor_models.dart';
import 'package:alarm_front/presentation/samples/charts/html_chart_sample.dart';
import 'package:alarm_front/util/monitor_item_notifier.dart';

class MonitorCard extends StatelessWidget {
  final MonitorItemNotifier itemNotifier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MonitorCard({
    Key? key,
    required this.itemNotifier,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);
  
  // 便捷的getter获取MonitorItem
  MonitorItem get monitorItem => itemNotifier.monitorItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.itemsBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部标题栏
          _buildHeader(),
          // 主要内容区域
          _buildContent(),
        ],
      ),
    );
  }

  // 构建顶部标题栏
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getAlgorithmColor().withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // 算法类型徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getAlgorithmColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              monitorItem.algorithm.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // 编辑按钮
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              Icons.edit,
              size: 16,
              color: AppColors.primary,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            tooltip: '编辑',
          ),
          // 删除按钮
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete,
              size: 16,
              color: AppColors.contentColorRed,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            tooltip: '删除',
          ),
        ],
      ),
    );
  }

  // 构建主要内容区域（左右分布）
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧信息区域
          Expanded(
            flex: 4,  // 左侧区域占卡片的40%
            child: _buildLeftInfo(),
          ),
          const SizedBox(width: 8),
          // 右侧状态区域
          Expanded(
            flex: 6,  // 右侧区域占卡片的60%  
            child: _buildRightStatus(),
          ),
        ],
      ),
    );
  }

  // 构建左侧信息区域
  Widget _buildLeftInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 静态信息部分（不会因为状态更新而重建）
        ..._buildStaticInfo(),
        
        // 添加间距
        const SizedBox(height: 8),
        
        // 动态状态部分（使用ValueListenableBuilder实现精确更新）
        ValueListenableBuilder<MonitorItemData>(
          valueListenable: itemNotifier,
          builder: (context, data, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 监测状态 - 动态更新
                _buildInlineInfoItem('监测状态', data.status.displayName),
                const SizedBox(height: 8),
                
                // 监测值 - 动态更新
                _buildInlineInfoItem('监测值', data.monitorValue.displayText),
                const SizedBox(height: 8),
                
                // 当前过阈次数 - 动态更新
                _buildInlineInfoItem('过阈次数', '${data.currentOverCount}次'),
              ],
            );
          },
        ),
      ],
    );
  }
  
  // 构建静态信息（不会因为状态更新而重建）
  List<Widget> _buildStaticInfo() {
    return [
      // 标题
      _buildInlineInfoItem('Title', monitorItem.title, maxLines: 2),
      const SizedBox(height: 8),
      
      // 描述
      if (monitorItem.description.isNotEmpty) ...[
        _buildInlineInfoItem('描述', monitorItem.description, maxLines: 3),
        const SizedBox(height: 8),
      ],
      
      // Key
      _buildInlineInfoItem('Key', monitorItem.key, maxLines: 2),
      const SizedBox(height: 8),
      
      // 监测频率
      _buildInlineInfoItem('频率', monitorItem.frequency.displayName),
      const SizedBox(height: 8),
      
      // 算法特定信息
      ..._buildAlgorithmSpecificInfo(),
    ];
  }

  // 构建右侧状态区域（使用稳定Key避免Grafana图表重新加载）
  Widget _buildRightStatus() {
    // 如果有Grafana URL，显示图表；否则显示基本信息
    if (monitorItem.grafanaUrl != null && monitorItem.grafanaUrl!.isNotEmpty) {
      return Container(
        // 使用稳定的Key确保Grafana图表不会因为状态更新而重建
        key: ValueKey('grafana_${monitorItem.id}_${monitorItem.grafanaUrl.hashCode}'),
        width: double.infinity,
        height: 300, // 设置固定高度，让图表可以动态调整
        decoration: BoxDecoration(
          color: AppColors.pageBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: HtmlChartSample(
            title: '${monitorItem.title} - 监控图表',
            htmlUrl: monitorItem.grafanaUrl!,
          ),
        ),
      );
    } else {
      // 如果没有Grafana URL，不显示任何东西
      return Container(
        key: ValueKey('empty_chart_${monitorItem.id}'),
        height: 200, // 与图表区域保持相同高度
        child: const Column(),
      );
    }
  }

  // 构建行内信息项（标题和内容支持多行显示）
  Widget _buildInlineInfoItem(String label, String value, {int? maxLines}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label：',
            style: TextStyle(
              color: AppColors.mainTextColor2,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: AppColors.mainTextColor1,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }

  // 构建算法特定信息
  List<Widget> _buildAlgorithmSpecificInfo() {
    switch (monitorItem.algorithm) {
      case MonitorAlgorithm.absoluteThreshold:
        return [
          if (monitorItem.upperThreshold != null)
            _buildInlineInfoItem('上限', monitorItem.upperThreshold!.toString()),
          if (monitorItem.lowerThreshold != null) ...[
            const SizedBox(height: 6),
            _buildInlineInfoItem('下限', monitorItem.lowerThreshold!.toString()),
          ],
          if (monitorItem.consecutiveTriggerCount != null) ...[
            const SizedBox(height: 6),
            _buildInlineInfoItem('连续次数', monitorItem.consecutiveTriggerCount!.toString()),
          ],
        ];
        
      case MonitorAlgorithm.threeSigma:
        return [
          if (monitorItem.consecutiveTriggerCount != null)
            _buildInlineInfoItem('连续次数', monitorItem.consecutiveTriggerCount!.toString()),
        ];
        
      default:
        // AI模型算法（Informer, TimesNet, Autoformer等）
        return [
          if (monitorItem.consecutiveDeviationCount != null)
            _buildInlineInfoItem('偏离次数', monitorItem.consecutiveDeviationCount!.toString()),
        ];
    }
  }

  // 获取算法对应的颜色
  Color _getAlgorithmColor() {
    switch (monitorItem.algorithm) {
      case MonitorAlgorithm.absoluteThreshold:
        return AppColors.contentColorBlue;
      case MonitorAlgorithm.threeSigma:
        return AppColors.contentColorOrange;
      default:
        // AI模型算法（Informer, TimesNet, Autoformer等）
        return AppColors.contentColorPurple;
    }
  }

}