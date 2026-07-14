# A股纪律分析助手（stock）

## 文档定位

本文档是项目级事实来源和开发约束，供开发者与 AI 编码助手共同使用。修改代码前应先确认本文中的产品边界、数据可信原则、规则执行约定和平台限制；实现发生变化后需同步更新本文，避免文档与代码脱节。

## 项目概要

基于 Flutter 的跨平台（Android / iOS / Web）A 股个股纪律分析应用。核心能力是根据可配置、可版本化的买卖纪律，对实时报价、日 K、分钟 K 和当日分时进行扫描，输出卖出、减仓、预警等结构化信号，并在开盘窗口执行 15–20 分钟监控。

本应用提供技术分析辅助，**不构成投资建议**。实盘决策仍须用户自行判断。

### 当前实现状态

- 已接入东方财富公开行情，支持报价、搜索、日 K、1/5/15 分钟 K 和当日分时。
- 已实现自选、持仓、信号扫描、信号历史、规则编辑、开盘监控、本地通知和后台尽力调度。
- 已实现 OpenAI 兼容大模型配置、个股纪律解读和规则优化草稿。
- 已通过静态分析、自动化测试、Web Release 构建及 Android 16 真机级模拟器烟测。

## 技术栈

- Flutter 3.44.x / Dart 3.12.x
- 状态：`provider` + 页面内 `StatefulWidget` 组合
- 网络：`http`（东方财富实时报价、日 K、1/5/15 分钟 K、当日分时）
- 本地持久化：`shared_preferences`（组合、规则、阈值、信号历史）+ `flutter_secure_storage`（大模型 Token）
- 通知与后台：`flutter_local_notifications` + `workmanager`
- 目标平台：Android、iOS、Web

## 平台基线

- Android：`minSdk 30`、`compileSdk 36`、`targetSdk 36`，即最低 Android 11，目标 Android 16。
- Android 构建：使用 Android Studio 自带 JDK 17 或更高版本；已在 Pixel 10 Pro、Android 16 / API 36 模拟器验证。
- iOS：最低 iOS 14.0；后台调度依赖系统策略，不能承诺固定时刻执行。
- Web：支持主要页面与演示数据；东方财富接口可能受浏览器 CORS 限制，页面关闭后无法继续监控。

## 目录结构

```
lib/
  main.dart                 # 入口
  theme/app_theme.dart
  models/
    market_data.dart        # 行情来源、周期、元数据与异常
    rule.dart               # 规则定义、参数、条件与版本
    app_settings.dart       # 数据源、监控与大模型设置
    signal.dart             # 信号及来源、时间、规则版本元数据
  services/
    stock_api_service.dart  # 真实行情、分时、缓存、重试、Mock
    app_state.dart          # 页面状态与用例编排
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

## 核心数据流

1. 页面通过 `AppState` 发起刷新、扫描、监控、规则编辑或大模型请求。
2. `StockApiRouter` 根据设置选择东方财富或显式 Mock 数据源，并返回包含来源、数据时间和过期状态的 `MarketDataResult`。
3. `DisciplineEngine` 使用启用的 `RuleDefinition` 对行情执行确定性扫描。
4. `TradeSignal` 保存规则版本、数据来源、时间周期、匹配条件和信号分数。
5. `SignalRepository` 按股票、规则、标题和冷却时间去重；达到阈值的新增信号才能触发通知。
6. 页面只负责展示和用户交互，不应直接访问 `SharedPreferences`、安全存储或拼装行情请求。

## 不可破坏的产品约束

### 1. 行情可信

- 东方财富模式请求失败时，只允许返回此前缓存的真实数据，并明确标记 `cache`、`isStale` 和原始数据时间。
- **禁止**在真实模式失败后静默返回 Mock 数据，否则会产生看似真实的错误交易信号。
- 演示数据必须由用户主动切换，并在界面和信号元数据中明确标记。
- 所有信号应保留数据来源、数据时间、时间周期和规则版本，便于追溯。

### 2. 规则确定性

- 最终买卖信号必须由本地规则引擎产生；大模型只能解释信号或生成待确认草稿。
- 自定义规则只能组合白名单 `RuleMetric`、`RuleOperator` 和受约束参数，不执行任意 Dart、JavaScript 或远程脚本。
- 参数保存前必须校验类型和范围；修改已保存规则时生成新版本，不覆盖历史事实。

### 3. 密钥安全

- Token 只存入 `flutter_secure_storage`，不得写入普通偏好、日志、异常信息、规则 JSON 或版本库。
- 除 localhost 调试外，大模型 Base URL 必须使用 HTTPS。
- Web 端不应长期保存供应商 Token；生产环境优先通过自有服务端代理。

### 4. 平台能力如实表达

- 不得把移动端系统的周期后台任务描述为秒级实时监控或可靠推送。
- Web 页面关闭后不能继续执行本地轮询。
- 可靠的闭屏分钟级监控需要服务端行情任务和 FCM/APNs，不属于当前纯客户端能力。

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

- `eastmoney`：默认数据源，使用东方财富公开 HTTP 接口获取实时报价、日 K、分钟 K 和分时，无需 Token；Web 端可能受 CORS 限制。
- `mock`：内置演示 K 线，仅用于离线演示、自动化测试和 Web 调试，必须由用户主动选择。

`StockApiConfig.customBaseUrl` 和行情 Token 当前仅为预留字段，尚未形成可用的私有行情协议。新增私有数据源时必须先定义接口契约、鉴权、错误语义、来源标记和测试，不得仅替换 URL 后宣称可用。

## 主要用户流程

1. **自选 / 持仓**：添加股票代码（如 `600519`、`000001`）。
2. **信号**：对自选+持仓批量跑纪律引擎，按规则分组展示卖出/减仓/预警。
3. **个股详情**：查看报价、近况要点、命中纪律与操作建议。
4. **开盘监控**：09:30 后按 30–120 秒拉取一分钟分时，检查跳空、冲高、回落与量能。
5. **纪律**：启停、调整阈值、版本历史、自定义条件、JSON 导入导出和 AI 优化草稿。
6. **设置**：数据源、通知、后台状态、大模型 Base URL/Token/模型名与连接测试。

## 状态与持久化职责

- `AppState`：应用用例编排、加载状态、错误状态和页面通知；避免继续膨胀纯数据转换逻辑。
- `PortfolioRepository`：自选与持仓。
- `SettingsRepository`：数据源、通知、监控阈值和大模型非敏感配置。
- `RuleRepository`：规则定义与版本。
- `SignalRepository`：信号历史、去重和数量限制。
- `SecureTokenRepository`：大模型 Token。
- 新增持久化字段时必须兼容旧 JSON 缺失字段，提供安全默认值，避免升级后启动失败。

## 规则扩展约定

- 内置规则由 `DefaultRules` 提供参数 Schema，执行实现注册在 `DisciplineEngine`。
- 用户规则由受约束的 `RuleCondition` 组合，不执行任意 Dart/脚本代码。
- 所有保存都会校验参数范围并生成版本历史；AI 只能生成草稿，用户确认并保存后才生效。
- 新增内置纪律时同时添加默认参数、规则实现、试跑与边界测试。

## 监控与通知限制

- 默认监控窗口为 09:30–09:50，前台默认每 45 秒轮询，可在界面调整。
- 默认阈值：跳空 3%、冲高 2%、高点回落 1.5%、分钟相对量能 1.5 倍、信号冷却 60 分钟、最低通知分数 60。
- 前台服务只在用户启用监控且处于交易窗口时按秒级设置轮询；手动检查可以显式强制执行。
- Android/iOS 后台任务由 `workmanager` 以最短约 15 分钟周期注册，并要求网络连接；实际执行时间由操作系统决定。
- Web 页面关闭后不能继续监控。真正可靠的闭屏实时推送需要单独部署服务端并接入 FCM/APNs。
- 同一股票、规则和标题在冷却时间内不得重复通知。

## 大模型安全

- 兼容 OpenAI Chat Completions 风格的 HTTPS Base URL、模型名和 Bearer Token。
- 手机端 Token 存入系统安全存储，不写入普通偏好、日志或规则导出。
- 除 localhost 外拒绝 HTTP 明文地址。Web 端建议使用自有代理，不建议长期保存供应商 Token。
- 大模型仅解释真实行情和纪律信号，不参与规则引擎的确定性判定。
- 规则优化响应中的参数名、类型和范围必须再次由本地代码校验；无法识别的字段直接拒绝。

## 开发约定

- 产出与 UI 文案使用 **简体中文**。
- 用户可见错误需说明影响、数据来源和可执行的解决方式，禁止吞掉异常或伪造成功状态。
- 新增纪律：在 `disciplines/` 新增规则类、在 `DefaultRules` 声明参数并在 `DisciplineEngine` 注册。
- 规则阈值尽量可调（比率、窗口天数），避免魔法数散落在 UI。
- 不提交密钥；若接入需 Token 的行情商，用 `--dart-define` 或本地未跟踪配置。
- UI 保持 Material 3 风格；业务阈值和网络行为不得散落在 Widget 中。
- 修改模型序列化、规则引擎、行情解析、监控去重或 Token 安全逻辑时，必须补充对应测试。

## 变更检查清单

### 新增或修改纪律

1. 在 `DefaultRules` 定义稳定 ID、参数 Schema、默认值和范围。
2. 在 `DisciplineEngine` 注册执行器，或使用受约束的自定义条件执行路径。
3. 信号填充规则版本、匹配条件、数据来源和周期。
4. 验证规则编辑、版本历史、JSON 导入导出和试跑。
5. 添加正常命中、阈值边界、无数据及非法参数测试。

### 修改行情能力

1. 返回 `MarketDataResult`，不得丢失来源和数据时间。
2. 区分网络失败、解析失败、空数据和缓存过期。
3. 保证真实模式不回退 Mock。
4. 为解析、缓存和错误传播增加测试。

### 修改监控或通知

1. 同时验证前台轮询、后台单次检查、信号去重和最低分数。
2. Android 通知小图标必须放在 `res/drawable`，并由 `res/raw/keep.xml` 保留，防止 Release 资源压缩删除。
3. 在 Android 16 Release APK 上验证启动、通知权限、通知展示及 WorkManager 注册。

## 测试与验收

- `test/discipline_engine_test.dart`：内置纪律对演示行情的基础扫描。
- `test/market_data_service_test.dart`：东方财富分时解析、真实失败传播、显式 Mock。
- `test/rule_system_test.dart`：规则序列化、参数范围、自定义规则执行。
- `test/monitor_service_test.dart`：开盘跳空、冲高、回落监控。
- `test/repository_test.dart`：信号冷却去重。
- `test/llm_service_test.dart`：规则草稿参数校验和 HTTPS 安全。
- `test/widget_test.dart`：应用启动及主要页面烟测。
- 提交前至少执行 `dart format`、`flutter analyze` 和 `flutter test`。
- 涉及平台配置时还需构建对应产物；Android 发布路径必须额外执行 Release 模拟器烟测。

## 运行

```bash
flutter pub get
flutter run                 # 默认设备
flutter run -d chrome       # Web
dart format lib test
flutter analyze
flutter test
flutter build apk --release
flutter build web --release
```

Android Release APK 输出到 `build/app/outputs/flutter-apk/app-release.apk`。

## 发布前必须处理

- 将 `com.example.stock` 替换为正式且唯一的应用 ID，并同步 iOS Bundle ID 和后台任务标识。
- 配置 Android Release keystore；当前 Release 构建仍使用调试签名，只适合本地安装验证。
- 配置正式应用名称、图标、版本策略、隐私政策和行情服务合规说明。
- 若要求可靠闭屏实时通知，部署服务端监控并接入 FCM/APNs。
- 验证真实设备上的网络权限、通知权限、省电策略和后台限制。

## 免责声明

本软件信号仅供学习与个人辅助决策。股市有风险，亏钱不退。
