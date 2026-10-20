# Device acceptance / 真机验收

Status: pending. This is a test procedure, not a report of passing results.

状态：待执行。这是验收步骤，不是通过报告。

## Record the setup / 记录环境

Record iPhone model/iOS, Watch model/watchOS, wrist/crown orientation, app commit,
audio route, and whether the screen is awake. Never infer hardware results from
the offline mock tests.

记录手机与手表型号、系统版本、佩戴手腕与表冠方向、应用提交版本、音频输出方式
和屏幕状态。不得把离线模拟测试当作硬件测试结果。

## Required checks / 必测项

| Test / 测试 | Expected / 预期 | Result / 结果 |
| --- | --- | --- |
| Hold a chord without moving / 仅按住和弦 | Silence / 静音 | Not run / 未执行 |
| Strum without holding / 未按住时扫弦 | Silence / 静音 | Not run / 未执行 |
| Hold Em and strum / 按住 Em 扫弦 | One audible chord per intended stroke / 每个有意扫弦对应一次和弦 | Not run / 未执行 |
| Release mid-note / 发声途中松手 | Short smooth decay, no stuck tail / 短暂平滑衰减，无挂音 | Not run / 未执行 |
| Alternate chords / 切换和弦 | No stale chord triggered after release / 松手后不触发旧和弦 | Not run / 未执行 |
| Repeated down and alternating strokes / 连续下扫及上下扫 | Count missed/doubled/mislabeled strokes / 记录漏判、重复与方向误判 | Not run / 未执行 |
| Leave phone app while holding / 按住时切走手机应用 | Held state released / 持有状态释放 | Not run / 未执行 |
| Stop/restart Watch detection / 停止并重新启动识别 | No ghost first stroke / 无虚假首个扫弦 | Not run / 未执行 |
| Disconnect/reconnect / 断连并重连 | Honest status; no replay of offline strokes / 状态真实，离线动作不补播 | Not run / 未执行 |
| Lower wrist, then switch watch apps / 放下手腕再切换手表应用 | Record actual suspension behavior; no background promise / 记录实际挂起行为，不预设后台可用 | Not run / 未执行 |
| Phone call/audio route change / 来电或切换音频输出 | Record audio recovery and any required restart / 记录音频恢复及是否需重启 | Not run / 未执行 |
| Chinese/English, VoiceOver, large text / 中英文、旁白与大字体 | Controls readable and actionable / 控件可读可操作 | Not run / 未执行 |

## Timing and sound / 延迟与听感

Film the gesture and audible output together using an external recording device.
Report measurement method and frame resolution, median and slowest responses,
and missed strokes. Compare speaker/wired output with Bluetooth headphones.
Do not report a latency target as a measurement. Listen for clicks, clipping,
overlapping-note clarity, and audible difference between D and Dm and between G7
and a major triad. Offline spectrum tests alone cannot prove guitar realism.

用外部设备同时记录动作与声音，报告测量方法、视频帧精度、中位及最慢响应和漏判。
分别对比扬声器、有线与蓝牙耳机。不可将目标延迟写成实测值。试听是否存在爆音、
削波、重叠声部混浊，以及 D/Dm、G7/大三和弦是否可分辨。离线频谱测试不能证明
吉他音色真实。

No device acceptance has been completed yet. A full iOS/watchOS build and signed
installation must precede these checks.

尚未完成真机验收。以上测试需要先成功构建 iOS/watchOS 双端并签名安装。
