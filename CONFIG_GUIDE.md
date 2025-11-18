# JUNOMonitor 配置指南

本文档说明如何修改 JUNOMonitor 应用的配置，以便项目迁移和变动。

## 📋 目录

- [快速开始](#快速开始)
- [配置文件说明](#配置文件说明)
- [易于修改的配置](#易于修改的配置)
- [需要手动修改的配置](#需要手动修改的配置)
- [特殊配置说明](#特殊配置说明)
- [完整配置项列表](#完整配置项列表)

---

## 🚀 快速开始

### 步骤 1：修改配置文件

打开 `lib/config/app_config.json` 文件，修改您需要的配置项。

**最常修改的配置：**

```json
{
  "backend": {
    "baseUrl": "http://10.3.192.122:8001",
    "alarmHistoryUrl": "http://10.3.192.122:8001/api/alarm/history",
    "grafanaBaseUrl": "http://10.3.192.122:3000"
  },
  "websocket": {
    "url": "ws://10.3.192.122:8001/ws"
  }
}
```

### 步骤 2：检查是否需要手动修改

- 如果您只修改了 IP 地址和端口，**无需修改其他文件**，直接重启应用即可
- 如果您修改了应用名称、包名等，请按照配置文件中的 `_manual_files` 提示修改对应文件

### 步骤 3：重启应用

```bash
# Web 版
flutter run -d chrome

# Android 版（需要重新编译）
flutter build apk --release --target-platform android-arm64

# iOS 版（需要重新编译）
flutter build ios --release
```

---

## 📄 配置文件说明

### 主配置文件

**路径：** `lib/config/app_config.json`

这是统一的配置文件，包含所有可配置项。配置文件由 `lib/config/app_config.dart` 读取和解析。

### 配置分类

配置项分为两类：

1. **✅ 易于修改的配置**：修改后重启应用即可生效
2. **⚠️ 需要手动修改的配置**：需要修改原生配置文件，然后重新编译应用

---

## ✅ 易于修改的配置

以下配置可以直接在 `app_config.json` 中修改，重启应用即可生效：

### 1. 后端服务配置

```json
{
  "backend": {
    "baseUrl": "http://10.3.192.122:8001",
    "alarmApiBase": "http://10.3.192.122:8001/api/alarm",
    "alarmHistoryUrl": "http://10.3.192.122:8001/api/alarm/history",
    "llmHistoryUrl": "http://10.3.192.122:8001/api/alarm/llm/history",
    "dashboardUploadUrl": "http://10.3.192.122:8001/api/dashboard/upload",
    "dashboardStatusUrl": "http://10.3.192.122:8001/api/dashboard/status",
    "grafanaBaseUrl": "http://10.3.192.122:3000"
  }
}
```

**说明：**
- 所有 API 端点都配置为完整的 URL，直接使用无需拼接
- 包含 Grafana 服务器地址配置
- 修改 IP 或端口时，需要同步修改所有相关 URL
- 配置清晰直观，所见即所得

**影响范围：**
- 报警历史查询 API
- LLM 对话历史 API
- Grafana 仪表盘服务
- 所有后端服务调用

### 2. WebSocket 配置

```json
{
  "websocket": {
    "url": "ws://10.3.192.122:8001/ws",  // WebSocket 完整连接地址
    "heartbeatInterval": 30,              // 心跳间隔（秒）
    "heartbeatTimeout": 60,               // 心跳超时（秒）
    "maxReconnectAttempts": 5             // 最大重连次数
  }
}
```

**说明：**
- 直接配置完整的 WebSocket URL
- 修改 URL 后，WebSocket 会自动重新连接
- 可以调整心跳和重连参数优化连接稳定性

**影响范围：**
- 实时数据推送
- 图表数据更新
- 报警状态监控

### 3. Grafana 配置特别说明

Grafana 配置已合并到 `backend` 配置中的 `grafanaBaseUrl` 字段。

**⚠️ 特别注意：**
修改 `grafanaBaseUrl` 后，还需要**批量替换** `lib/config/chart_config.json` 文件中的所有 Grafana URL（约 73 处）。

**批量替换方法：**
1. 打开 `lib/config/chart_config.json`
2. 使用文本编辑器的"查找替换"功能
3. 查找：`http://10.3.192.122:3000`
4. 替换为：您的新 Grafana 地址（如 `http://192.168.1.100:3000`）

---

## ⚠️ 需要手动修改的配置

以下配置需要修改原生配置文件，修改后需要重新编译应用：

### 1. 应用名称

**修改位置：**

| 平台 | 文件路径 | 行号 | 修改内容 |
|------|---------|------|---------|
| Web | `web/index.html` | 32 | `<title>JUNOMonitor</title>` |
| Web | `web/index.html` | 26 | `<meta name="apple-mobile-web-app-title" content="JUNOMonitor">` |
| Web | `web/manifest.json` | 2, 3 | `"name"` 和 `"short_name"` |
| Android | `android/app/src/main/AndroidManifest.xml` | 30 | `android:label="JUNOMonitor"` |
| iOS | `ios/Runner/Info.plist` | 10, 18 | `CFBundleDisplayName` 和 `CFBundleName` |
| Dart | `lib/presentation/resources/app_texts.dart` | - | 已改为从配置读取 |

**示例：**

修改 Web 标题：
```html
<!-- web/index.html line 32 -->
<title>您的应用名称</title>
```

修改 Android 应用名称：
```xml
<!-- android/app/src/main/AndroidManifest.xml line 30 -->
<application android:label="您的应用名称" ...>
```

修改 iOS 应用名称：
```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleDisplayName</key>
<string>您的应用名称</string>
```

### 2. 应用包名 / Bundle ID

**修改位置：**

| 平台 | 文件路径 | 行号 | 修改内容 |
|------|---------|------|---------|
| Android | `android/app/src/main/AndroidManifest.xml` | 2 | `package="dev.flchart.app"` |
| Android | `android/app/build.gradle` | 15 | `namespace = "dev.flchart.app"` |
| Android | `android/app/build.gradle` | 30 | `applicationId "dev.flchart.app"` |
| iOS | `ios/Runner.xcodeproj/project.pbxproj` | 多处 | 搜索 `PRODUCT_BUNDLE_IDENTIFIER` 并修改所有出现的地方 |

**示例：**

修改 Android 包名：
```gradle
// android/app/build.gradle
android {
    namespace = "com.yourcompany.yourapp"
    defaultConfig {
        applicationId "com.yourcompany.yourapp"
        ...
    }
}
```

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.yourapp">
```

修改 iOS Bundle ID：
1. 打开 `ios/Runner.xcodeproj/project.pbxproj`
2. 搜索 `PRODUCT_BUNDLE_IDENTIFIER`
3. 将所有 `dev.flchart.app` 替换为 `com.yourcompany.yourapp`

### 3. 项目描述和版本

**修改位置：**

```yaml
# pubspec.yaml
name: alarm_front                                      # 项目名称
description: JUNOMonitor is a Jiangmen neutrino...   # 项目描述
version: 1.1.5+10105                                  # 版本号+构建号
```

---

## 🔧 特殊配置说明

### Grafana URL 批量替换

Grafana 的 URL 在 `lib/config/chart_config.json` 中硬编码了约 73 处，需要批量替换。

**使用 VS Code 批量替换：**

1. 打开 `lib/config/chart_config.json`
2. 按 `Ctrl + H` (Windows/Linux) 或 `Cmd + H` (Mac) 打开查找替换
3. 查找：`http://10.3.192.122:3000`
4. 替换为：您的新地址（如 `http://192.168.1.100:3000`）
5. 点击"全部替换"

**使用命令行批量替换：**

```bash
# Linux/Mac
sed -i 's|http://10.3.192.122:3000|http://192.168.1.100:3000|g' lib/config/chart_config.json

# Windows PowerShell
(Get-Content lib\config\chart_config.json) -replace 'http://10.3.192.122:3000', 'http://192.168.1.100:3000' | Set-Content lib\config\chart_config.json
```

---

## 📊 完整配置项列表

### 应用基础配置

| 配置项 | 默认值 | 说明 | 修改方式 |
|--------|--------|------|----------|
| `app.name` | `JUNOMonitor` | 应用名称 | ✅ 修改配置文件 + ⚠️ 修改原生文件 |
| `app.description` | `JUNOMonitor is a...` | 应用描述 | ⚠️ 修改 `pubspec.yaml` |
| `app.version` | `1.1.5` | 版本号 | ⚠️ 修改 `pubspec.yaml` |
| `app.buildNumber` | `10105` | 构建号 | ⚠️ 修改 `pubspec.yaml` |

### 后端服务配置

| 配置项 | 默认值 | 说明 | 修改方式 |
|--------|--------|------|----------|
| `backend.baseUrl` | `http://10.3.192.122:8001` | 后端基础地址 | ✅ 修改配置文件即可 |
| `backend.alarmApiBase` | `http://10.3.192.122:8001/api/alarm` | 报警 API 基础地址 | ✅ 修改配置文件即可 |
| `backend.alarmHistoryUrl` | `http://10.3.192.122:8001/api/alarm/history` | 报警历史 URL | ✅ 修改配置文件即可 |
| `backend.llmHistoryUrl` | `http://10.3.192.122:8001/api/alarm/llm/history` | LLM 历史 URL | ✅ 修改配置文件即可 |
| `backend.dashboardUploadUrl` | `http://10.3.192.122:8001/api/dashboard/upload` | 仪表盘上传 URL | ✅ 修改配置文件即可 |
| `backend.dashboardStatusUrl` | `http://10.3.192.122:8001/api/dashboard/status` | 服务状态 URL | ✅ 修改配置文件即可 |
| `backend.grafanaBaseUrl` | `http://10.3.192.122:3000` | Grafana 服务器地址 | ✅ 修改配置文件 + 🔄 批量替换 chart_config.json |

**说明：** 🔄 修改 Grafana 地址后需要批量替换 `lib/config/chart_config.json` 中的 URL（约 73 处）

### WebSocket 配置

| 配置项 | 默认值 | 说明 | 修改方式 |
|--------|--------|------|----------|
| `websocket.url` | `ws://10.3.192.122:8001/ws` | WebSocket 完整连接地址 | ✅ 修改配置文件即可 |
| `websocket.heartbeatInterval` | `30` | 心跳间隔（秒） | ✅ 修改配置文件即可 |
| `websocket.heartbeatTimeout` | `60` | 心跳超时（秒） | ✅ 修改配置文件即可 |
| `websocket.maxReconnectAttempts` | `5` | 最大重连次数 | ✅ 修改配置文件即可 |

### 平台特定配置

| 配置项 | 默认值 | 说明 | 修改方式 |
|--------|--------|------|----------|
| `platform.android.packageName` | `dev.flchart.app` | Android 包名 | ⚠️ 修改原生文件 |
| `platform.ios.bundleId` | `dev.flchart.app` | iOS Bundle ID | ⚠️ 修改原生文件 |

---

## 🔍 配置验证

修改配置后，可以通过以下方式验证：

### 1. 查看控制台输出

应用启动时会打印配置信息：

```
<Info> 应用配置加载成功
========== 应用配置信息 ==========
应用名称: JUNOMonitor
后端地址: http://10.3.192.122:8001
WebSocket: ws://10.3.192.122:8001/ws
Grafana: http://10.3.192.122:3000
================================
```

### 2. 检查网络连接

- **后端 API**：打开报警历史页面，查看是否能正常加载数据
- **WebSocket**：查看图表页面，观察数据是否实时更新
- **Grafana**：打开仪表盘页面，查看 Grafana 图表是否正常显示

---

## 📝 注意事项

1. **修改配置前请备份**：建议先备份原配置文件
2. **测试后再部署**：在测试环境验证配置正确后再部署到生产环境
3. **注意协议匹配**：如果使用 HTTPS/WSS，确保服务器支持
4. **Grafana URL 特别注意**：修改 Grafana 配置后必须同步更新 `chart_config.json`
5. **包名修改需谨慎**：修改包名后需要重新签名和发布应用

---

## 🆘 常见问题

### Q: 修改配置后应用无法连接到服务器？

**A:** 请检查：
1. IP 地址和端口是否正确
2. 服务器是否正常运行
3. 防火墙是否允许访问
4. 协议是否匹配（http/https, ws/wss）

### Q: 修改应用名称后，部分地方仍显示旧名称？

**A:** 应用名称需要在多个地方修改：
1. `app_config.json` 中的 `app.name`
2. Web: `web/index.html` 和 `web/manifest.json`
3. Android: `android/app/src/main/AndroidManifest.xml`
4. iOS: `ios/Runner/Info.plist`

### Q: Grafana 图表无法显示？

**A:** 请检查：
1. 是否修改了 `app_config.json` 中的 Grafana 配置
2. 是否批量替换了 `chart_config.json` 中的所有 Grafana URL
3. Grafana 服务器是否正常运行
4. URL 格式是否正确

---

## 📞 技术支持

如有问题，请联系开发团队或查看项目文档。

**相关文件：**
- 配置文件：`lib/config/app_config.json`
- 配置管理类：`lib/config/app_config.dart`
- 项目说明：`README.md`
