import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'alarm_sound_service.dart';

/// Web端具体实现 - 提供完整音频功能
class AlarmSoundServiceImpl implements AlarmSoundService {
  bool _isEnabled = true;
  bool _isInitialized = false;
  
  // 音频池，用于支持多个同时播放
  final List<html.AudioElement> _audioPool = [];
  int _currentAudioIndex = 0;
  static const int _maxAudioInstances = 5;

  /// 初始化音频服务
  @override
  void initialize() {
    if (_isInitialized || !kIsWeb) return;
    
    try {
      // 创建音频池，支持多个同时播放
      for (int i = 0; i < _maxAudioInstances; i++) {
        html.AudioElement audioElement = html.AudioElement();
        audioElement.preload = 'auto';
        audioElement.volume = 0.8; // 设置音量为80%
        
        // 设置音频文件路径
        const String soundPath = 'sounds/alarm_notification.mp3';
        audioElement.src = soundPath;
        audioElement.load();
        
        _audioPool.add(audioElement);
      }
      
      _isInitialized = true;
      debugPrint('<Info> AlarmSoundService Web端初始化成功 (音频池大小: $_maxAudioInstances)');
    } catch (e) {
      debugPrint('<Error> AlarmSoundService Web端初始化失败: $e');
      _isInitialized = false;
    }
  }

  /// 播放报警提示音
  @override
  void playAlarmSound({String? alarmLevel}) {
    if (!_isEnabled || !_isInitialized || !kIsWeb) return;
    
    try {
      // 统一播放一次提示音
      int playCount = _getPlayCountByLevel(alarmLevel);
      
      // 播放提示音
      _playWebAudioSound(playCount, alarmLevel);
    } catch (e) {
      debugPrint('<Warning> 音频播放失败，尝试备用方案: $e');
      _playFallbackSound();
    }
  }

  /// 使用Web Audio API播放提示音
  void _playWebAudioSound(int count, String? alarmLevel) {
    if (!kIsWeb) return;
    
    try {
      // 直接使用备用方案，避免Web Audio API兼容性问题
      for (int i = 0; i < count; i++) {
        Future.delayed(Duration(milliseconds: i * 300), () {
          _playFallbackSound();
        });
      }
      
      debugPrint('<Info> 播放报警提示音 (级别: $alarmLevel)');
    } catch (e) {
      debugPrint('<Error> 音频播放失败: $e');
      _playFallbackSound();
    }
  }

  /// 播放音频
  void _playFallbackSound() {
    if (!kIsWeb || _audioPool.isEmpty) return;
    
    try {
      // 轮转使用音频池中的实例，确保多个音频可以同时播放
      html.AudioElement audioToPlay = _getAvailableAudio();
      
      audioToPlay.currentTime = 0;
      audioToPlay.play().then((_) {
        debugPrint('<Info> 播放报警提示音成功 (实例: $_currentAudioIndex)');
      }).catchError((error) {
        debugPrint('<Warning> 音频播放失败: $error');
        // 如果本地文件播放失败，尝试使用浏览器默认提示音
        _playBrowserNotification();
      });
    } catch (e) {
      debugPrint('<Warning> 音频播放失败: $e');
      _playBrowserNotification();
    }
  }

  /// 获取可用的音频实例
  html.AudioElement _getAvailableAudio() {
    // 寻找当前未播放的音频实例
    for (int i = 0; i < _audioPool.length; i++) {
      html.AudioElement audio = _audioPool[i];
      if (audio.paused || audio.ended) {
        _currentAudioIndex = i;
        return audio;
      }
    }
    
    // 如果所有实例都在播放，使用轮转方式
    _currentAudioIndex = (_currentAudioIndex + 1) % _audioPool.length;
    html.AudioElement selectedAudio = _audioPool[_currentAudioIndex];
    
    // 强制停止当前播放并重新开始
    selectedAudio.pause();
    selectedAudio.currentTime = 0;
    
    debugPrint('<Info> 强制使用音频实例 $_currentAudioIndex (所有实例都在播放中)');
    return selectedAudio;
  }

  /// 使用浏览器默认通知音
  void _playBrowserNotification() {
    try {
      // 使用Web Notification API的默认提示音
      if (html.Notification.permission == 'granted') {
        final notification = html.Notification('报警提醒',
          body: '',
          icon: 'favicon.png',
        );
        // 立即关闭通知，只保留声音
        Future.delayed(const Duration(milliseconds: 100), () {
          notification.close();
        });
        debugPrint('<Info> 使用浏览器默认提示音');
      } else {
        debugPrint('<Warning> 没有通知权限，无法播放默认提示音');
      }
    } catch (e) {
      debugPrint('<Warning> 浏览器默认提示音播放失败: $e');
    }
  }

  /// 根据报警级别获取播放次数
  int _getPlayCountByLevel(String? alarmLevel) {
    // 统一所有级别的报警都只播放一次
    return 1;
  }

  /// 启用/禁用提示音
  @override
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('<Info> 报警提示音${enabled ? '已启用' : '已禁用'}');
  }

  /// 检查是否启用
  @override
  bool get isEnabled => _isEnabled;

  /// 检查是否已初始化
  @override
  bool get isInitialized => _isInitialized;

  /// 测试播放提示音
  @override
  void testSound({String? level}) {
    if (!_isInitialized) {
      debugPrint('<Warning> AlarmSoundService未初始化，无法测试播放');
      return;
    }
    
    debugPrint('<Info> 测试播放报警提示音');
    playAlarmSound(alarmLevel: level);
  }

  /// 释放资源
  @override
  void dispose() {
    if (_isInitialized) {
      try {
        // 释放音频池中的所有音频实例
        for (html.AudioElement audio in _audioPool) {
          audio.pause();
          audio.src = '';
        }
        _audioPool.clear();
        _currentAudioIndex = 0;
      } catch (e) {
        debugPrint('<Warning> 音频资源释放时出错: $e');
      }
      
      _isInitialized = false;
      debugPrint('<Info> AlarmSoundService Web端已释放资源');
    }
  }
}

/// 创建Web端特定的实现
AlarmSoundService createAlarmSoundService() => AlarmSoundServiceImpl();