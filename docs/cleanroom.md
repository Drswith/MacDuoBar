# Cleanroom 实现规范

核对日期：2026-10-26。适用项目：MacDuoBar 0.1。

## 目标与输入边界

在 macOS 菜单栏用外圈、中间和底部四点表达多项状态，点击后查看读数并配置位置。代码、界面文案和工程组织在本仓库独立编写。

用户指定 [DuoBar 的公开产品说明](https://github.com/elovria/DuoBar/blob/main/README.md) 作为需求背景，并要求独立实现。公开可见不等于取得源码使用许可；许可的一般规则参见 [GitHub 说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)。本规范不作参考仓库当前许可状态的法律认定。

本次读取了该产品 README 的完整内容，其中含有文件列表、几何参数、私有接口和构建描述；这些实现描述不作为本项目实现依据。没有读取、克隆或反编译该产品源码，没有复制其图片或脚本。当前工作由同一实现者完成，因此属于记录输入边界的独立重写，不能宣称已经满足研究者与实现者相互隔离的双团队 Cleanroom 证明。

允许输入是用户需求、公开的功能描述、Apple API 文档、官方设计说明以及可追溯的外部行为测量。引用对话「整理Cleanroom规范」的工具可读结果仅提供用户问题，助手正文返回内容引用标记，无法核对其具体规范；这里不假定已恢复该正文。用户后续指定的 Duo UI Demo 提供图形来源线索，详见 [图形依据](graphics.md)。没有复用 Demo 源码。

发现来源不清的实现或资源时，先停止使用该输入，保留来源记录，重新从需求和公开 API 编写受影响部分。不要在此仓库保存原始私人聊天、参考产品代码或完整 Apple 设计套件。

## 功能范围

| 能力 | 当前契约 |
| --- | --- |
| 三合一图标 | 外圈表示比例，中间表示数字或网络种类，底部四点表示四级占用；全部为系统模板图像，自适应菜单栏深浅 |
| 位置配置 | 每个位置可选电量、网络、CPU、内存、磁盘或隐藏；允许重复，至少保留一个位置；设置跨重启保存 |
| 默认布局 | 外圈电量、中间网络、底部 CPU |
| 详情 | 点击后显示全部五项读数、系统设置入口、设置和退出；macOS 26 及以上使用无箭头的原生 Liquid Glass 分块面板，14／15 使用系统 NSPopover；再次点击同一菜单栏图标关闭；点击外部、切换窗口或 Esc 关闭 |
| 设置 | 同时预览当前图标，点击预览打开状态面板；配置三个位置，立即生效；可恢复默认布局 |
| 辅助功能 | 图标提供状态文字；配置使用系统控件，支持键盘；无自动播放动画 |
| 隐私 | 无遥测、更新请求、网络探测、Wi-Fi 扫描或密码存储；读取系统当前连接信息，SSID 仅在内存中用于显示；通过用户操作请求定位授权，不请求坐标位置 |

GPU、网速、音量、蓝牙外设电量、独立开关指示灯、Wi-Fi 加入／切换、充电控制、登录启动和自动更新均未实现；它们不是当前版本的可用能力。详情没有实现参考产品的拆分动画。后续需求进入本表并补齐数据依据、失败处理与验收后再实现，不引入私有框架来填补能力。

## 数据与失败语义

| 数据 | 本项目定义 | 公开接口 |
| --- | --- | --- |
| 电量 | 内置电池当前容量／最大容量；电池卡片和包含电量的菜单栏图标显示充电／外接电源闪电标识，文字区分正在充电与外接电源但未充电；无内置电池时明确显示外接电源，比例不可用 | IOKit Power Sources |
| 网络 | 优先显示已连接 Wi-Fi 的当前 SSID；macOS 定位授权缺失时显示「需要定位权限」，授权后读取失败显示「名称不可用」。无 Wi-Fi 连接时显示有线或其他连接；Wi-Fi 关闭／未连接分别明确显示。连接不证明公网可达；无 RSSI、热点或 VPN 识别承诺 | CoreWLAN `CWInterface.ssid()`、Core Location 授权与 Network `NWPathMonitor` |
| CPU | 相邻两次系统累计 CPU tick 的忙碌差值／总差值；覆盖系统全部 CPU；首次读数或零增量显示不可用 | Mach `host_statistics` / `HOST_CPU_LOAD_INFO` |
| 内存 | `(active + wired + compressed pages) × page size / physical memory`；为本项目的占用估算，不等同于内存压力或活动监视器的所有口径 | Mach `host_statistics64` / `HOST_VM_INFO64` |
| 磁盘 | 根文件系统 `(total − available) / total`；APFS 可清理空间与系统设置口径可能不同 | Foundation URL volume resource values |

系统读数与当前 SSID 每 2 秒刷新，网络路径和定位权限变化时立即刷新；唤醒后立即刷新，并重新建立 CPU 采样基线。读数失败或非有限值使用「暂不可用」，不伪装成 0%、100% 或联网成功；比例限定为 0…1。未取得 CPU 第二个样本时不显示开机以来的平均值。

网络映射为未连接 0、已连接 1；Wi-Fi 关联状态不等同于互联网可达。用于外圈和四点时只表达连接状态，不表达带宽或 Wi-Fi 信号质量。底部四点按 25%、50%、75%、100% 分段，非零且低于 25% 时亮一颗，0% 全暗；未知值全暗，完整文字读数说明未知。配置中三个位置同时隐藏时，保留本次操作前的最后一个可见位置；损坏或全隐藏的持久化配置恢复默认布局。

Wi-Fi 卡片和设置内提供授权入口：首次操作请求系统定位授权，拒绝后再次操作打开系统定位设置。不启动位置更新，不绕过权限，不读取保存的 Wi-Fi 列表。

## 工程契约

- `Package.swift` 是平台下限和 SwiftPM 产品的权威来源；`Resources/Info.plist` 是应用标识与版本的权威来源。
- 构建脚本只构建本机架构、生成开发 `.app`、进行本地签名，不修改系统图标、网络、电池策略或登录项。
- 最低运行版本与构建 SDK 分别维护：保留 macOS 14 下限，使用当前 Xcode SDK 编译、链接；脚本以 Darwin `-isysroot` 明确链接 SDK，并检查 `LC_BUILD_VERSION.sdk` 与所选 SDK 一致。不能把 SDK 标成兼容下限来启用旧外观。原生控件跟随运行系统外观；自定义 Liquid Glass 使用 `if #available(macOS 26, *)` 并保留低版本回退。SDK 标记本身不证明自定义界面已采用玻璃效果。
- 现代详情面板使用透明、无边框、非激活 NSPanel 承载按控制中心实测布局的系统玻璃；菜单栏入口从按钮的屏幕坐标向下定位，设置预览使用设置窗口自身的锚点。位置受对应屏幕可用区域约束，支持负坐标显示器；小屏缩窄并按需滚动，不裁切固定宽高内容。材质和布局规则见 [图形规范](graphics.md#详情面板材质与定位)。
- 面板失去焦点和全局鼠标监听共用 `PanelDismissal`：按下同一状态栏图标的左键不提前清除面板，由随后图标动作统一切换关闭；外部点击、右键与键盘切换窗口仍关闭。判断使用状态栏按钮实时屏幕边界与该事件的鼠标位置，不用延时窗口或防抖时间掩盖事件顺序。
- `UserDefaults` 仅存储三个位置配置。进程启动即建立状态栏入口；退出释放计时器和网络监视器。
- 图形尺寸与来源只在 [图形依据](graphics.md) 维护。采样层不依赖界面；图标与详情使用同一读数，避免两套状态。
- 读数与配置的边界测试在 `Tests/MacDuoBarTests/`；不为每种系统 API 编造一定成功的 mock 结论。

## 验收

1. `swift test` 通过：CPU 差分、计数回绕、首次／零增量、非法比例、四点分段、隐藏约束、配置恢复、官方字形／数字与圆环同心、图形比例保持、充电状态与可见位置、典型 Wi-Fi 名称排版宽度，以及面板锚点、屏幕边缘、负坐标与小屏约束。
2. `./scripts/build-app.sh` 成功，应用元数据可解析，`codesign --verify --strict` 通过。
3. 启动 `.app` 后存在菜单栏入口；点击、Esc、设置窗口、恢复默认和退出可操作；配置重启后恢复。
4. 图标在浅／深菜单栏、Retina 缩放和辅助功能读屏下检查，数值文字与图形含义一致。
5. 硬件检查应覆盖电池供电、充电、无内置电池、网络变化、睡眠唤醒及不同系统版本；只验过本机的项目不得标记为全面验证。

构建和逻辑测试不证明官方图形逐像素一致，也不证明全部硬件状态已经实测。具体交付验证在当次变更说明中报告。

## API 依据

- [Apple IOPSCopyPowerSourcesInfo](https://developer.apple.com/documentation/iokit/1523839-iopscopypowersourcesinfo)：通过 Power Sources 访问器读取电源信息。
- [Apple NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor)：观察系统网络路径变化。
- [Apple CoreWLAN SSID](https://developer.apple.com/documentation/corewlan/cwinterface/ssid()) 与 [定位授权说明](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)：读取当前网络名称所需的系统授权；不用于获取位置。
- Mach 数据结构与常量以构建 SDK 的 `mach/host_info.h`、`mach/vm_statistics.h` 为准；不要从参考产品复制采样实现。
