# svgo-swift 重构蓝图（Swift Package + CLI）

> 文档目的：基于现有 SVGO 开源项目能力与测试资产，规划一个可落地、可验证、可被 AI 持续开发的 **Swift 版本复现项目**。  
> 项目名称固定：`svgo-swift`。

---

## 0. 已完成调研与结论（先调研再规划）

本蓝图在撰写前已完成以下调研：

### 0.1 Swift 工具链与包管理

- 本机工具链：**Swift 6.2.4**（`swift --version`）
- `swift package`、`swift test` 命令可用
- SwiftPM 官方 `PackageDescription` 确认支持：
  - `library` product
  - `executable` product
  - `.target` / `.executableTarget` / `.testTarget`

**结论**：`svgo-swift` 采用单仓库 Swift Package 是可行且标准做法。

### 0.2 CLI 生态

- `apple/swift-argument-parser`：成熟、稳定，支持 `ParsableCommand` / `AsyncParsableCommand`

**结论**：CLI 层使用 `swift-argument-parser`。

### 0.3 测试生态

- `swift-testing` 功能强（宏、参数化、并行）
- Swift 官方仍保留 XCTest 兼容路径

**结论**：
- 基线测试采用 **XCTest**（兼容稳、工具链普适）
- 新增复杂参数化测试可逐步引入 `swift-testing`

### 0.4 XML 解析生态

- FoundationXML 的 `XMLParser` 在 Swift 开源实现中可用（含 delegate 事件、行列信息等）
- SWXMLHash / AEXML：更偏便利层，不适合作为核心解析引擎

**结论**：核心 SVG 解析使用 **FoundationXML.XMLParser**（事件流 + 自建 AST）。

### 0.5 CSS/选择器相关生态

- SwiftSoup：有 CSS selector，支持 `parseXML`，但核心定位仍是 HTML 解析生态
- `swift-css-parser`：轻量，但 README 明确可能忽略无效 token，且生态成熟度需验证
- 旧版 CSSParser（katana 封装）功能覆盖有限

**结论**：
- **不把第三方 CSS 库作为不可替代核心依赖**
- 采用“可插拔策略”：
  1) 首期实现 SVGO 测试覆盖所需的 CSS/selector 子集
  2) 保留第三方适配层（可实验）

### 0.6 SVG 规范依据

- W3C SVG Path、Arc 实现说明（尤其 F.6 arc 修正算法）

**结论**：几何核心算法（`convertPathData`、`convertTransform`）以 W3C 规范为第一真相源。

---

## 1. 目标与非目标

## 1.1 目标

构建 `svgo-swift`，同时提供：

1. **可集成库（Swift Package library）**
2. **可执行 CLI 工具（SwiftPM executable target）**
3. **可复用测试桥接层**，复用 SVGO 现有测试资产作为黄金评估标准

## 1.2 非目标

1. 不做 JS 实现逐行照抄
2. 不要求所有输出字节级一致（允许语义等价）
3. 不在早期为了性能牺牲兼容性与可验证性

---

## 2. 参考资产与绝对路径（AI 必填）

`svgo-swift` 的行为评估依赖以下源资产：

- SVGO 源项目：`/Users/5km/Dev/Web/svgo`
- 核心代码参考：
  - `/Users/5km/Dev/Web/svgo/lib`
  - `/Users/5km/Dev/Web/svgo/plugins`
- 测试资产：
  - `/Users/5km/Dev/Web/svgo/test/plugins`
  - `/Users/5km/Dev/Web/svgo/test/cli`
  - `/Users/5km/Dev/Web/svgo/test/svgo`
  - `/Users/5km/Dev/Web/svgo/test/regression`

规则：

1. AI Ticket 必须写明上述**绝对路径**。
2. 若 fixture 更新，必须更新 baseline manifest 和差异说明。
3. 所有“兼容性结论”必须能回链到具体用例文件。

---

## 3. 产物形态（Package + CLI）

## 3.1 Package 产品（当前已落地）

当前 `Package.swift` 已落地为三产物：

- `library(name: "svgo-swift", targets: ["svgo-swift"])`
- `executable(name: "svgo-swift-cli", targets: ["svgo-swift-cli"])`
- `executable(name: "svgo-swift-dev", targets: ["svgo-swift-dev"])`

其中：

- `svgo-swift-cli` 依赖 `svgo-swift`
- `svgo-swift-dev` 依赖 `svgo-swift`

## 3.2 目录建议（目标态）


> 说明：不依赖 shell 脚本，fixture 导入与回归触发由 `svgo-swift-dev`（Swift 可执行目标）统一承载。
```text
svgo-swift/
  Package.swift
  Sources/
    svgo-swift/               # 当前库 target（后续可细拆模块）
    svgo-swift-cli/           # 业务 CLI
    svgo-swift-dev/           # 纯 Swift 开发工具命令（fixture/regression）
    # 目标态可逐步拆分：SVGAST / SVGPath / SVGStyle / SVGOPlugins*
  Tests/
    svgo-swiftTests/
    Fixtures/SVGO/
    # 目标态可新增：SVGOCompatibilityTests
  docs/
  reports/
```


## 3.3 当前项目基线（已创建）

当前仓库（`/Users/5km/Dev/Apple/svgo-swift`）已具备：

```text
svgo-swift/
  Package.swift
  Sources/
    svgo-swift/
    svgo-swift-cli/
    svgo-swift-dev/
  Tests/
    svgo-swiftTests/
    Fixtures/SVGO/
      plugins/
      cli/
      svgo/
      regression/
  docs/
    svgo-swift-rewrite-blueprint.md
  reports/
    .gitkeep
  .github/workflows/ci.yml
```

已验证命令：

```bash
swift build
swift test
swift run svgo-swift-dev --help
```

纯 Swift 工具化状态：

- 已移除 shell `Scripts/` 目录
- fixture 导入与回归触发入口统一为 `svgo-swift-dev`

`svgo-swift-dev` 当前子命令：

- `import-fixtures`（已可把 `/Users/5km/Dev/Web/svgo/test` 导入 `Tests/Fixtures/SVGO`）
- `run-regression`（Swift wrapper 触发 Node regression 管线）

测试资产当前导入规模（文件数）：

- `plugins`: 368
- `cli`: 3
- `svgo`: 10
- `regression`: 10


实现粒度基线（as-is）：

- `Sources/svgo-swift/` 目前为模板占位（尚未实现 optimize API）
- `Sources/svgo-swift-cli/` 目前为 HelloWorld 占位（待接 ArgumentParser）
- `Sources/svgo-swift-dev/` 已可执行 `import-fixtures` / `run-regression`
- `Tests/svgo-swiftTests/` 已具备 `Testing`/`XCTest` 条件兼容骨架

## 3.4 目录扩展路线（从当前态到目标态）

在保留现有三 target 的基础上，逐步拆分出：

- `SVGAST`
- `SVGPath`
- `SVGStyle`
- `SVGOPluginsCore`
- `SVGOPluginsBuiltin`
- `SVGOCompatibilityTests`

> 实施原则：每次新增一个模块，都必须先接入 fixture 驱动测试再扩展功能。

---

## 4. API 设计（库集成面）

```swift
public struct OptimizeOptions {
    public var path: String?
    public var multipass: Bool
    public var dataURI: DataURIFormat?
    public var js2svg: StringifyOptions
    public var plugins: [PluginConfig]
}

public struct OptimizeResult {
    public let data: String
}

public func optimize(_ input: String, options: OptimizeOptions = .default) throws -> OptimizeResult
public func loadConfig(at path: String?, cwd: String) throws -> OptimizeOptions?
```

插件协议建议：

```swift
public protocol SVGOPlugin {
    var name: String { get }
    func makeVisitor(params: PluginParams, info: PluginInfo) throws -> Visitor?
}
```

核心要求：

- 插件参数必须强类型化
- 支持 preset（如 `preset-default`）
- 支持全局覆盖（如 floatPrecision）

---

## 5. CLI 设计（svgo-swift）

使用 `swift-argument-parser` 实现命令行：

- 输入：文件、目录、stdin、字符串
- 输出：文件、目录、stdout
- 支持：`--config`, `--multipass`, `--pretty`, `--indent`, `--show-plugins`

示例：

```bash
svgo-swift input.svg -o output.svg
svgo-swift -f ./icons -o ./dist --recursive
cat input.svg | svgo-swift - -o -
```

与库关系：

- CLI 仅做参数绑定、IO、报错处理
- 优化逻辑当前落在 `svgo-swift` target，后续按规划细拆到 `SVGOCore` 等模块

---

## 6. 核心技术决策（Swift 语境）

## 6.1 XML 解析

- 选型：`FoundationXML.XMLParser`
- 方法：SAX/事件流构建自定义 AST（兼容 xast 概念）
- 目标：保留/处理文本空白策略与 SVGO 一致

## 6.2 AST 与 Visitor

- AST 节点：`root/element/text/comment/cdata/doctype/instruction`
- 访问器：`enter/exit`
- 删除节点需“安全遍历”策略（避免遍历时失效）

## 6.3 Path/Transform

- `SVGPath` 独立模块
- 实现 tolerant parser（错误截断至最后合法段）
- Arc 采用 W3C F.6 规则（含半径修正）
- Transform 分解失败时必须回退保留 `matrix()`

## 6.4 CSS/Selector

- 首期做“测试驱动子集”：仅实现 SVGO 用例覆盖到的特性
- 动态伪类、复杂媒体查询默认保守（标记 dynamic，不做激进优化）
- 预留 selector 引擎替换点（便于后续尝试 SwiftSoup/其他库）

---

## 7. 兼容性评估体系（L1/L2/L3）

### L1：字节一致

- 直接对比输出文本

### L2：归一化一致

归一化步骤：

1. 统一换行
2. 去尾空白
3. 属性顺序稳定化
4. 数值规范化（`-0 -> 0`, leading-zero 统一）
5. 空标签写法归一

### L3：渲染一致

- 使用现有回归策略（Playwright + pixelmatch）
- 默认阈值：`diff_pixels <= 4` 或 `diff_ratio <= 0.05%`

> 说明：L3 可继续调用现有 Node regression harness，Swift 只负责触发与收集结果。

---

## 8. 测试资产接管方案

## 8.1 fixture 映射

| SVGO 资产 | 读取方式 | Swift 侧映射 |
|---|---|---|
| `test/plugins/*.svg.txt` | `@@@` 分段 | `PluginFixtureCase` |
| `test/svgo/*.svg.txt` | 输入/期望 | `CoreFixtureCase` |
| `test/cli/*.test.js` | 行为契约 | `CLIBlackBoxCase` |
| `test/regression/*` | 脚本执行 | `RegressionRunner` |

## 8.2 幂等性检查

- 除明确排除插件外，默认执行 2-pass 幂等性检查
- 若第 2 次输出变化，记录为 `idempotence` 失败类别

## 8.3 报告协议

- `reports/plugin-events.ndjson`
- `reports/failures.ndjson`
- `reports/quality-gates.json`

---

## 9. 插件迁移波次（按语义风险）

### Wave 0（低风险清理）

`removeDoctype`, `removeXMLProcInst`, `removeComments`, `removeMetadata`, `removeTitle`, `removeDesc`, `removeXMLNS`

### Wave 1（属性/结构）

`cleanupAttrs`, `removeEmptyAttrs`, `removeDimensions`, `removeUnusedNS`, `sortAttrs`, `sortDefsChildren`

### Wave 2（样式链路）

`mergeStyles`, `inlineStyles`, `minifyStyles`, `convertStyleToAttrs`, `removeAttributesBySelector`

### Wave 3（几何中风险）

`convertColors`, `convertShapeToPath`, `convertEllipseToCircle`, `cleanupNumericValues`, `cleanupListOfValues`

### Wave 4（几何高风险）

`convertTransform`, `convertPathData`, `mergePaths`, `removeHiddenElems`, `removeOffCanvasPaths`, `reusePaths`

---

## 10. 质量门（可量化）

### Gate-1（基础可用）

- CLI 合约测试通过率：100%
- Wave 0+1：L1/L2 通过率 >= 95%

### Gate-2（语义稳定）

- Wave 2+3：L1/L2 通过率 >= 92%
- L3 回归通过率 >= 99%
- 幂等性通过率 >= 98%

### Gate-3（核心完成）

- 全插件综合通过率（L1/L2/L3）>= 95%
- 无新增不可解释渲染退化
- 失败 100% 有归因与处置记录

---

## 11. AI 开发协议（推荐）

每个 AI Ticket 必须包含：

1. 目标插件/模块
2. 规范引用（W3C 或源实现依据）
3. 绝对路径 fixture 列表
4. 禁止项（不允许影响哪些行为）
5. 验收命令（`swift test` + regression）
6. 报告输出路径

模板示例：

```yaml
title: implement convertPathData arc-normalization
scope:
  modules: [SVGPath, SVGOPluginsBuiltin]
fixtures:
  - /Users/5km/Dev/Web/svgo/test/plugins/convertPathData.21.svg.txt
acceptance:
  commands:
    - swift test --filter convertPathData
    - swift run svgo-swift-dev run-regression --svgo-root /Users/5km/Dev/Web/svgo --subset path
outputs:
  - reports/failures.ndjson
```

---

## 12. 风险与回滚

## 12.1 主要风险

1. 浮点策略导致输出漂移
2. selector 语义不完整导致样式回归
3. path 压缩激进导致几何失真
4. AI 并行开发引发跨插件回归

## 12.2 回滚策略

运行模式：

- `--engine=swift`（默认）
- `--engine=node-svgo`（回退）
- `--engine=hybrid`（按插件路由）

> 注：hybrid 模式用于迁移中止损，不是最终形态。

---

## 13. 立即执行清单（基于当前基线）

### 13.1 已完成（Done）

1. `svgo-swift` package 已初始化（library + `svgo-swift-cli` + `svgo-swift-dev`）
2. fixture 已导入 `Tests/Fixtures/SVGO`
3. 纯 Swift 工具入口已建立（`svgo-swift-dev`）

### 13.2 下一步（Now）

1. 在 `svgo-swift` 库 target 中定义最小 API：`optimize` / `loadConfig` 占位
2. 新建 `SVGOCompatibilityTests`，接入 `test/plugins` 的 `@@@` fixture 解析
3. 将 `svgo-swift-cli` 从 HelloWorld 升级为参数骨架（建议引入 `swift-argument-parser`）
4. 为 `svgo-swift-dev import-fixtures` 增加 `baseline-manifest.json` 生成
5. 为 `svgo-swift-dev run-regression` 增加 report 输出到 `reports/*.ndjson`
6. 首个插件目标：`removeComments`（低风险、便于打通 L1）

---

## 14. Package.swift 参考骨架（目标态示意）


当前已落地的 manifest 关键点：

- products：`svgo-swift` / `svgo-swift-cli` / `svgo-swift-dev`
- targets：`svgo-swift` / `svgo-swift-cli` / `svgo-swift-dev` / `svgo-swiftTests`

下面代码块是“目标态拆模块后”的参考，不是当前仓库即刻状态。

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "svgo-swift",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "svgo-swift", targets: ["SVGO"]),
        .executable(name: "svgo-swift-cli", targets: ["SVGOSwiftCLI"]),
        .executable(name: "svgo-swift-dev", targets: ["SVGOSwiftDev"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(name: "SVGO", dependencies: ["SVGOCore"]),
        .target(name: "SVGOCore", dependencies: ["SVGAST", "SVGPath", "SVGStyle", "SVGOPluginsCore", "SVGOPluginsBuiltin"]),
        .target(name: "SVGAST"),
        .target(name: "SVGPath"),
        .target(name: "SVGStyle"),
        .target(name: "SVGOPluginsCore"),
        .target(name: "SVGOPluginsBuiltin", dependencies: ["SVGOPluginsCore", "SVGPath", "SVGStyle"]),
        .executableTarget(
            name: "SVGOSwiftCLI",
            dependencies: [
                "SVGO",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(name: "SVGOSwiftDev", dependencies: ["SVGO"]),
        .testTarget(name: "SVGOCompatibilityTests", dependencies: ["SVGO"]),
    ]
)
```

---

## 15. 参考链接（调研依据）

- Swift Argument Parser: https://github.com/apple/swift-argument-parser
- Swift PackageDescription: https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html
- Swift Testing: https://github.com/swiftlang/swift-testing
- FoundationXML XMLParser（开源实现）: https://github.com/swiftlang/swift-corelibs-foundation
- SwiftSoup: https://github.com/scinfu/SwiftSoup
- swift-css-parser: https://github.com/stackotter/swift-css-parser
- W3C SVG Path: https://www.w3.org/TR/SVG11/paths.html
- W3C Arc 实现说明: https://www.w3.org/TR/SVG11/implnote.html#ArcImplementationNotes
- SVGO 源资产：`/Users/5km/Dev/Web/svgo`
