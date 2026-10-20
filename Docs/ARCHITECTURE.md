# AirStrum Architecture / 架构

## English

The iPhone is the audio authority. A held chord is UI state on the phone; a
Watch strum is a short event delivered through `WCSession.sendMessage`. The
phone turns that event into a generated chord buffer and plays it through an
`AVAudioEngine` chain with reverb and delay.

The Watch does not stream audio samples. It samples processed device motion at
60 Hz, applies a small debounce window, classifies a direction, estimates a
velocity, and sends only a property-list message.

This keeps the interaction understandable and lets the audio path remain on
one device. It also means a strum is intentionally ignored when the phone is
not reachable or no chord is held.

## 中文

iPhone 是声音主机。按住的和弦是手机端 UI 状态；手表扫弦则通过
`WCSession.sendMessage` 发送一个短事件。手机收到事件后生成对应的和弦音频
buffer，通过带混响与延迟的 `AVAudioEngine` 链路播放。

手表不传输音频采样，而是以 60Hz 采样处理后的设备运动数据，通过简单的去抖
窗口判断方向并估算力度，只发送 property-list 消息。

这样可以让交互边界清晰，并让音频链路集中在一台设备上。代价是：手机不可达
或没有按住和弦时，扫弦会被有意忽略。
