# A股纪律助手

基于 Flutter 的跨平台（Android / iOS / Web）A 股个股纪律扫描应用。

## 快速开始

```bash
flutter pub get
flutter run                 # 手机/模拟器
flutter run -d chrome       # Web（东财若受 CORS 限制会明确报错）
```

项目说明与纪律规则见 [CLAUDE.md](./CLAUDE.md)。

Android 使用 `compileSdk 36`、`targetSdk 36`，已在 Pixel 10 Pro
Android 16（API 36）模拟器验证。构建环境需使用 Android Studio 自带 JDK 17 或更高版本。

## 功能概览

- **真实行情**：东方财富报价、日 K、1/5/15 分钟 K 和当日分时；失败不混入假数据
- **信号**：按跑路纪律、跳空、二高点、板块联动和自定义规则扫描
- **持仓 / 自选**：本地持久化，支持搜索添加
- **开盘监控**：09:30–09:45/09:50 分钟级监控，信号去重、本地通知和历史记录
- **纪律**：启停、阈值调整、版本历史、条件组合、试跑、JSON 导入导出
- **大模型**：自定义 OpenAI 兼容 Base URL、模型名与安全 Token，用于个股解读和规则草稿
- **数据源**：东方财富公开接口（默认）或用户主动启用的演示 K 线

## 后台说明

应用前台可以按 30–120 秒间隔监控。Android/iOS 后台由系统约 15 分钟尽力调度，
不能保证准点；Web 页面关闭后不能继续运行。可靠的闭屏实时推送需要服务端和 FCM/APNs。

## 验证

```bash
flutter analyze
flutter test
flutter build apk --release
flutter build web --release
```

APK 输出到 `build/app/outputs/flutter-apk/app-release.apk`。当前 Release
构建为便于本地安装仍使用调试签名，正式发布前请替换为自己的发布签名和唯一应用 ID。

本软件不构成投资建议。
