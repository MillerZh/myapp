# A股纪律分析助手（stock）

## 项目概要

基于 Flutter 的跨平台（Android / iOS / Web）A 股个股分析应用。核心能力：根据可配置的「买卖纪律」规则，对日 K / 量价等数据进行扫描，输出买入/卖出/减仓等信号与建议。

本应用提供技术分析辅助，**不构成投资建议**。实盘决策仍须用户自行判断。

## 技术栈

- Flutter 3.x / Dart 3.x
- 状态：`provider` + 页面内 `StatefulWidget` 组合
- 网络：`http`（东方财富实时报价、日 K、1/5/15 分钟 K、当日分时）
- 本地持久化：`shared_preferences`（组合、规则、阈值、信号历史）+ `flutter_secure_storage`（大模型 Token）
- 通知与后台：`flutter_local_notifications` + `workmanager`
- 目标平台：Android、iOS、Web

## 目录结构

```
lib/
  main.dart                 # 入口
  theme/app_theme.dart
  models/                   # 行情、信号、规则、设置与AI结构化模型
  services/
    stock_api_service.dart  # 真实行情、分时、缓存、重试、Mock
    app_repositories.dart   # 组合/规则/设置/历史/安全Token仓储
    monitor_service.dart    # 开盘15–20分钟前台监控
    notification_service.dart
    background_task_service.dart
    llm_service.dart        # OpenAI兼容接口
  disciplines/              # 纪律规则实现（可扩展）
    discipline_engine.dart  # 统一扫描入口
    exit_discipline.dart    # 跑路/减仓纪律
    gap_up_discipline.dart  # 跳空高开相关
    second_high_discipline.dart  # 二高点与深度回撤
    sector_correlation.dart # 板块联动（银行/证券 vs 科技）
  screens/                  # 底栏、监控、规则编辑、详情与设置
  widgets/                  # SignalCard 等可复用组件
  data/demo_data.dart       # 演示用 K 线与股票池
```

## 已实现纪律（源自老师规则整理）

### 1. 板块联动量化因子
- 若 **银行 + 证券** 板块短期急速拉升，则提示 **科技** 板块可能掉头向下。
- 用于宏观/板块层预警，不直接给单票买卖价。

### 2. 深度回撤与「二高点」
- 远离历史高点后，不宜期待立即 V 反；需时间构筑 **低于前高的二高点**。
- 光纤/PCB 等急跌标的：套牢盘重，消化期更长；缓跌（如部分锂矿）相对更易修复。
- 持仓宜轻；被套者可借二高点附近减仓离场。

### 3. 跑路纪律（傻瓜版）
1. **缩量破位 → 出一半**  
   - 上升趋势（多数收盘在 5 日线上方且 5 日线向上）：跌破 5 日线且当日量能短于近几日 → 减半。  
   - 箱体：跌破箱体下沿 → 减半。
2. **巨量 → 出一半**  
   - 当日量创观察窗口新高，且高于近 5 日均量约 20%–30%以上 → 减半。
3. **放量破位 → 全部跑**  
   - 同时满足缩量破位类破位与巨量条件 → 清仓。
4. **动能衰竭（择优）**  
   - 连阳后出现长上影、长下影或十字星/纺锤线，提示短线见顶风险。

### 4. 跳空高开纪律
- 大幅跳空高开后，开盘 **15–20 分钟**内急速冲高 → 可先减仓落袋。
- 跳空后收 **小阳/带长影线**（未能走出大阳）：买力不足；长上影偏出货，长下影偏诱多（尾盘拉升美化 K 线），需警惕。

## 数据源说明

| 模式 | 说明 |
|------|------|
| `eastmoney` | 东方财富公开 HTTP 接口（实时报价、日 K、分钟 K、分时），无需 Token；Web 端可能受 CORS 限制 |
| `mock` | 内置演示 K 线，便于离线与 Web 调试 |

真实模式失败时只使用此前缓存的真实数据并标记过期，**绝不静默混入演示数据**。演示数据必须由用户主动选择。

## 主要用户流程

1. **自选 / 持仓**：添加股票代码（如 `600519`、`000001`）。
2. **信号**：对自选+持仓批量跑纪律引擎，按规则分组展示卖出/减仓/预警。
3. **个股详情**：查看报价、近况要点、命中纪律与操作建议。
4. **开盘监控**：09:30 后按 30–120 秒拉取一分钟分时，检查跳空、冲高、回落与量能。
5. **纪律**：启停、调整阈值、版本历史、自定义条件、JSON 导入导出和 AI 优化草稿。
6. **设置**：数据源、通知、后台状态、大模型 Base URL/Token/模型名与连接测试。

## 规则扩展约定

- 内置规则由 `DefaultRules` 提供参数 Schema，执行实现注册在 `DisciplineEngine`。
- 用户规则由受约束的 `RuleCondition` 组合，不执行任意 Dart/脚本代码。
- 所有保存都会校验参数范围并生成版本历史；AI 只能生成草稿，用户确认并保存后才生效。
- 新增内置纪律时同时添加默认参数、规则实现、试跑与边界测试。

## 监控与通知限制

- 应用前台时可以按设置的 30–120 秒轮询。
- Android/iOS 后台任务最小约 15 分钟，执行时间由操作系统决定；iOS 不保证在 09:50 准点唤醒。
- Web 页面关闭后不能继续监控。真正可靠的闭屏实时推送需要单独部署服务端并接入 FCM/APNs。

## 大模型安全

- 兼容 OpenAI Chat Completions 风格的 HTTPS Base URL。
- 手机端 Token 存入系统安全存储，不写入普通偏好、日志或规则导出。
- 除 localhost 外拒绝 HTTP 明文地址。Web 端建议使用自有代理，不建议长期保存供应商 Token。
- 大模型仅解释真实行情和纪律信号，不参与规则引擎的确定性判定。

## 开发约定

- 产出与 UI 文案使用 **简体中文**。
- 新增纪律：在 `disciplines/` 新增规则类、在 `DefaultRules` 声明参数并在 `DisciplineEngine` 注册。
- 规则阈值尽量可调（比率、窗口天数），避免魔法数散落在 UI。
- 不提交密钥；若接入需 Token 的行情商，用 `--dart-define` 或本地未跟踪配置。

## 运行

```bash
flutter pub get
flutter run                 # 默认设备
flutter run -d chrome       # Web
flutter analyze
flutter test
flutter build apk
flutter build web
```

## 免责声明

本软件信号仅供学习与个人辅助决策。股市有风险，亏钱不退。
