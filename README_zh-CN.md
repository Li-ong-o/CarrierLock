# CarrierLock

> 🌍 **Languages:** [English](./README.md) | 简体中文

CarrierLock 是一款面向个人设备维护场景的 iOS 工具。它通过 Airlift 为指定 IMSI 写入运营商配置 Overlay 链接，让 CommCenter 优先命中本地 carrier bundle，减少卡贴场景下的重复配置匹配和跳激活。


## 配套软件与配对

CarrierLock 需要先完成设备配对，才能建立 Airlift 连接。请根据 iOS 版本选择对应方式。

### 📱 iOS 27：纯手机端使用，无需电脑

1. 使用证书安装 CarrierLock。
2. 从 App Store 安装 [LocalDevVPN](https://apps.apple.com/us/app/localdevvpn/id6755608044)。
3. 打开 **系统设置 → 隐私与安全 → 开发者模式 → 配对设备**，选择 CarrierLock。
4. 从 CarrierLock 获取配对密码并输入，完成配对。
5. 保持 **Wi-Fi** 和 **LocalDevVPN** 开启，再打开 CarrierLock 即可使用。

### 🍎 iOS 18–26：需要电脑配对

1. 在电脑上下载 [idevice_pair](https://github.com/jkcoxson/idevice_pair/releases)。
2. 插入 iPhone，解锁并点击 **信任**。
3. 生成 **RPPairing 文件**。
   - 注意：不要选择锁定的配对文件，也不要使用 SideStore 的 `.mobiledevicepairing` 文件。
4. 通过 **隔空投送 / 分享**，在 CarrierLock 中打开并导入；也可以复制文件内容后，在 CarrierLock 中通过 **从剪贴板粘贴** 导入。


## 功能特性

- 提供配对文件与 LocalDevVPN 回环连接的设备端引导。
- 检查状态：枚举用户态 Carrier Overlay，读取 IMSI 链接，并读取 SIM1 / SIM2 的 IMSI 与运营商信息。
- 支持 SIM1 / SIM2 独立选择运营商 Bundle，也可以使用 PLMN 自动匹配或手动输入自定义名称。
- 写入 Overlay 链接前强制确认 IMSI，降低锁错 SIM 的风险。
- 恢复：删除用户态 Carrier Overlay 中以 15 位数字 IMSI 命名的软链接。
- 支持简体中文界面。

## 工作原理

CarrierLock 会通过 Airlift 写入形如 `<IMSI> -> /System/Library/Carrier Bundles/iPhone/<Bundle>.bundle` 的用户态 Overlay 链接。检查状态时会枚举 Overlay，读取 15 位数字命名的 IMSI 链接，并与 Lockdown 返回的 SIM 信息比对。未锁定时可根据 PLMN 自动预选运营商 Bundle；锁定时会为每张选中的 SIM 分别写入对应链接。

更完整的运行机制、验证方式和边界说明见下方“原理与边界”。

## 系统要求

- 一台受支持的 iOS/iPadOS 系统的实体 iPhone 或 iPad：
  - **iOS/iPadOS 18.0 – 27.2 B2**
- 配对方式：
  - **iOS 27**：可在手机端配合 [LocalDevVPN](https://apps.apple.com/us/app/localdevvpn/id6755608044) 完成配对，无需电脑。
  - **iOS 18–26**：需要使用电脑通过 [idevice_pair](https://github.com/jkcoxson/idevice_pair/releases) 生成 RPPairing 文件并导入。
- 本地构建需 Xcode 27 或更高版本。
- 仓库提供的 GitHub Actions 工作流可在云端构建 unsigned IPA。

> CarrierLock 依赖非公开的系统行为，不同 iOS 版本之间兼容性可能发生变化。锁定前请务必确认 IMSI 属于目标 SIM。

## 原理与边界

> 更新时间：2026-10-19
> 适用范围：iOS 18.0 - 27.2 beta 2（24B5089g）范围内的个人设备维护场景。
> 本文只做技术机制整理，不提供绕过运营商锁、激活锁或账户验证的方法。

## 1. 三个容易混淆的概念

| 概念                    | 作用                                       | 说明                      |
| --------------------- | ---------------------------------------- | ----------------------- |
| 运营商锁                  | 限制设备只接受特定运营商策略下的 SIM                     | 属于设备策略和基带/激活链路的一部分      |
| MEP / QPE 卡贴          | 改变或编排 iOS 看到的 SIM 身份，让锁机策略可接受            | 只影响身份上报与解锁路径，不能凭空改基带能力  |
| Carrier Bundle / IPCC | iOS 的运营商配置包，包含 APN、VoLTE、VoWiFi、5G、IMS 等 | CarrierLock 只优化这一层的选择结果 |

核心区别：卡贴负责“让设备接受这张卡”，Carrier Bundle 负责“让设备用正确的运营商配置提供服务”。两者相邻，但不是同一个问题。

## 2. 开机后的链路

简化后的流程如下：

```text
基带读取 SIM / 卡贴组合
→ 向 iOS 上报 IMSI、ICCID、PLMN 等身份
→ iOS 检查激活状态与运营商策略
→ CommCenter 为当前 SIM 选择 carrier bundle
→ 命中本地 Overlay 链接时直接加载
→ 未命中时继续查系统 bundle / 联网匹配
→ 配置加载后进入正常通话、短信、数据服务
```

CarrierLock 写入的是完整 IMSI 到系统 bundle 的映射：

```text
/var/mobile/Library/Carrier Bundles/iPhone/<完整 IMSI>
  → /System/Library/Carrier Bundles/iPhone/<Bundle Name>.bundle
```

它不修改：

- 基带固件或基带能力。
- SIM 或卡贴内部数据。
- 运营商锁策略。
- 激活服务器结果。
- 系统只读分区。

## 3. 跳激活的常见原因

iOS 和 CommCenter 会在重启、基带复位、SIM 重读、飞行模式切换、网络重注册等时机重新校验：

1. 当前 SIM 身份。
2. 运营商策略和激活记录。
3. Carrier Bundle 是否与当前身份匹配。

当身份变化、配置匹配不稳定，或需要重新完成激活流程时，就可能出现：

- “需要激活”页面。
- 无服务或信号延迟。
- 运营商显示为 `carrierxx.xx`。
- 横竖屏暂时锁定。
- 通知不恢复。

通宵*充电场景更容易触发，不是因为“充电”本身，而是因为几个条件叠加：*

- *长时间空闲后系统执行维护任务。*
- *Wi-Fi 可用时更容易联网校验。*
- *夜间可能发生基带复位或网络重注册。*
- *卡贴可能临时切换 IMSI。*
- *激活流程未及时完成时，通*知和方向等服务状态可能未完全恢复。

## 4. MEP 与 QPE 的差别

| 场景              | MEP 表现                  | QPE 表现                    |
| --------------- | ----------------------- | ------------------------- |
| 开机激活            | 常见会弹一次激活                | 通常不弹激活                    |
| 配置显示            | 激活完成后可能较快匹配             | 可能显示 LTE / `carrierxx.xx` |
| 典型问题            | 激活完成太慢时需要重新获取信号         | 接不到电话、上不了网                |
| 常见手动处理          | 及时完成激活或重新获取信号           | 手动加载 IPCC、注销资源库           |
| CarrierLock 的作用 | 优化激活后的 bundle 命中，减少重复匹配 | 让服务 IMSI 命中本地配置，减少手动处理    |

### 4.1 MEP 开机流程

```text
开机
→ MEP 编排 SIM 身份
→ iOS 可能要求完成一次激活
→ 及时完成激活
→ 卡贴最终上报服务 IMSI
→ CommCenter 扫 Overlay
→ 命中则直接加载对应 bundle
→ 信号和运营商配置恢复
```

如果激活太慢，卡贴可能已经切到另一个 IMSI 或 fallback 状态。若该 IMSI 没有锁定，就仍需要重新获取信号。

因此，MEP 场景的合理预期是：

- 不能保证开机不弹激活。
- 激活完成后，配置匹配应更快、更稳定。
- 日常使用和夜间空闲时的被动跳激活应明显减少。

### 4.2 QPE 开机流程

```text
开机
→ QPE 使用辅助身份满足锁机策略
→ 切换到实际服务 SIM
→ CommCenter 查找配置
→ 未命中时显示 LTE / carrierxx.xx / 无法服务
→ 命中 Overlay 后加载正确 bundle
→ APN、VoLTE、运营商显示等恢复正常
```

QPE 的核心问题通常是“最终服务身份没有拿到正确配置”。锁定后如果服务 IMSI 命中，理想情况下可以减少或省去：

- 手动加载 IPCC。
- 注销资源库。
- 手动触发重新匹配。

如果 QPE 开机先短暂上报临时 IMSI，前几秒仍可能显示 `carrierxx.xx`。等它切到服务 IMSI 后，Overlay 才会命中。

## 5. 双卡应如何锁定

双卡且两条线都在使用时，应为每条真实服务线路分别写入映射：

```text
卡 1 服务 IMSI -> 对应运营商 bundle
卡 2 服务 IMSI -> 对应运营商 bundle
```

例如：

```text
46000XXXXXXXXXXXX -> CMCC_cn.bundle
46001XXXXXXXXXXXX -> China_Unicom.bundle
```

不要按“物理卡槽”盲锁，也不要把所有日志里出现过的 IMSI 全部锁上。判断标准是：

> 信号稳定后，CommCenter 为这条正在提供服务的线路选择配置时实际使用的完整 IMSI。

常见 IMSI 有三类：

| IMSI 类型               | 是否锁定       |
| --------------------- | ---------- |
| 真实服务卡的 IMSI           | 优先锁定       |
| 卡贴临时或辅助 IMSI          | 通常不锁       |
| 只用于解锁的辅助卡 / eSIM IMSI | 若不提供服务，则不锁 |

双卡建议流程：

1. 分别启用或分别插入一张卡，开始监听。
2. 在卡贴菜单刷新 SIM 信号。
3. 记录该线路的服务 IMSI。
4. 确认日志里看到的 bundle 名称。
5. 回到双卡状态，分别锁定两个服务 IMSI。
6. 重启测试两条线路是否都能直接加载正确配置。

如果双卡同时监听时出现多个 IMSI 和多个 bundle，无法精确配对，优先使用“单线路分别确认”的方式。

## 6. 中国运营商参考

| 运营商  | 常见 PLMN                                       | 常见 bundle              |
| ---- | --------------------------------------------- | ---------------------- |
| 中国移动 | 46000 / 46002 / 46004 / 46007 / 46008 / 46020 | `CMCC_cn`              |
| 中国联通 | 46001 / 46006 / 46009 / 46010                 | `Unicom_cn`            |
| 中国电信 | 46003 / 46005 / 46011 / 46012                 | `ChinaTelecom_USIM_cn` |
| 中国广电 | 46015                                         | `CBN_cn`               |

bundle 名称必须对应系统目录下实际存在的文件夹。不同 iOS 版本可能存在命名差异，最终应以日志中实际加载的名称为准。

## 7. CarrierLock 的准确边界

`CarrierLock` 这个名字偏产品化。准确说，它锁定的对象是：

```text
某张 SIM 的完整 IMSI → 某个运营商 Bundle
```

不是：

```text
网络锁 / 运营商锁 / 激活锁
```

因此更技术化的名称可以理解为 `Carrier Bundle Lock`。它解决的是“配置选择不稳定”，不是“运营商授权”。

## 8. CarrierLock 能解决什么

CarrierLock 可以减少：

- CommCenter 反复联网匹配 carrier bundle。
- 配置缓存失效后的重新匹配。
- 日常使用中的被动跳激活。
- QPE 场景下 `carrierxx.xx` 和无法服务的时间。
- 手动加载 IPCC、注销资源库、重新获取信号的频率。

它不能保证：

- 绕过运营商锁或激活锁。
- 阻止 MEP 开机主动弹出激活。
- 阻止卡贴临时切换 IMSI。
- 修改基带频段能力或强制开启基带不支持的 5G 频段。
- 在更换 SIM 后继续生效。
- 在系统更新或 Airlift 失效后继续写入。

## 9. 验证方式

当前 App 会直接枚举用户态 Carrier Overlay，读取 15 位数字命名的 IMSI 符号链接，并与 Lockdown 返回的 SIM 信息比对。

可观察的信息包括：

- 每个 SIM 卡槽的完整 IMSI。
- Overlay 中已有的 IMSI 链接及其目标 Bundle。
- 未锁定的 SIM 可用的 PLMN 自动匹配结果。
- 锁定后实际链接目标与用户选择的 Bundle 是否一致。

有效判定：

```text
检查状态
→ Lockdown 返回 SIM1 / SIM2 的 IMSI
→ 枚举 Overlay 目录
→ 若存在同 IMSI 链接，则读取目标 Bundle
→ 状态页显示该 SIM 已锁定
```

注意事项：

- PLMN 自动匹配只是预选建议，最终应以系统目录中实际存在的 Bundle 为准。
- 如果链接存在但目标 Bundle 不存在，CommCenter 可能忽略该链接并回退默认选择。
- 检查结果只能证明当前 Overlay 状态，不能证明运营商锁策略永远不会再触发激活。

## 10. 敏感信息与安全边界

本文中的 IMSI、UDID、运行目录均已脱敏。实际操作时不要公开分享：

- 完整 IMSI。
- ICCID。
- 手机号码。
- UDID 或序列号。
- 配对文件。
- 运行日志原文件。

只在使用者本人设备或已获授权设备上操作。使用前应确认符合当地法律法规、运营商条款及相关平台协议。

## 免责声明

本软件仅供个人学习、研究以及维护本人拥有或已获授权的设备使用。下载、安装或使用本软件均属于个人自发行为，风险由使用者自行承担。使用者应自行确认符合当地法律法规、运营商条款及相关平台协议。

本软件按“现状”提供，不提供任何明示或默示保证。开发者不对因使用本软件导致的设备异常、数据丢失、业务中断、账户风险、法律问题或其他后果承担责任。

## 构建

打开 `CarrierLock.xcodeproj`，选择 `CarrierLock` target，设置你的签名团队，然后构建到实体设备。

Airlift FFI 的 Rust 完整源码位于 [`rust-core/`](./rust-core/README.md)。
修改源码后运行 `scripts/build-airlift-xcframework.sh`，并把更新后的
`Vendor/CarrierLock/AirliftFFI.xcframework` 与源码一起提交。

如需构建 unsigned IPA，请在 GitHub Actions 中运行 `Release unsigned IPA` 工作流。成品文件名为 `carrierlock-v<version>-unsigned.ipa`。

## 致谢 / Credits

- 感谢 [AirCard-iOS](https://github.com/mak5er/AirCard-iOS) 提供 `rust-core/` 中的 Rust Airlift FFI。
- 感谢 [CarrierSIM](https://github.com/ios-bundles/CarrierSIM) 提供的 IPCC Overlay 固定链接原理与实现参考。
- 感谢 [AirliftSilence](https://github.com/YiHoooong/AirliftSilence) 提供的静音音频资源与替换方案研究。
- 感谢 [airlift](https://github.com/0xjohnnydev/airlift)（作者 0xjohnny）提供的 AirTraffic 与 Airlock 研究，其作为项目依赖被保留。
- 感谢 [Placard](https://github.com/frs0n/placard) 的贡献者提供的原始 iOS 项目结构与容器访问实现。

## 许可证 / License

CarrierLock 以 [GNU 通用公共许可证 v3.0](LICENSE) 发布。
