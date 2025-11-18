import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:alarm_front/config/app_config.dart';
import 'package:alarm_front/presentation/resources/app_resources.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dotted_border/dotted_border.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

class GrafanaDashboardPage extends StatefulWidget {
  const GrafanaDashboardPage({Key? key}) : super(key: key);

  @override
  State<GrafanaDashboardPage> createState() => _GrafanaDashboardPageState();
}

class _GrafanaDashboardPageState extends State<GrafanaDashboardPage> {
  // 服务器地址 - 从 AppConfig 读取
  String get _apiUrl => AppConfig().dashboardUploadUrl;
  
  // 上传记录
  final List<UploadRecord> _uploadRecords = [];
  
  // 文件拖拽区高亮状态
  bool _isDragging = false;
  
  @override
  void initState() {
    super.initState();
    // 检查服务器连接状态
    _checkServerStatus();
  }
  
  // 检查服务器状态
  Future<void> _checkServerStatus() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig().dashboardStatusUrl),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] != 'success') {
          _showSnackBar('Grafana服务异常: ${data['message']}');
        }
      } else {
        _showSnackBar('无法连接到服务器');
      }
    } catch (e) {
      _showSnackBar('连接服务器失败: $e');
    }
  }
  
  // 显示Snackbar消息
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.itemsBackground,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // 验证JSON格式
  (bool, String) _validateJsonFormat(String jsonStr) {
    try {
      json.decode(jsonStr);
      return (true, '');
    } on FormatException catch (e) {
      final errorMessage = 'JSON格式错误: ${e.message}';
      _showSnackBar(errorMessage);
      return (false, errorMessage);
    }
  }
  
  // 验证必要字段
  (bool, String) _validateRequiredFields(Map<String, dynamic> jsonData) {
    const requiredFields = ['title', 'tags', 'panels', 'time'];
    final missingFields = <String>[];
    
    for (final field in requiredFields) {
      if (!jsonData.containsKey(field)) {
        missingFields.add(field);
      }
    }
    
    if (missingFields.isNotEmpty) {
      final errorMessage = '缺少必要字段: ${missingFields.join(", ")}';
      _showSnackBar(errorMessage);
      return (false, errorMessage);
    }
    
    return (true, '');
  }
  
  // 处理文件上传
  Future<void> _handleFileUpload(
      {List<int>? fileBytes, String? fileName, XFile? file}) async {
    if (file != null) {
      // 使用传入的fileName（如果有）或从file中获取
      fileName = fileName ?? file.name;
      fileBytes = await file.readAsBytes();
    }

    if (fileBytes == null || fileName == null) {
      _showSnackBar('未能获取文件内容');
      return;
    }

    // 确保文件名以.json结尾
    if (!fileName.toLowerCase().endsWith('.json')) {
      fileName = '$fileName.json';
    }

    // 添加上传记录
    final record = UploadRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      uploadTime: DateTime.now(),
      status: UploadStatus.jsonValidating,
    );
    
    setState(() {
      _uploadRecords.insert(0, record);
    });
    
    // 验证JSON格式
    String fileContent;
    try {
      fileContent = utf8.decode(fileBytes);
      final (isValid, errorMessage) = _validateJsonFormat(fileContent);
      if (!isValid) {
        _updateRecordStatus(record.id, UploadStatus.jsonError,
            errorMessage: errorMessage);
        return;
      }
    } catch (e) {
      final errorMessage = '文件无法读取或解码: $e';
      _updateRecordStatus(record.id, UploadStatus.jsonError, errorMessage: errorMessage);
      _showSnackBar(errorMessage);
      return;
    }
    
    // 验证必要字段
    final jsonData = json.decode(fileContent);
    _updateRecordStatus(record.id, UploadStatus.fieldsValidating);
    
    final (isValid, errorMessage) = _validateRequiredFields(jsonData);
    if (!isValid) {
      _updateRecordStatus(record.id, UploadStatus.fieldsMissing,
          errorMessage: errorMessage);
      return;
    }
    
    // 开始上传
    _updateRecordStatus(record.id, UploadStatus.uploading);
    
    try {
      // 准备multipart请求
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      
      // 添加文件，并设置正确的Content-Type
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType('application', 'json'), // 明确设置Content-Type为application/json
        ),
      );
      
      // 添加请求头，确保服务器知道这是JSON文件
      request.headers['Accept'] = 'application/json';
      
      // 发送请求
      final startTime = DateTime.now();
      final response = await request.send().timeout(const Duration(seconds: 30));
      
      // 处理响应
      final responseData = await response.stream.toBytes();
      final responseString = utf8.decode(responseData);
      final responseJson = json.decode(responseString);
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      if (response.statusCode == 200 && responseJson['status'] == 'success') {
        // 上传成功
        _updateRecordStatus(
          record.id, 
          UploadStatus.success, 
          url: responseJson['url'],
          duration: duration,
        );
      } else {
        // 上传失败
        _updateRecordStatus(
          record.id, 
          UploadStatus.grafanaError,
          errorMessage: responseJson['message'],
          duration: duration,
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        _updateRecordStatus(record.id, UploadStatus.timeout);
      } else {
        _updateRecordStatus(record.id, UploadStatus.serverError, errorMessage: e.toString());
      }
    }
  }
  
  // 更新上传记录状态
  void _updateRecordStatus(
    String id, 
    UploadStatus status, {
    String? url, 
    String? errorMessage,
    Duration? duration,
  }) {
    setState(() {
      final recordIndex = _uploadRecords.indexWhere((r) => r.id == id);
      if (recordIndex != -1) {
        _uploadRecords[recordIndex] = _uploadRecords[recordIndex].copyWith(
          status: status,
          url: url,
          errorMessage: errorMessage,
          duration: duration,
        );
      }
    });
  }
  
  // 选择文件并上传
  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true, // 确保获取文件数据
      );
      
      if (result != null && result.files.isNotEmpty) {
        final platFile = result.files.first;
        
        // 确保文件名以.json结尾（这对服务器验证至关重要）
        String fileName = platFile.name;
        if (!fileName.toLowerCase().endsWith('.json')) {
          fileName = '$fileName.json';
        }
        
        // 简化处理逻辑，确保获取正确数据
        List<int>? fileBytes;
        
        if (platFile.bytes != null) {
          // Web平台或已加载字节
          fileBytes = platFile.bytes!;
        } else if (platFile.path != null && !kIsWeb) {
          // 非Web平台且有路径时读取文件
          try {
            fileBytes = await File(platFile.path!).readAsBytes();
          } catch (e) {
            _showSnackBar('读取文件失败: $e');
            return;
          }
        }
        
        if (fileBytes != null) {
          // 直接使用字节和文件名上传，避免再次通过XFile读取
          await _handleFileUpload(
            fileBytes: fileBytes,
            fileName: fileName
          );
        } else {
          _showSnackBar('无法获取文件内容');
        }
      }
    } catch (e) {
      _showSnackBar('选择文件失败: $e');
    }
  }
  
  // 复制URL到剪贴板
  Future<void> _copyUrlToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    _showSnackBar('URL已复制到剪贴板');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户自定义图表'),
        backgroundColor: Colors.white.withOpacity(0.2),
      ),
      backgroundColor: AppColors.pageBackground,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽上传区域
            DropTarget(
              onDragDone: (detail) async {
                if (detail.files.isNotEmpty) {
                  final file = detail.files.first;
                  if (file.name.endsWith('.json')) {
                    await _handleFileUpload(file: file);
                  } else {
                    _showSnackBar('请上传JSON格式的文件');
                  }
                }
              },
              onDragEntered: (detail) {
                setState(() {
                  _isDragging = true;
                });
              },
              onDragExited: (detail) {
                setState(() {
                  _isDragging = false;
                });
              },
              child: GestureDetector(
                onTap: _pickAndUploadFile,
                child: DottedBorder(
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  color: _isDragging 
                      ? AppColors.primary 
                      : AppColors.mainTextColor3,
                  strokeWidth: 2,
                  dashPattern: const [8, 4],
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 64,
                          color: _isDragging 
                              ? AppColors.primary 
                              : AppColors.mainTextColor3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '拖拽上传JSON配置文件',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isDragging 
                                ? AppColors.primary 
                                : AppColors.mainTextColor1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '或点击选择文件',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mainTextColor3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // 上传记录标题
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
              child: Row(
                children: [
                  Icon(Icons.history, color: AppColors.mainTextColor1),
                  const SizedBox(width: 8),
                  Text(
                    '上传记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainTextColor1,
                    ),
                  ),
                ],
              ),
            ),
            
            // 上传记录列表
            Expanded(
              child: _uploadRecords.isEmpty
                  ? Center(
                      child: Text(
                        '暂无上传记录',
                        style: TextStyle(
                          color: AppColors.mainTextColor3,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _uploadRecords.length,
                      itemBuilder: (context, index) {
                        final record = _uploadRecords[index];
                        return _buildUploadRecordItem(record);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadFile,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // 构建上传记录项
  Widget _buildUploadRecordItem(UploadRecord record) {
    final statusInfo = _getStatusInfo(record.status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      color: AppColors.itemsBackground,
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(
          statusInfo.icon,
          color: statusInfo.color,
        ),
        title: Text(
          _getFileName(record.fileName),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.mainTextColor1,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '状态: ${statusInfo.label}',
              style: TextStyle(
                color: statusInfo.color,
              ),
            ),
            Text(
              '上传时间: ${_formatDateTime(record.uploadTime)}',
              style: TextStyle(
                color: AppColors.mainTextColor3,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: record.url != null
            ? IconButton(
                icon: const Icon(Icons.content_copy, size: 20),
                color: AppColors.primary,
                tooltip: '复制URL',
                onPressed: () => _copyUrlToClipboard(record.url!),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文件信息
                _buildInfoRow('文件名', record.fileName),
                
                // 加载耗时
                if (record.duration != null)
                  _buildInfoRow(
                    '加载耗时', 
                    '${record.duration!.inSeconds}.${record.duration!.inMilliseconds % 1000} 秒'
                  ),
                
                // URL信息
                if (record.url != null)
                  _buildInfoRow(
                    'URL', 
                    record.url!,
                    isUrl: true,
                    onTap: () => _copyUrlToClipboard(record.url!),
                  ),
                
                // 错误信息
                if (record.errorMessage != null)
                  _buildInfoRow('错误信息', record.errorMessage!),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建信息行
  Widget _buildInfoRow(String label, String value, {bool isUrl = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.mainTextColor1,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                value,
                style: TextStyle(
                  color: isUrl ? AppColors.primary : AppColors.mainTextColor2,
                  decoration: isUrl ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 获取文件名缩写
  String _getFileName(String fullPath) {
    final name = path.basename(fullPath);
    return name.length > 20 ? '${name.substring(0, 17)}...' : name;
  }
  
  // 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} '
        '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}';
  }
  
  // 将数字格式化为两位数
  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }
  
  // 获取状态信息
  StatusInfo _getStatusInfo(UploadStatus status) {
    switch (status) {
      case UploadStatus.jsonValidating:
        return StatusInfo(
          label: 'JSON格式校验中',
          icon: Icons.hourglass_empty,
          color: Colors.blue,
        );
      case UploadStatus.fieldsValidating:
        return StatusInfo(
          label: 'Grafana必要字段校验中',
          icon: Icons.hourglass_empty,
          color: Colors.blue,
        );
      case UploadStatus.uploading:
        return StatusInfo(
          label: '上传中',
          icon: Icons.upload_file,
          color: Colors.orange,
        );
      case UploadStatus.success:
        return StatusInfo(
          label: '上传成功',
          icon: Icons.check_circle,
          color: Colors.green,
        );
      case UploadStatus.jsonError:
        return StatusInfo(
          label: 'JSON格式错误',
          icon: Icons.error,
          color: Colors.red,
        );
      case UploadStatus.fieldsMissing:
        return StatusInfo(
          label: 'Grafana必要字段缺失',
          icon: Icons.error,
          color: Colors.red,
        );
      case UploadStatus.serverError:
        return StatusInfo(
          label: '服务器繁忙',
          icon: Icons.cloud_off,
          color: Colors.red,
        );
      case UploadStatus.grafanaError:
        return StatusInfo(
          label: 'Grafana配置失败',
          icon: Icons.error,
          color: Colors.red,
        );
      case UploadStatus.timeout:
        return StatusInfo(
          label: '超时',
          icon: Icons.timer_off,
          color: Colors.red,
        );
      default:
        return StatusInfo(
          label: '未知状态',
          icon: Icons.help_outline,
          color: Colors.grey,
        );
    }
  }
}

// 上传记录模型
class UploadRecord {
  final String id;
  final String fileName;
  final DateTime uploadTime;
  final UploadStatus status;
  final String? url;
  final String? errorMessage;
  final Duration? duration;
  
  UploadRecord({
    required this.id,
    required this.fileName,
    required this.uploadTime,
    required this.status,
    this.url,
    this.errorMessage,
    this.duration,
  });
  
  UploadRecord copyWith({
    String? id,
    String? fileName,
    DateTime? uploadTime,
    UploadStatus? status,
    String? url,
    String? errorMessage,
    Duration? duration,
  }) {
    return UploadRecord(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      uploadTime: uploadTime ?? this.uploadTime,
      status: status ?? this.status,
      url: url ?? this.url,
      errorMessage: errorMessage ?? this.errorMessage,
      duration: duration ?? this.duration,
    );
  }
}

// 上传状态枚举
enum UploadStatus {
  jsonValidating,
  fieldsValidating,
  uploading,
  success,
  jsonError,
  fieldsMissing,
  serverError,
  grafanaError,
  timeout,
}

// 状态信息模型
class StatusInfo {
  final String label;
  final IconData icon;
  final Color color;
  
  StatusInfo({
    required this.label,
    required this.icon,
    required this.color,
  });
} 