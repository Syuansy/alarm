// Readout Link卡片展示检测器数量

import 'package:flutter/material.dart';
import 'package:alarm_front/util/shared_data_service.dart';

class ReadoutLinkCard extends StatefulWidget {
  const ReadoutLinkCard({Key? key}) : super(key: key);

  @override
  State<ReadoutLinkCard> createState() => _ReadoutLinkCardState();
}

class _ReadoutLinkCardState extends State<ReadoutLinkCard> {
  // 存储从共享数据服务获取的检测器数据
  Map<String, Map<String, int>> _detectors = {};
  
  // 共享数据服务
  final SharedDataService _dataService = SharedDataService();

  @override
  void initState() {
    super.initState();
    // 注册检测器数据监听器
    _dataService.addDetectorListener(_handleDetectorUpdate);
  }

  @override
  void dispose() {
    // 移除检测器数据监听器
    _dataService.removeDetectorListener(_handleDetectorUpdate);
    super.dispose();
  }
  
  // 处理检测器数据更新
  void _handleDetectorUpdate(Map<String, Map<String, int>> detectors) {
    setState(() {
      _detectors = detectors;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 从_detectors创建DetectorItem列表用于渲染
    final List<DetectorItem> detectorItems = _detectors.entries.map((entry) {
      final String title = entry.key;
      final Map<String, int> tags = entry.value;
      
      // 创建标签项列表
      final List<TagItem> tagItems = tags.entries.map((tagEntry) {
        return TagItem(
          label: tagEntry.key,
          count: tagEntry.value,
        );
      }).toList();
      
      return DetectorItem(
        title: title,
        tags: tagItems,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
              child: Text(
                'Readout Link',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 使用Wrap作为响应式容器
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 根据容器宽度决定布局方式
                  int columns;
                  
                  // 根据宽度决定列数
                  if (constraints.maxWidth < 320) {
                    columns = 1; // 极窄屏：1列
                  } else if (constraints.maxWidth < 480) {
                    columns = 2; // 窄屏：2列
                  } else {
                    columns = 3; // 宽屏：3列
                  }
                  
                  // 计算项目宽度
                  double itemWidth = (constraints.maxWidth - ((columns - 1) * 8)) / columns;
                  
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detectorItems.map((detector) => 
                      SizedBox(
                        width: itemWidth,
                        child: _buildDetectorButton(detector),
                      )
                    ).toList(),
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetectorButton(DetectorItem detector) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 小标题
            Flexible(
              flex: 1,
              child: Text(
                detector.title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 标签组 - 使用SingleChildScrollView处理可能的溢出
            Flexible(
              flex: 2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: detector.tags.map((tag) => _buildTag(tag)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(TagItem tag) {
    Color tagColor;
    switch (tag.label) {
      case 'ALL':
        tagColor = Colors.cyanAccent;
        break;
      case 'WF':
        tagColor = Colors.lightBlueAccent;
        break;
      case 'T/Q':
        tagColor = Colors.greenAccent;
        break;
      case 'CD':
        tagColor = Colors.orangeAccent;
        break;
      case 'WP':
        tagColor = Colors.purpleAccent;
        break;
      default:
        tagColor = Colors.lightBlueAccent;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              tag.label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            tag.count.toString(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// 数据模型
class DetectorItem {
  final String title;
  final List<TagItem> tags;

  DetectorItem({required this.title, required this.tags});
}

class TagItem {
  final String label;
  final int count;

  TagItem({required this.label, required this.count});
} 