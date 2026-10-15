# CarrierLock

> 🌍 **Languages:** [English](./README.md) | 简体中文

CarrierLock 是一款面向个人设备维护场景的 iOS 工具。它通过 Airlift 为指定 IMSI 写入运营商配置 Overlay 链接，让 CommCenter 优先命中本地 carrier bundle，减少卡贴场景下的重复配置匹配和跳激活。


## 功能特性

- 提供配对文件与 LocalDevVPN 回环连接的设备端引导。
- 监听 CommCenter 日志并捕获 IMSI 候选值。
- 支持一次锁定多个 IMSI 候选值，包括真实 SIM、卡贴上报值和双卡 IMSI。
- 支持选择运营商 bundle，也支持手动输入自定义 bundle 名称。
- 写入 Overlay 链接前强制确认 IMSI，降低锁错 SIM 的风险。
- 支持简体中文界面。

## 工作原理

CarrierLock 会监听 CommCenter 的 bundle 选择事件，帮助确认当前使用的 IMSI，然后通过 Airlift 写入形如 `<IMSI> -> /System/Library/Carrier Bundles/iPhone/<Bundle>.bundle` 的 Overlay 链接。多 IMSI 模式会一次写入多个候选链接。CommCenter 再次扫描运营商配置时会优先匹配本地 Overlay，并加载所选 bundle。

多 IMSI 锁定可以覆盖双卡、卡贴临时切换 IMSI 等场景，但它不能阻止卡贴主动切换 IMSI，也不能修复激活票据或修改基带能力。

## 系统要求

- 一台受支持的 iOS/iPadOS 系统的实体 iPhone 或 iPad：
  - **iOS/iPadOS 18.0 – 27.2 B2**
- 本地构建需 Xcode 27 或更高版本。
- 仓库提供的 GitHub Actions 工作流可在云端构建 unsigned IPA。

> CarrierLock 依赖非公开的系统行为，不同 iOS 版本之间兼容性可能发生变化。锁定前请务必确认 IMSI 属于目标 SIM。

## 免责声明

本软件仅供个人学习、研究以及维护本人拥有或已获授权的设备使用。下载、安装或使用本软件均属于个人自发行为，风险由使用者自行承担。使用者应自行确认符合当地法律法规、运营商条款及相关平台协议。

本软件按“现状”提供，不提供任何明示或默示保证。开发者不对因使用本软件导致的设备异常、数据丢失、业务中断、账户风险、法律问题或其他后果承担责任。

## 构建

打开 `carrierlock.xcodeproj`，选择 `carrierlock` target，设置你的签名团队，然后构建到实体设备。

如需构建 unsigned IPA，请在 GitHub Actions 中运行 `Release unsigned IPA` 工作流。成品文件名为 `carrierlock-v<version>-unsigned.ipa`。

## 致谢 / Credits

- 感谢 [AirliftSilence](https://github.com/YiHoooong/AirliftSilence) 提供的静音音频资源与替换方案研究。
- 感谢 [airlift](https://github.com/0xjohnnydev/airlift)（作者 0xjohnny）提供的 AirTraffic 与 Airlock 研究，其作为项目依赖被保留。
- 感谢 [Placard](https://github.com/frs0n/placard) 的贡献者提供的原始 iOS 项目结构与容器访问实现。

## 许可证 / License

CarrierLock 以 [GNU 通用公共许可证 v3.0](LICENSE) 发布。
