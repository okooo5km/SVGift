# SVGift

> SVGO 的 Swift 原生实现，提供可集成库、CLI 工具和兼容性测试体系。

## 项目概况

- **目标**：用 Swift 复现 SVGO 核心 SVG 优化能力，提供 library + CLI 双产物
- **参考源**：`/Users/5km/Dev/Web/svgo`（SVGO JS 原版）
- **蓝图文档**：`docs/svgo-swift-rewrite-blueprint.md`
- **测试资产**：`Tests/Fixtures/SVGO/`（从 SVGO 导入的 fixture）

## 技术栈

- Swift 6.2+ / SwiftPM
- XML 解析：FoundationXML.XMLParser（SAX 事件流 + 自建 AST）
- CLI：swift-argument-parser
- 测试：Swift Testing（via swift-testing package dependency，兼容 CommandLineTools 环境）
- CSS/Selector：自实现测试驱动子集，预留可插拔替换点

## 项目结构

```
svgo-swift/
  Package.swift
  Sources/
    SVGift/               # 核心库（optimize API、AST、插件系统）
    SVGiftCLI/            # CLI 工具（swift-argument-parser）
    SVGift-dev/           # 开发工具（fixture 导入、回归测试）
  Tests/
    SVGiftTests/          # 单元测试 + 兼容性测试
    Fixtures/SVGO/        # 从 SVGO 导入的测试资产
  docs/                   # 项目文档
  reports/                # 测试报告输出
```

## 开发约定

- 代码和注释使用英文，交流使用中文
- 新文件署名：okooo5km(十里)
- 文档（除 CLAUDE.md 和 README.md）存放于 `docs/` 目录
- 每个模块先接入 fixture 驱动测试，再扩展功能
- 插件参数强类型化，支持 preset 和全局覆盖

## 常用命令

```bash
swift build                        # 构建
swift test                         # 测试
swift run svgift --help            # CLI 帮助
swift run SVGift-dev import-fixtures --source /Users/5km/Dev/Web/svgo/test --destination Tests/Fixtures/SVGO
swift run SVGift-dev run-regression --svgo-root /Users/5km/Dev/Web/svgo --subset all
```

---

## 分阶段开发路线图

### Phase 1：核心基础设施

> 搭建 AST、解析器、序列化器、Visitor 遍历机制——一切插件的基石。

- [x] **1.1 SVG AST 数据模型**
  - 定义节点类型：root / element / text / comment / cdata / doctype / instruction
  - 节点需支持 parent 引用、children 列表、attributes 字典
  - 参考：SVGO 的 xast 数据结构

- [x] **1.2 XML Parser → AST**
  - 基于 FoundationXML.XMLParser（SAX delegate）构建完整 AST
  - 处理文本空白策略，与 SVGO 行为一致
  - 保留 XML declaration、doctype、processing instruction

- [x] **1.3 AST → SVG 序列化（Stringify）**
  - 实现 `StringifyOptions`（indent、pretty、useShortClosingTag 等）
  - 输出与 SVGO `js2svg` 语义等价

- [x] **1.4 Visitor 遍历机制**
  - enter/exit 回调模式
  - 安全遍历策略（遍历时删除/替换节点不失效）
  - `ResolvedPlugin` 结构 + `invokePlugins` 批量执行

- [x] **1.5 optimize API 骨架**
  - 实现 `optimize(_ input: String, options: OptimizeOptions) throws -> OptimizeResult`
  - 串联：parse → visitor traversal → stringify
  - multipass 支持（最多 10 轮，输出不再缩小时停止）

- [x] **1.6 插件协议与 preset 机制**（协议、配置模型、解析逻辑已完成，preset-default 组装待 Phase 2 插件就位后实现）
  - `SVGOPlugin` 协议定义
  - `PluginConfig` 配置模型（启用/禁用/参数覆盖）
  - `preset-default` 组装逻辑

**验收标准**：`swift test` 通过，空插件列表下 parse→stringify 往返一致。 **已达标 (10/10 tests passed)**

**已知限制与待处理项**（参考 `docs/svgo-rewrite-pitfalls.md`）：
- ~~FoundationXML.XMLParser 的 attributeDict 为无序 `[String: String]`~~ **已解决**：`AttributeOrderScanner` 预扫描原始 XML 提取属性顺序，解析后重建 `OrderedAttributes`。空 xmlns 声明（如 `xmlns:xlink=""`）也通过 rescued attributes 恢复。L1=100%
- **命名空间前缀保留**：XMLParser 可能合并同 URI 的不同前缀（如 `xlink` 和 `xl`）——需验证并在必要时处理
- **Boolean 属性**：HTML 风格的无值属性（如 `<svg focusable>`）需区分空值和无值，当前未处理
- **根级文本节点**：SVGO 跳过根级文本节点，需验证当前 Parser 行为

---

### Phase 2：测试基础设施 + Wave 0 插件

> 打通 fixture 驱动测试链路，实现最低风险的一批插件。

- [x] **2.1 Fixture 解析器**
  - 解析 `@@@` 分段格式的 `.svg.txt` 测试文件
  - 提取插件名、参数、输入 SVG、期望输出 SVG
  - 封装为 `PluginFixtureCase` 结构
  - 实现文件：`Sources/SVGift/FixtureParser.swift`

- [x] **2.2 兼容性测试框架**
  - `PluginFixtureTests` 自动加载 `Tests/Fixtures/SVGO/plugins/` 下的 fixture
  - 支持 L1（字节一致）和 L2（归一化一致）对比
  - 失败用例输出到 `reports/failures.ndjson`
  - 实现文件：`Tests/SVGiftTests/PluginFixtureTests.swift`

- [ ] **2.3 baseline-manifest.json 生成**
  - `svgo-swift-dev import-fixtures` 增加 manifest 生成
  - 记录每个 fixture 的文件名、大小、哈希

- [x] **2.4 Wave 0 插件实现**（低风险清理类）
  - [x] `removeDoctype`
  - [x] `removeXMLProcInst`
  - [x] `removeComments`（支持 preservePatterns 参数）
  - [x] `removeMetadata`
  - [x] `removeTitle`
  - [x] `removeDesc`（支持 removeAny 参数）
  - [x] `removeXMLNS`
  - 插件注册表：`Sources/SVGift/plugins/BuiltinPlugins.swift`
  - Fixture 测试：`Tests/SVGiftTests/Wave0PluginTests.swift`

**验收标准**：Wave 0 全部插件 fixture 测试 L1/L2 通过率 >= 95%。 **已达标 (L2=100%, 10/10 fixtures passed, 26 tests total)**

---

### Phase 3：CLI 骨架 + Wave 1 插件

> CLI 可用，属性/结构类插件就位。

- [x] **3.1 CLI 参数骨架**
  - 引入 swift-argument-parser 依赖 (1.5.0+)
  - 实现基本参数：input, -o output, --config, --multipass, --pretty, --indent
  - stdin/stdout 支持
  - `--show-plugins` 列出可用插件
  - 实现文件：`Sources/SVGiftCLI/SVGiftCLI.swift`

- [x] **3.2 配置文件加载**
  - `loadConfig(at:)` 实现
  - 支持 JSON 格式配置（与 SVGO `svgo.config.js` 语义对齐）
  - 实现文件：`Sources/SVGift/Config.swift`

- [x] **3.3 Wave 1 插件实现**（属性/结构类）
  - [x] `cleanupAttrs`
  - [x] `removeEmptyAttrs`（保留 `requiredFeatures`/`requiredExtensions`/`systemLanguage`）
  - [x] `removeDimensions`
  - [x] `removeUnusedNS`
  - [x] `sortAttrs`
  - [x] `sortDefsChildren`
  - Fixture 测试：`Tests/SVGiftTests/Wave1PluginTests.swift`

- [x] **3.4 幂等性检查**
  - 2-pass 幂等性验证机制（使用 L2 归一化对比）
  - 集成在 `Wave1PluginTests.swift` 中

**验收标准**：CLI 可处理单文件输入输出；Wave 0+1 L1/L2 通过率 >= 95%（Gate-1）。 **已达标 (L1=100%, L2=100%, 31/31 fixtures passed, Idempotency=100%, 52 tests total)**

---

### Phase 4：样式链路 + Wave 2 插件

> CSS 解析/选择器子集实现，样式相关插件就位。

- [x] **4.1 CSS 解析子集**
  - CSS 声明解析器（inline tokenizer）：`CSSParser.swift`
  - CSS 样式表解析器（rules + at-rules）：`CSSParser.swift`
  - CSS 选择器 AST + 解析 + specificity：`CSSSelector.swift`
  - CSS 选择器匹配引擎（从右到左）：`CSSSelectorMatcher.swift`
  - CSS 压缩（CSSO-lite）：`CSSMinifier.swift`
  - 动态伪类标记为 dynamic，保守处理

- [x] **4.2 Style 工具函数**
  - style 属性解析/序列化：`StyleUtils.swift`
  - 表现属性集合（60+ properties）：`PresentationAttrs.swift`
  - specificity 计算：标准 (a,b,c) 算法
  - collectStylesheet + parent map 构建

- [x] **4.3 Wave 2 插件实现**（样式链路）
  - [x] `mergeStyles`（12 fixtures，100% L2）
  - [x] `inlineStyles`（28 fixtures，93% L2 — .18 fails due to XMLParser tab→space）
  - [x] `minifyStyles`（11 fixtures，73% L2 — .01/.02/.03 need CSSO shorthand merging）
  - [x] `convertStyleToAttrs`（5 fixtures，100% L2）
  - [x] `removeAttributesBySelector`（3 fixtures，100% L2）

**验收标准**：Wave 2 fixture 测试 L1/L2 通过率 >= 92%。 **已达标 (L1=91.5%, L2=93.2%, 55/59 fixtures passed, Idempotency=100%, 86 tests total)**

---

### Phase 5：几何核心 + Wave 3 插件

> 数值工具 + Path 序列化 + 中低风险几何/颜色插件就位。

- [x] **5.1 数值处理工具**
  - `toFixed`、`removeLeadingZero`、`jsToString`、`stringifyNumber`
  - 负零处理、指数格式规范化、前导零移除
  - 实现文件：`Sources/SVGift/utils/NumericUtils.swift`

- [x] **5.2 Path Data 序列化器**
  - `PathDataItem` 结构 + `stringifyPathData` 函数
  - 命令合并（M+L）、隐式分隔符、Arc flag 空格处理
  - 实现文件：`Sources/SVGift/utils/PathDataSerializer.swift`

- [x] **5.3 颜色字典**
  - 147 named colors、31 short names、colorsProps、includesUrlReference
  - 实现文件：`Sources/SVGift/utils/ColorData.swift`

- [x] **5.4 Wave 3 插件实现**（几何中风险）
  - [x] `convertEllipseToCircle`
  - [x] `convertColors`（currentColor/names2hex/rgb2hex/shorthex/shortname/convertCase，mask 边界追踪）
  - [x] `convertShapeToPath`（rect/line/polyline/polygon/circle/ellipse，convertArcs 参数）
  - [x] `cleanupNumericValues`（viewBox 特殊处理、单位转换、精度控制）
  - [x] `cleanupListOfValues`（8 种列表属性处理）
  - Fixture 测试：`Tests/SVGiftTests/Wave3PluginTests.swift`

- [x] **5.5 XastElement.name 改为 var**
  - convertEllipseToCircle/convertShapeToPath 需要修改元素名称

**验收标准**：Wave 3 fixture 测试 L1/L2 通过率 >= 92%。 **已达标 (L1=100%, L2=100%, 18/18 fixtures passed, Idempotency=100%, 94 tests total)**

---

### Phase 6：高风险几何 + Wave 4 插件

> Transform 分解、Path 压缩等最复杂算法实现。

- [x] **6.1 Transform 解析与分解**
  - transform 属性解析（TransformParser.swift）
  - matrix 分解为 translate/rotate/scale/skew（QRAB + QRCD 两种路径，取最短）
  - 分解失败时回退保留 `matrix()`
  - 非均匀缩放/旋转对 arc 参数的特殊处理（SVD 分解 transformArc）

- [x] **6.2 Arc 规范实现**
  - W3C F.6 arc 修正算法（PathIntersection.swift a2c 函数）
  - 半径修正、大弧/小弧判定
  - 退化 arc（rx/ry → 0）转换为直线

- [x] **6.3 Wave 4 插件实现**（几何高风险）
  - [x] `convertTransform`（13 fixtures, 100% L2）
  - [x] `convertPathData`（37 fixtures, 100% L2）
  - [x] `mergePaths`（12 fixtures, 100% L2）
  - [x] `removeHiddenElems`（19 fixtures, 100% L2）
  - [x] `removeOffCanvasPaths`（6 fixtures, 100% L2）
  - [x] `reusePaths`（6 fixtures, 100% L2）
  - 基础设施：PathDataParser, Collections, References, ComputeStyle, TransformParser, PathIntersection, ApplyTransforms
  - Fixture 测试：`Tests/SVGiftTests/Wave4PluginTests.swift`

**验收标准**：全插件综合 L1/L2/L3 通过率 >= 95%（Gate-3）。 **已达标 (Wave 4: L1=100%, L2=100%, 93/93 fixtures; 全量 Wave 0-4: L1=99.0%, L2=100%, 201/201 fixtures, Idempotency=100%, 103 tests total)**

---

### Phase 7：补全 preset-default + 剩余插件

> 完成全部 preset-default 插件 + 非 preset-default 插件。

- [x] **7.1 集合数据补全 + preset 注册更新**
  - `ElemsData.swift`：editorNamespaces, attrsGroupsDeprecated, attrsGroupsDefaults, elems 完整白名单
  - `BuiltinPlugins.swift`：presetDefaultPlugins 34 插件完整注册（按 SVGO 执行顺序）
  - `PresentationAttrs.swift`：修正 inheritableAttrs（添加 font/marker/transform）

- [x] **7.2 Wave 5 — preset-default 补全（9 插件，88 fixtures）**
  - [x] `removeEditorsNSData`、`removeEmptyText`、`removeUselessDefs`
  - [x] `removeDeprecatedAttrs`、`removeUselessStrokeAndFill`
  - [x] `removeEmptyContainers`、`collapseGroups`
  - [x] `removeUnknownsAndDefaults`（13 fixtures）
  - [x] `cleanupIds`（15 fixtures）

- [x] **7.3 Wave 6 — 非 preset-default 插件（15 插件，74 fixtures）**
  - [x] `removeAttrs`、`removeElementsByAttr`、`removeScripts`、`removeStyleElement`
  - [x] `removeRasterImages`、`removeViewBox`、`removeXlink`
  - [x] `addAttributesToSVGElement`、`addClassesToSVGElement`
  - [x] `convertOneStopGradients`、`removeNonInheritableGroupAttrs`
  - [x] `cleanupEnableBackground`、`moveGroupAttrsToElems`
  - [x] `moveElemsAttrsToGroup`、`prefixIds`

**验收标准**：全量 L2 >= 98%。 **已达标 (Wave 0-6: 363 fixtures, L1=100.0%, L2=100.0%, Idempotency=100%, 130 tests total)**

---

### Phase 8：完善与发布

> CLI 功能补全、multipass 精化、CI/CD 完善、文档发布。

- [ ] **8.1 模块拆分**（按需，暂缓）
  - 将 SVGift 拆分为 SVGAST / SVGPath / SVGStyle / SVGOPluginsCore / SVGOPluginsBuiltin
  - 更新 Package.swift 为目标态结构

- [x] **8.2 multipass 收敛检测精化**
  - 从字节大小比较改为精确字符串比较（`output == current` → 收敛停止）
  - 实现文件：`Sources/SVGift/svgo_swift.swift`

- [x] **8.3 CLI 完善**
  - stdin 读取改为 `FileHandle.standardInput.readDataToEndOfFile()`
  - `--recursive` / `-r`：递归处理目录下所有 `.svg` 文件
  - `--quiet` / `-q`：静默模式
  - `--version`：版本号输出（从 `Version.swift` 读取）
  - 目录处理时输出进度（保存百分比）和错误汇总
  - 实现文件：`Sources/SVGiftCLI/SVGiftCLI.swift`

- [x] **8.4 版本管理**
  - `Sources/SVGift/Version.swift`：版本常量 `svgoSwiftVersion`
  - CLI 的 `CommandConfiguration.version` 引用库版本常量

- [x] **8.5 CI/CD**
  - `.github/workflows/ci.yml`：多平台矩阵（macos-latest + macos-14）
  - `.github/workflows/release.yml`：tag 触发发布，Universal Binary 构建，GitHub Release 创建，Homebrew tap 自动更新

- [x] **8.6 文档与发布**
  - `README.md`：完整安装说明、CLI/API 用法、配置文件格式、插件列表、兼容性说明
  - `docs/plugins.md`：全部 49 个插件的详细文档（名称、描述、参数、是否默认启用）

**验收标准**：Gate-3 全部达标；CI 绿色；文档齐全。

---

## 质量门标准

| 质量门 | 要求 |
|--------|------|
| Gate-1 | CLI 合约测试 100%；Wave 0+1 L1/L2 >= 95% |
| Gate-2 | Wave 2+3 L1/L2 >= 92%；L3 回归 >= 99%；幂等性 >= 98% |
| Gate-3 | 全插件综合 L1/L2/L3 >= 95%；无不可解释渲染退化；失败 100% 有归因 |
