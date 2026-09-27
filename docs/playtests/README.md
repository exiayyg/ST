# v0.5.1 示例报告

这是一局实际 Godot 4.7.1 / D3D12 全屏、隔离进度目录中的**自动化输入验收**，不是陌生玩家的意见或真人教学验证。

- [summary.json](example-v051-summary.json)：由游戏自己的 PlaytestRecorder 生成，未合成结算或修改 HP / 动量账本。
- [events.jsonl](example-v051-events.jsonl)：原样保留的语义事件与每秒聚合战况。
- 源运行：`artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/`。

本局放置 2 对二极管，完成 1 次练习拆除、1 组旋转和 1 次实际拖动；通过两波，记录内游戏时间约 89.96 秒，塔 HP 1000，最终利用率约 18.53%。自动发射全程开启；结算后关闭自动发射是既有结束行为。

字段说明：

- `first_events` 的时间相对于本局开始；未出现的事件不包含对应字段。`actions` 未出现的操作等价于次数 0。
- `waves/<n>/actual_damage` 包含清场期间的实际伤害；两波分别为 64 和 108。
- `utilization`、`tower_source_momentum` 和 `stats` 遵循现有 HUD / 胜负口径：达标时锁存。本局第二波锁存伤害约 37.8、源动量 204、利用率约 18.53%；不能用包含清场的 actual_damage 反算同一锁存利用率。
- `live_source_momentum` 是未锁存的实时原生账本，包含达标后继续发射的动量；休整不会覆盖前一波记录。
- `wave_device_losses` 记录本波敌人摧毁导致的装置损失；主动拆除单独出现在 actions 中。
- `paused_seconds` 与运行时间分开。本局未打开暂停，所以为 0；暂停逻辑另有真实输入、聚合计时和生命周期测试。
- process_id 仅用于避免把另一个正在运行的本机实例误判为异常中断；没有采集个人身份或原始输入。

意见留空是允许的。试玩数据不会自动上传；真人试玩请使用 [观察表](../playtest-observation.md)，不要把本示例当作教学体验的替代证据。
