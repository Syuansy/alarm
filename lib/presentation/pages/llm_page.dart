import 'package:alarm_front/config/app_config.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LLMPage extends StatefulWidget {
  const LLMPage({Key? key}) : super(key: key);

  @override
  State<LLMPage> createState() => _LLMPageState();
}

class _LLMPageState extends State<LLMPage> {
  String selectedTimeRange = 'Last 30min';
  String selectedAppId = 'ALL';
  String selectedLevel = 'ALL';
  String selectedKeyword = '';
  List<Map<String, dynamic>> llmData = [];
  bool isLoading = false;
  
  // 分页相关状态
  int currentPage = 1;
  int totalPages = 1;
  int totalCount = 0;
  int pageSize = 100;
  
  // 页面跳转控制器
  final TextEditingController _pageJumpController = TextEditingController();
  
  // 关键词文本框控制器和历史记录
  final TextEditingController _keywordController = TextEditingController();
  List<String> _keywordHistory = [];

  final List<String> timeRangeOptions = [
    'Last 30min',
    'Last 6h', 
    'Today',
    'Last 2days',
    'Last 7days'
  ];
  
  final List<String> appIdOptions = [
    'ALL',
    'ro-spmt-0',
    'ro-spmt-1',
    'ro-spmt-2',
    'ro-spmt-3',
    'ro-spmt-4',
    'ro-spmt-5',
    'ro-spmt-6',
    'ro-spmt-7',
    'ro-spmt-8'
    // 动态添加的应用ID选项
  ];
  
  final List<String> levelOptions = [
    'ALL',
    'Debug',
    'Info',
    'Warn',
    'Error',
    'Fatal'
  ];

  @override
  void initState() {
    super.initState();
    // 初始加载数据
    _fetchLLMData();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _pageJumpController.dispose();
    super.dispose();
  }

  // 添加关键词到历史记录
  void _addKeywordToHistory(String keyword) {
    if (keyword.trim().isEmpty) return;
    
    // 移除重复的关键词
    _keywordHistory.remove(keyword);
    // 添加到开头
    _keywordHistory.insert(0, keyword);
    // 只保留最近5个
    if (_keywordHistory.length > 5) {
      _keywordHistory = _keywordHistory.take(5).toList();
    }
  }

  // 将显示文本转换为API参数
  String _getTimeRangeParam(String displayText) {
    switch (displayText) {
      case 'Last 30min':
        return '30min';
      case 'Last 6h':
        return '6h';
      case 'Today':
        return 'today';
      case 'Last 2days':
        return '2days';
      case 'Last 7days':
        return '7days';
      default:
        return '30min';
    }
  }

  // 将级别显示文本转换为API参数
  String _getLevelParam(String displayText) {
    switch (displayText) {
      case 'Debug':
        return '1';
      case 'Info':
        return '2';
      case 'Warn':
        return '3';
      case 'Error':
        return '4';
      case 'Fatal':
        return '5';
      default:
        return displayText; // 对于'ALL'或其他值直接返回
    }
  }

  // 获取LLM数据
  Future<void> _fetchLLMData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final timeParam = _getTimeRangeParam(selectedTimeRange);
      
      // 构建查询参数
      List<String> queryParams = [
        'limit=$pageSize',
        'page=$currentPage',
        'time_range=$timeParam'
      ];
      
      // 如果app_id不是ALL，添加app_id参数
      if (selectedAppId != 'ALL' && selectedAppId.isNotEmpty) {
        queryParams.add('app_id=$selectedAppId');
      }
      
      // 如果level不是ALL，添加level参数
      if (selectedLevel != 'ALL' && selectedLevel.isNotEmpty) {
        final levelParam = _getLevelParam(selectedLevel);
        queryParams.add('level=$levelParam');
      }
      
      // 获取文本框中的关键词
      String keyword = _keywordController.text.trim();
      if (keyword.isNotEmpty) {
        queryParams.add('keyword=$keyword');
        // 添加到历史记录
        _addKeywordToHistory(keyword);
      }
      
      final url = '${AppConfig().llmHistoryUrl}?${queryParams.join('&')}';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          final data = List<Map<String, dynamic>>.from(jsonData['data']);
          
          // 解析分页信息
          final pagination = jsonData['pagination'];
          if (pagination != null) {
            totalPages = pagination['total_pages'] ?? 1;
            totalCount = pagination['total_count'] ?? 0;
          } else {
            // 兼容旧版本API
            totalPages = 1;
            totalCount = data.length;
          }
          
          setState(() {
            llmData = data;
          });
        } else {
          _showError('获取数据失败: ${jsonData['message']}');
        }
      } else {
        _showError('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _showError('请求失败: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 显示错误信息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // 分页相关方法
  void _goToPage(int page) {
    if (page >= 1 && page <= totalPages && page != currentPage && !isLoading) {
      setState(() {
        currentPage = page;
      });
      _fetchLLMData();
    }
  }

  void _goToPreviousPage() {
    if (currentPage > 1) {
      _goToPage(currentPage - 1);
    }
  }

  void _goToNextPage() {
    if (currentPage < totalPages) {
      _goToPage(currentPage + 1);
    }
  }

  void _goToFirstPage() {
    _goToPage(1);
  }

  void _goToLastPage() {
    _goToPage(totalPages);
  }

  // 跳转到指定页面
  void _jumpToPage() {
    final pageText = _pageJumpController.text.trim();
    if (pageText.isEmpty) return;
    
    final page = int.tryParse(pageText);
    if (page != null && page >= 1 && page <= totalPages) {
      _goToPage(page);
      _pageJumpController.clear();
      // 隐藏键盘
      FocusScope.of(context).unfocus();
    } else {
      _showError('请输入有效的页码 (1-$totalPages)');
    }
  }

  // 重置分页状态
  void _resetPagination() {
    setState(() {
      currentPage = 1;
      totalPages = 1;
      totalCount = 0;
    });
  }

  // 构建关键词文本框
  Widget _buildKeywordTextField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: AppColors.itemsBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _keywordController,
              style: TextStyle(
                color: AppColors.mainTextColor1,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: '关键词搜索',
                hintStyle: TextStyle(
                  color: AppColors.mainTextColor2,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (value) {
                // 回车时触发搜索
                if (!isLoading) {
                  _resetPagination();
                  _fetchLLMData();
                }
              },
            ),
          ),
          // 历史记录按钮
          if (_keywordHistory.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.history,
                color: AppColors.mainTextColor2,
                size: 20,
              ),
              offset: const Offset(0, 40),
              color: AppColors.itemsBackground,
              onSelected: (String value) {
                _keywordController.text = value;
              },
              itemBuilder: (BuildContext context) {
                return _keywordHistory.map((String keyword) {
                  return PopupMenuItem<String>(
                    value: keyword,
                    child: Text(
                      keyword,
                      style: TextStyle(
                        color: AppColors.mainTextColor1,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
        ],
      ),
    );
  }

  // 构建下拉框的辅助方法
  Widget _buildDropdown({
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
    required String hint,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: AppColors.itemsBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: DropdownButton<String>(
        value: options.contains(value) ? value : options.first,
        isExpanded: true,
        underline: Container(),
        dropdownColor: AppColors.itemsBackground,
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: AppColors.mainTextColor1,
        ),
        style: TextStyle(
          color: AppColors.mainTextColor1,
          fontSize: 14,
        ),
        onChanged: onChanged,
        items: options.map<DropdownMenuItem<String>>((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Text(
                option.isEmpty ? '请选择$hint' : option,
                style: TextStyle(
                  color: option.isEmpty 
                      ? AppColors.mainTextColor2 
                      : AppColors.mainTextColor1,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部查询区域
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppColors.itemsBackground,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Column(
            children: [
              // 单行：时间范围、应用ID、级别、关键词、查询按钮
              Row(
                children: [
                  // 应用ID下拉框
                  Expanded(
                    flex: 2,
                    child: _buildDropdown(
                      value: selectedAppId,
                      options: appIdOptions,
                      hint: '应用ID',
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedAppId = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 级别下拉框
                  Expanded(
                    flex: 2,
                    child: _buildDropdown(
                      value: selectedLevel,
                      options: levelOptions,
                      hint: '级别',
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedLevel = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 时间范围下拉框
                  Expanded(
                    flex: 2,
                    child: _buildDropdown(
                      value: selectedTimeRange,
                      options: timeRangeOptions,
                      hint: '时间范围',
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedTimeRange = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 关键词文本框
                  Expanded(
                    flex: 2,
                    child: _buildKeywordTextField(),
                  ),
                  const SizedBox(width: 12),
                  // 查询按钮
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8.0),
                    child: InkWell(
                      onTap: isLoading ? null : () {
                        _resetPagination();
                        _fetchLLMData();
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 数据列表
        Expanded(
          child: llmData.isEmpty && !isLoading
              ? _buildEmptyState()
              : _buildDataList(),
        ),
      ],
    );
  }


  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Colors.white60,
          ),
          SizedBox(height: 16),
          Text(
            '暂无LLM分析记录',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: llmData.length + (totalPages > 1 ? 1 : 0),
      itemBuilder: (context, index) {
        // 如果是最后一项且有分页，显示分页组件
        if (index == llmData.length && totalPages > 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: _buildPaginationWidget(),
          );
        }
        // 否则显示LLM分析项
        return _buildLLMCard(llmData[index]);
      },
    );
  }

  Widget _buildLLMCard(Map<String, dynamic> llmItem) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.itemsBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：时间、应用ID、级别
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 时间
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      llmItem['time'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // 应用ID
                  Flexible(
                    child: Text(
                      llmItem['app_id'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainTextColor1,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 级别
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getLevelColor(llmItem['level'] ?? 0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getLevelDisplayText(llmItem['level'] ?? 0),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 第二行：内容
              Text(
                'Content: ${llmItem['content'] ?? ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mainTextColor1,
                ),
              ),
              const SizedBox(height: 8),
              // 第三行：LLM分析结果
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.pageBackground,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${llmItem['llm_analyze'] ?? '暂无分析结果'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mainTextColor2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 将数字级别转换为显示文本
  String _getLevelDisplayText(int level) {
    switch (level) {
      case 1: return 'Debug';
      case 2: return 'Info';
      case 3: return 'Warn';
      case 4: return 'Error';
      case 5: return 'Fatal';
      default: return 'Unknown';
    }
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 1: return Colors.grey;
      case 2: return Colors.green;
      case 3: return Colors.orange;
      case 4: return Colors.red;
      case 5: return Colors.purple;
      default: return Colors.grey;
    }
  }

  // 构建分页组件（复用alarm页面的逻辑）
  Widget _buildPaginationWidget() {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
      ),
      child: Column(
        children: [
          // 显示统计信息
          Text(
            '共 $totalCount 条记录，第 $currentPage/$totalPages 页',
            style: TextStyle(
              color: AppColors.mainTextColor2,
              fontSize: 12,
            ),
          ),
          // 分页按钮区域
          Column(
            children: [
              // 主分页按钮行
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 首页按钮
                  _buildPageButton(
                    icon: Icons.first_page,
                    onPressed: currentPage > 1 ? _goToFirstPage : null,
                    tooltip: '首页',
                  ),
                  // 上一页按钮
                  _buildPageButton(
                    icon: Icons.chevron_left,
                    onPressed: currentPage > 1 ? _goToPreviousPage : null,
                    tooltip: '上一页',
                  ),
                  // 页码按钮
                  ..._buildPageNumbers(),
                  // 下一页按钮
                  _buildPageButton(
                    icon: Icons.chevron_right,
                    onPressed: currentPage < totalPages ? _goToNextPage : null,
                    tooltip: '下一页',
                  ),
                  // 末页按钮
                  _buildPageButton(
                    icon: Icons.last_page,
                    onPressed: currentPage < totalPages ? _goToLastPage : null,
                    tooltip: '末页',
                  ),
                ],
              ),
              // 页面跳转输入行
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '跳转到',
                    style: TextStyle(
                      color: AppColors.mainTextColor2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 60,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.pageBackground,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: TextField(
                      controller: _pageJumpController,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: AppColors.mainTextColor1,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: currentPage.toString(),
                        hintStyle: TextStyle(
                          color: AppColors.mainTextColor2,
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        isCollapsed: true,
                      ),
                      onSubmitted: (_) => _jumpToPage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '页',
                    style: TextStyle(
                      color: AppColors.mainTextColor2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTap: _jumpToPage,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: const Text(
                          '跳转',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建页码按钮
  Widget _buildPageButton({
    IconData? icon,
    String? text,
    VoidCallback? onPressed,
    bool isSelected = false,
    String? tooltip,
  }) {
    final widget = Material(
      color: isSelected 
          ? AppColors.primary 
          : (onPressed != null ? AppColors.itemsBackground : AppColors.borderColor),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: isSelected 
                      ? Colors.white 
                      : (onPressed != null ? AppColors.mainTextColor1 : AppColors.mainTextColor2),
                )
              : Text(
                  text ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected 
                        ? Colors.white 
                        : (onPressed != null ? AppColors.mainTextColor1 : AppColors.mainTextColor2),
                  ),
                ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: widget,
      );
    }
    return widget;
  }

  // 构建页码数字按钮
  List<Widget> _buildPageNumbers() {
    List<Widget> widgets = [];
    
    // 计算要显示的页码范围
    int start = (currentPage - 1).clamp(1, totalPages);
    int end = (currentPage + 1).clamp(1, totalPages);
    
    // 确保至少显示5个页码（如果总页数允许）
    if (end - start < 3) {
      if (start == 1) {
        end = (start + 3).clamp(1, totalPages);
      } else if (end == totalPages) {
        start = (end - 3).clamp(1, totalPages);
      }
    }
    
    // 如果开始页码大于1，显示第一页和省略号
    if (start > 1) {
      widgets.add(_buildPageButton(
        text: '1',
        onPressed: () => _goToPage(1),
      ));
      if (start > 2) {
        widgets.add(Container(
          width: 20,
          height: 36,
          alignment: Alignment.center,
          child: Text(
            '...',
            style: TextStyle(
              color: AppColors.mainTextColor2,
              fontSize: 14,
            ),
          ),
        ));
      }
      widgets.add(const SizedBox(width: 4));
    }
    
    // 显示页码范围
    for (int i = start; i <= end; i++) {
      widgets.add(_buildPageButton(
        text: i.toString(),
        isSelected: i == currentPage,
        onPressed: i == currentPage ? null : () => _goToPage(i),
      ));
      if (i < end) {
        widgets.add(const SizedBox(width: 4));
      }
    }
    
    // 如果结束页码小于总页数，显示省略号和最后一页
    if (end < totalPages) {
      widgets.add(const SizedBox(width: 4));
      if (end < totalPages - 1) {
        widgets.add(Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Text(
            '...',
            style: TextStyle(
              color: AppColors.mainTextColor2,
              fontSize: 14,
            ),
          ),
        ));
      }
      widgets.add(_buildPageButton(
        text: totalPages.toString(),
        onPressed: () => _goToPage(totalPages),
      ));
    }
    
    return widgets;
  }
}