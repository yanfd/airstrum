# AirStrum Architecture / 架构

## English

The iPhone is the audio authority. A held chord is UI state on the phone; a
Watch strum is a short event delivered through `WCSession.sendMessage`. The
phone uses prewarmed chord buffers and plays them through an
`AVAudioEngine` chain with reverb and delay.

The Watch does not stream audio samples. It samples processed device motion at
a requested 60 Hz update interval, applies a debounce window, labels the sign
of an acceleration change, estimates intensity, and sends a property-list
message. These labels have not been validated as physical up/down strokes.
Actual update timing is determined by the system. The current detector is
experimental, not a calibrated motion-tracking model.

This keeps the interaction understandable and lets the audio path remain on
one device. It also means a strum is intentionally ignored when the phone is
not reachable or no chord is held.

## 中文

iPhone 是声音主机。按住的和弦是手机端 UI 状态；手表扫弦则通过
`WCSession.sendMessage` 发送一个短事件。手机使用预热的和弦音频 buffer，通过
带混响与延迟的 `AVAudioEngine` 链路播放。

手表不传输音频采样，而是请求 60Hz 运动更新，实际更新时间由系统决定。当前
检测器通过加速度变化的符号标记方向并估算强度，使用去抖窗口，只发送
property-list 消息。这些方向标签尚未验证为真实上下扫；检测器仍是实验实现，
不是经过校准的运动追踪模型。

这样可以让交互边界清晰，并让音频链路集中在一台设备上。代价是：手机不可达
或没有按住和弦时，扫弦会被有意忽略。
