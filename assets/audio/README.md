# 一炮千径 · 原创合成音效

由项目自己的 `EnergySoundBank` 离线生成，无外部采样、音乐、配音或素材授权依赖。PCM16 单声道 WAV，默认 22050 Hz。音频参数以 `balance.json/audio` 为唯一项目来源；`bank.sha256` 识别对应配置。

| 文件 | 事件 | 默认时长 | 优先级 |
|---|---|---:|---:|
| ui_confirm.wav | 菜单确认 | 80 ms | 4 |
| ui_cancel.wav | 菜单取消／返回 | 90 ms | 4 |
| place.wav | 合法放置 | 100 ms | 2 |
| activate.wav | 装置激活 | 240 ms | 5 |
| dismantle.wav | 主动拆除 | 180 ms | 3 |
| tower_fire.wav | 塔真实发射 | 70 ms | 1 |
| transform.wav | 装置转换／储存／释放 | 90 ms | 1 |
| hit.wav | 真实正伤害 | 60 ms | 2 |
| destroy.wav | 节点摧毁 | 240 ms | 6 |
| warning.wav | 已有方向预警 | 300 ms | 7 |
| target.wav | 达标清场 | 300 ms | 8 |
| victory.wav | 成功 | 450 ms | 9 |
| failure.wav | 失败 | 450 ms | 9 |
| enemy_attack.wav | 敌人实际攻击 | 120 ms | 2 |

采用有界基频／泛音与短包络，不使用模拟 RNG。世界与 UI 分别使用有限播放器池，类型冷却、同帧合并、优先级抢占与保守混音增益限制叠加；静音立即停止当前声音。世界声音随暂停冻结，菜单声音保持可用。

默认加载此目录 WAV；F2 修改合成配置后在统一重置时编译一次音库，绝不逐命中合成。需要把新默认烘焙为资源时，在隔离项目执行 `tools/bake_energy_audio.gd`，检查输出后再同步 WAV 和哈希。

运行 `tools/run_validation.ps1 -Suite Audio` 会在隔离项目中烘焙并使用本机真实输出设备测试。其他套件使用 Dummy 隔离设备变化，不能据此宣称听觉验收完成。听感、耳机／扬声器音量及长期舒适度请按 `docs/presentation-observation.md` 实际确认。
