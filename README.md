# AirStrum

> **Play the air. / 弹奏空气。**

AirStrum is a native Swift iPhone + Apple Watch instrument. Hold a chord on
It is designed for immediate, playful sound rather than a traditional guitar
simulator.

AirStrum 是一个原生 Swift iPhone + Apple Watch 体感乐器。用一只手在 iPhone
上按住和弦，用另一只手佩戴 Apple Watch 扫弦。它追求即时、好玩的声音反馈，
而不是模拟一把完整的真实吉他。

## Current build / 当前版本

- Native SwiftUI UI for iOS and watchOS / iOS 与 watchOS 原生 SwiftUI 界面
- Watch-side Core Motion strum detection / 手表端 Core Motion 扫弦识别
- WatchConnectivity live messages / WatchConnectivity 实时消息
- Hold-to-play chord interaction / 按住和弦才发声
- Programmatically generated chord tones with short natural decay / 程序生成和弦音色与短尾音衰减
- Down-strum and up-strum direction / 下扫与上扫方向

This is an early personal prototype. Motion thresholds and audio feel must be
tuned on a real paired iPhone and Apple Watch. The simulator cannot validate
the physical strum experience.

这是一个早期个人原型。动作阈值和声音手感必须在真实配对的 iPhone 与 Apple
Watch 上调试；模拟器无法验证真实扫弦体验。

## Interaction / 交互

1. Install and open AirStrum on iPhone and Apple Watch.
2. Allow motion and audio permissions.
3. Keep a chord button pressed on iPhone.
4. Tap **STRUM** on the Watch to begin motion detection.
5. Strum down or up with the Watch hand.
6. Release the chord button to fade the current chord out.

1. 在 iPhone 与 Apple Watch 上安装并打开 AirStrum。
2. 允许动作与音频权限。
3. 在 iPhone 上按住一个和弦按钮。
4. 在手表上点击 **STRUM** 开始动作识别。
5. 佩戴手表的手向下或向上扫动。
6. 松开 iPhone 和弦按钮，让当前和弦衰减消失。

## Build / 构建

The repository uses XcodeGen to keep the project definition readable.

```bash
brew install xcodegen
xcodegen generate
open AirStrum.xcodeproj
```

Then select an iPhone and its paired Apple Watch in Xcode and run the iOS
scheme. Set your own Signing Team in the two targets.

仓库使用 XcodeGen，让工程配置保持可读：

```bash
brew install xcodegen
xcodegen generate
open AirStrum.xcodeproj
```

然后在 Xcode 中选择 iPhone 及其配对的 Apple Watch，运行 iOS scheme，并在两个
target 中设置自己的签名 Team。

## Architecture / 架构

```text
iPhone SwiftUI
  ├─ held chord state
  ├─ AVAudioEngine chord voice
  └─ WatchConnectivity session
          ↕ live strum events
Apple Watch SwiftUI
  └─ Core Motion → down/up + velocity
```

The watch sends compact motion events; the phone remains the source of chord
state and audio output. No network service is required.

手表只发送紧凑的动作事件；iPhone 负责和弦状态与声音输出。不需要服务器。

## License / 许可证

Personal prototype. Add a project-specific license before public distribution.

个人原型项目。如需公开分发，请先补充项目专用许可证。
