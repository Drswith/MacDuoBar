# 图形依据与资源归属

核对日期：2026-10-26。运行版的网络、电源等字形使用 macOS 自带的官方 SF Symbols；数字使用系统字体，动态比例环和四点由 AppKit 绘制。没有打包参考产品图标、Apple UI Kit 导出文件或模拟器提取图片。

用户已明确选择运行版使用官方 SF Symbols。不要生成、临摹或手工重画这些字形，不要把图片拉伸到任意宽高。

## 可追溯参考

用户指定聊天「开发 macOS Duo UI Demo (2)」作为线索。已通过聊天读取工具核对其工作目录为 `quantex`，并读取其中 `docs/design-reference.md`、`docs/asset-sources.md` 和 `docs/motion-reference.md`。这些记录区分了官方矢量测量、截图推导和 Demo 自行调校；当前使用的是其官方状态栏组件测量记录，没有复用 Demo 代码或动效参数。

| 来源 | 用途与边界 |
| --- | --- |
| [Apple Design Resources](https://developer.apple.com/design/resources/) | 官方设计资源入口；2026-10-26 页面仍链接到 Sketch 套件 |
| [状态栏组件 Inspector](https://www.sketch.com/s/04c24d8b-38fb-4afb-8836-36617e022f02/f/C1DAE7F8-E4BA-47CB-9010-8CFAA54E73A8#Inspector) | Demo 在 2026-10-09 记录的几何测量来源；本轮未重新导出、测量原始 SVG |
| [Apple HIG — Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) | 设计语义来源；不是可复制整个产品外观的许可 |
| [Apple Design Resources 许可](https://developer.apple.com/support/downloads/terms/apple-design-resources/Apple-Design-Resources-License-20230621-English.pdf) | 第 2A 条将用途限定为界面设计稿，第 2B 条禁止把套件素材嵌入软件；运行版使用系统公开的 SF Symbols API |

原 Demo 的 Phone、Messages、Music、Safari PNG 来自 Apple UI Kit，Settings PNG 来自本机模拟器渲染。原记录明确限制为本地设计演示，并不属于 Demo 源码许可；这些图片也不属于本项目 MIT 许可范围。本版本无需这些 Dock／设置图片，因此没有导入。

## 本项目绘制规则

以下基础值来自上述 Demo 的官方矢量测量记录，保留来源的不确定性：

| 项目 | 48 pt 参考坐标中的测量 |
| --- | --- |
| 图标画布 | 48 × 48 |
| 圆环中心／半径 | (24, 24.427)／约 18.95 |
| 圆环线宽 | 约 3.1 |
| 四点直径 | 4 |
| 四点中心 | (14.671, 40.668)、(20.671, 43.338)、(27.329, 43.338)、(33.329, 40.668) |
| Wi-Fi 语义 | 两条弧线加末端；不把信号图形当作网络带宽证明 |

菜单栏图像为 24 × 24 pt，将参考坐标等比缩小。外圈底部留出四点空间，起止角、中心内容字号和留白由本项目独立选择；不使用参考产品 README 的几何参数。无效读数显示短横。隐藏外圈后保持稳定画布，避免状态栏位置随刷新跳动。

中心内容与圆环共用 `(24, 24.427)`，四点围绕 x=24 对称。SF Symbols 从系统按 semibold 渲染并缓存，测量 alpha > 0.1 的可见边界，按原始比例放入最大 24 × 20 的中心区域；只改变整体缩放和位置，不改字形。系统字体使用原始 glyph 路径的可见边界居中，避免排版框和字形中心不同。所有坐标最终统一缩小 0.5 倍。

`testOfficialSymbolsAndNumbersShareRingCenter` 对 Wi-Fi、有线、网络、离线、外接电源和数字的实际渲染进行检查，中心误差不超过菜单栏坐标的 0.3 pt；`testSymbolPlacementPreservesOriginalAspectRatio` 检查原始比例保持。小尺寸栅格化与不同系统的 SF Symbols 版本仍可能产生亚像素差异，最终同时检查实际窗口，不能只凭矩形中心判断视觉居中。

所有状态继续使用系统单色模板，由系统适应菜单栏深浅外观；用户本轮明确要求暂时保留现有颜色。比例圆环填充长度与读数一致，接通外部电源或正在充电时，电池卡片使用官方 `battery.100percent.bolt`；电池供电时按电量档位使用对应的系统电池字形。菜单栏配置包含电量时，在圆环正上方显示官方 `bolt.fill`（48 pt 画布内中心约 `(24, 6.32)`，可见边界不超过 6.4 × 10 pt），圆环在顶部 255°…285° 留缺口；中间的网络／数字与底部四点保持原位；电量全部隐藏时不显示该标记。真实充电与外接电源但未充电的区别继续在提示和辅助功能文字中说明，不用颜色单独承载信息。四点的分段规则以 [数据契约](cleanroom.md#数据与失败语义) 为准。

充电态依据补充读取了 quantex 的 `docs/simulator-motion-capture.md` 及本地 `artifacts/duo-simulator-2026-10-15/charging-comparison.jpg`、`power-controlled-contact.jpg` 中的系统原帧，未读取其绘图实现。采集记录对应 iOS 27.1 Duo 模拟器的调试状态覆盖：顶部闪电、环顶部缺口、正常充电绿弧与低电量充电红弧。原始稳态帧 `power-controlled-frames/0064.png` 为 168 × 210 px：闪电可见边界约 19 × 29 px；绿色电量弧拟合的半径约 56.08 px，闪电中心较圆环顶端中心线低约 2.53 px。按原帧 3× 与本项目 0.5× 菜单栏缩放换算，闪电约为 3.2 × 4.8 pt，中心应略低于圆环顶部中心线。运行版采用系统字形对应的 6.4 × 10 pt 上限和上述基线，不以 24 pt 画布直接套用原帧像素。颜色暂按用户要求保留本项目单色。运行版继续使用官方 SF Symbols；只对本项目静态收拢态作适配，未复制模拟器图片或 Demo 路径，未实现该参考约 0.6–0.7 秒的状态动画。

## 详情面板材质与定位

2026-10-26 在本机 macOS 27.0.1、内置 Retina 显示器（1512 × 982 屏幕点，2×）重新采集原生控制中心。原始桌面合成图保留原始像素，没有按聊天图片尺寸缩放。原始截图、窗口坐标、校准程序和材质样本留在本地忽略目录 `build/control-center-calibration-2026-10-26/`，不作为应用资源或公开文档图片打包。

| 项目 | 原生测量与当前采用值 |
| --- | --- |
| 内容宽度 | 292 pt |
| 小卡片 | 140 × 64 pt |
| 长卡片 | 292 × 64 pt |
| 卡片间距 | 12 pt |
| 图标底座 | 36 pt 圆形，左侧留白 14 pt |
| 标签与底座间距 | 6 pt |
| 主标题／次级文字 | 系统字体 13 pt semibold／11 pt medium；此前将次级文字也设成 13 pt 有误 |
| 进度条 | 4 pt 高的圆角轨道与填充，绕开系统 ProgressView 的内置最小高度 |
| 主面板正常顶部间距／右侧边距 | 12／14 pt（内置屏，无控制中心隐私提示行时） |

布局为第一行网络、电池两张小卡片，后续 CPU、内存、磁盘各一张长卡片，底部为独立的系统玻璃操作按钮。电池卡片居中显示图标和百分比，供电状态保留在悬停提示和辅助功能文本中。Wi-Fi 的文字区域为 `140 − 14 × 2 − 36 − 6 = 70 pt`，次级文字使用 11 pt，取消额外缩字和文字后的多余 Spacer 间距；典型 11 字符名称在本机系统 medium 字体下约需 69 pt，可完整显示。任意更长名称仍按系统单行尾部省略，完整内容保留在悬停和辅助功能文本中。Wi-Fi 显示当前连接的真实 SSID；未授权时明确提示定位权限，并提供操作入口。进度条仅显示读数，不改变系统设置。

材质使用公开的系统 `glassEffect(.regular, in: .capsule)`，由系统处理边缘反射、背景适应与辅助功能回退。没有自绘描边、黑色压暗层、额外磨砂背景或面板窗口阴影。卡片前景在减少透明度或增加对比度时使用系统颜色。全部卡片位于同一个 `GlassEffectContainer`，融合距离 0，避免卡片静止时粘连。macOS 14／15 保留 `NSPopover` 回退。

此前的 Clear＋半透明 popover 背景＋15% 压暗组合，仅在一个不含边缘的局部材质区域（280 × 36 像素）比对过；该结果不能验证边缘反射。用户指出边缘仍显得生硬后，已移除这套组合，改为上述系统玻璃。现有采样继续用于尺寸依据，不作为当前材质与控制中心完全一致的证据。

控制中心的最近录屏提示会使内容整体下移；测量以截图中的实际卡片定位，不固定截图行号。采样期间捕获到的错位、非同背景或非对应激活态的结果不作为最终验收数据。后续样式修改优先复核这些条件，避免反复盲调材质。

### 面板开合动画

2026-10-27 复核已有素材：本项目 macOS 资料只有静态截图，quantex 的录屏是 iOS Duo 图标展开，不能充当 macOS 面板的时序。用户确认桌面空闲后，只补录了一次约 6 秒的原生 macOS 27.0.1 控制中心打开／关闭。原视频、111 个实际编码帧、原始 PTS、局部测量和拟合结果保存在忽略目录 `build/panel-motion-2026-10-27/`，没有追加参考采集，也没有打包这些素材。录制文件的名义帧率字段不作为显示刷新率；分析保留实际帧时间，没有补帧。

第一张 Wi-Fi 卡片的白色圆底座在可辨识阶段直径基本不变，打开时向右约 1 pt、向下约 3 pt 到达稳态。关闭时反向移动并淡出。早期玻璃轮廓有形变，但不能据此把内容整体大幅缩放。选取这个底座的局部亮度估计透明度，得到以下近似；玻璃背景、低透明度帧和录屏压缩带来误差，不能推断为 Apple 内部曲线。

| 方向 | 时长 | 三次 Bézier 控制点 | 几何 |
| --- | --- | --- | --- |
| 打开 | 240 ms | `(0.25, 0), (0.10, 1)` | 固定内容尺寸，从屏幕左上约 `(-1, -3) pt` 移回最终位置，透明度 0 → 1 |
| 关闭 | 180 ms | `(0.15, 0), (0.25, 1)` | 反向轻移，透明度 1 → 0，完成后关闭窗口 |

运行版通过公开 `NSAnimationContext` 同步动画窗口位置与透明度；`animationBehavior = .none` 禁用额外默认窗口动画，内容尺寸、字体和玻璃材质不变。快速反向点击复用同一个面板，过期的完成回调不能关闭已重新打开的面板。关闭中不拦截鼠标；打开设置、退出应用立即清理。系统「减少动态效果」启用时不移动位置，只进行 100 ms 淡入淡出。macOS 14／15 仍使用原生 `NSPopover` 开合。

这是单背景、单系统样本的内容位移和透明度拟合，没有复刻控制中心玻璃轮廓的独立形变，也不宣称逐帧或所有环境完全一致。公开接口依据：[NSWindow.animationBehavior](https://developer.apple.com/documentation/appkit/nswindow/animationbehavior-swift.property)、[NSAnimationContext](https://developer.apple.com/documentation/appkit/nsanimationcontext)、[减少动态效果](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion)。

面板外留 6 pt 容纳玻璃边缘，菜单栏锚点转换为屏幕坐标；窗口受对应显示器 `visibleFrame` 的水平 8 pt、垂直 6 pt 边距约束，玻璃表面的实际间距另计外留空间。靠近屏幕边缘时整体平移，小屏按需缩窄和滚动。设置预览使用设置窗口自身的锚点。

公开 API 依据：[Apple Liquid Glass 指南](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)、[Apple 材质指南](https://developer.apple.com/design/human-interface-guidelines/materials)。SDK 版本、API 使用、原生窗口渲染与不同系统版本实测是不同证据；单窗口截图不能完整证明桌面背景折射或透色，也不宣称还原了控制中心未公开的材质参数。

这是一份可审计的绘制依据，不宣称逐像素还原。Apple 素材的使用应遵守其实际许可和商标要求；独立重绘也不自动解决所有外观权利问题。新增素材要记录原始来源、许可、变更方式、打包用途和验证状态，不能仅写「官方素材」。
