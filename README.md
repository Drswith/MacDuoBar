# MacDuoBar

将多个 Mac 状态集中到一个菜单栏图标的原生 macOS 工具，使用 Swift、AppKit 和 SwiftUI 独立实现。需要 macOS 14 或更高版本及 Xcode 工具链，无第三方依赖。

当前版本提供电量、网络连接、CPU、内存和启动磁盘占用；获得定位授权后显示当前 Wi-Fi 名称。外圈、中间、底部四点可分别选择读数。点击图标查看详情与配置，设置自动保存在本机。

## 开始

```sh
swift test
./scripts/build-app.sh
open build/MacDuoBar.app
```

构建脚本使用当前 Xcode 的 macOS SDK，保留 macOS 14 运行下限，并核对二进制记录的 SDK 版本；在 macOS 26／27 上由原生组件采用对应系统外观。生成的本机架构开发应用使用 ad-hoc 签名，尚未经过 Apple 公证。启动后在菜单栏寻找圆环图标；菜单中的「设置…」打开配置窗口，「退出」结束应用。开发时可用 `open build/MacDuoBar.app --args --settings` 直接打开配置。

## 文档

- [Cleanroom 实现规范](docs/cleanroom.md)：输入边界、功能契约、数据定义和验收条件。
- [图形依据与资源归属](docs/graphics.md)：官方参考、测量来源和本项目绘制规则。
- [协作规则](AGENTS.md)：代码与文档的维护要求。
- [MIT 许可证](LICENSE)：适用于本仓库原创代码与文档，不覆盖 Apple 的系统资源与商标。

## 结构

`Sources/MacDuoBar/Readings.swift` 定义读数和配置；`SystemReader.swift` 通过系统公开接口采样；`StatusGlyph.swift` 绘制菜单栏图形；`ControlCenterView.swift` 实现按原生控制中心测量的现代面板；`StatusPanel.swift` 与 `PanelMotion.swift` 管理面板开合和反向，`PanelPlacement.swift` 计算屏幕锚点和边界，`PanelDismissal.swift` 协调同一状态栏按钮与外部关闭事件；`MacDuoBar.swift` 连接状态栏、分版本详情面板和设置。测试在 `Tests/MacDuoBarTests/`，应用元数据在 `Resources/Info.plist`。

当前功能边界与未实现项目统一维护在 [Cleanroom 规范](docs/cleanroom.md#功能范围)。本项目没有与 Apple 或参考产品建立关联。
