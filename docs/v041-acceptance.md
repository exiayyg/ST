# v0.4.1 验收与下一步

## 交付范围

完成常用调参置顶、射速倒数视图、schema v5 迁移、统一暂停原因、帮助/退出/离开确认、真实结算按钮、失败最佳纪录显示、保存失败重试和进度中断恢复。保留基线 80c90e2 后的工作树差异，未创建新提交。

冻结的唯一初始弹道、熵阈值语义、动量归零回收和九装置机制均未改变。布局数值仍由 balance.json 控制。本轮仅修改 GDScript、配置和项目自有数值编辑器插件，没有修改 C++ 或 Fennara 插件。

## 自动化验收

Godot 4.7.1.stable.official.a13da4feb。各命令使用 PowerShell Start-Process -Wait -PassThru，等待退出并检查退出码和标准错误日志。

- balance_config_test：v1/v2/v3/v4 到 v5 的事务迁移、字段覆盖、非法配置、稳定 JSON 往返、熵规则、常用/完整参数双向同步、7.5 发/s 倒数不舍入、非法射速拒绝、宽窄布局、搜索折叠恢复、未应用不影响原配置。
- campaign_framework_test：目录验证、顺序解锁、失败最佳值、超过 100%、损坏 JSON 独立保留、正式文件缺失恢复备份、损坏正式文件不覆盖有效备份、稳定保存。
- frontend_navigation_test：主菜单和失败纪录、一次结算、保存失败后按钮重试且保留原结算、重复重试幂等、结算默认焦点/Tab/方向键、建造/教学场暂停、F2/Esc 叠加、确认取消与执行、世界 tick 和发射累积冻结、模态 Enter 不触发底层暂停操作。
- prototype_logic_test、runtime_ux_regressions_test、v03_tutorial_test、native_lifecycle_test：建造/迷雾/唯一弹道/拆除/教学/全屏与绑定生命周期回归。
- test_combat_skeleton、test_endless_mode：单波与无尽回归，包含 20 波加速耐久。
- playthrough_v041 的 --exit-main、--exit-paused：独立进程通过菜单退出；后者确认框默认取消，确认后退出；退出码 0 且输出 V041_EXIT_CONFIRMED。
- format_balance：配置完整校验并稳定格式化。

输入验证通过 Godot Viewport.push_input 派发按下/松开、鼠标长按和移动，经过实际 GUI 与未处理输入链，而非直接调用按键处理函数。它验证引擎输入链，不等同于真人用物理键鼠盲玩；后者仍待进行。旧单元测试的直接方法调用继续保留为底层回归。

## 视觉证据

当前任务未暴露 Fennara MCP。使用隔离副本、Godot 4.7.1、D3D12 Forward Mobile 和 RTX 5060 生成并目检实际画面；运行时截图为 2560×1440 全屏。编辑器截图来自实际编辑器 viewport。初次编辑器截图任务过早在导入期间退出发生异常，验收脚本已改为等待文件扫描完成；后续完整等待与退出验证通过。

截图由 tools/capture_frontend_stage.gd 和项目自有编辑器测试入口生成，位于 artifacts/，默认不提交 Git：

- v041-main-menu.png、v041-help.png：模式、帮助与退出入口。
- v041-level-failed-best.png、v041-level-completed.png：失败未完成但最佳 121%，以及已完成最佳 142%。
- v041-tuning-wide.png、v041-editor-tuning.png：F2 和编辑器共用常用参数布局。
- v041-pause.png、v041-abandon-confirmation.png：统一暂停和默认取消。
- v041-settlement.png、v041-save-retry.png：真实焦点与成绩重试，按钮均在结算框内。
- v041-playthrough-3.png、v041-playthrough-4.png、v041-playthrough-8.png、v041-playthrough-return.png：实际流程的建路、战斗、失败与返回。

121% / 142% 和成功结算截图是明确构造的 UI 验收样本，不是实际通关成绩。

## 从主菜单开始的首关流程试跑

工具：tools/playthrough_v041.gd。未修改 HP、敌人、波次状态、账本或 balance 参数；通过菜单 Enter、亮区长按轮盘、二极管两阶段放置、Delete 长按和 Q 旋转进行操作。采用关卡建议坐标，建立北向路径后保持位置/朝向与默认自动发射，不继续优化网络。

实际 D3D12 全屏记录（以试跑开始为零点）：

| 时间 | 结果 |
| --- | --- |
| 1.57 s | 从主菜单和关卡选择进入首关 |
| 5.35 s | 完成练习二极管双端放置 |
| 6.17 s | 完成长按拆除，进入建路阶段 |
| 6.83 s | 放好路径并用 Q 调整为北向 |
| 7.35 s | 真实传送触发首波 |
| 82.17 s | 首波超时；最终利用率 1.7057569%，未达到 10% |
| 82.81 s | 结算按钮正确返回关卡选择 |

结论：从入口到失败结算/成绩反馈/返回的流程可运行；本次没有完成第一波，更没有获得两波通关时长，不能据此认定原先的“5–8 分钟切片”目标已经达成。另一轮无头同策略试跑同样得到约 1.71%。

试跑中发现并修复：结算旧 Enter 默认操作处理抢占真实按钮焦点，使已聚焦的返回错误执行重试。现在只有真实 Button 处理键盘激活。

## 下一步建议（尚未实施）

先做首关教学可达性与反馈修整，再做第二关：

1. 邀请一名未读设计文档的玩家用物理键鼠盲玩，记录误点、等待、卡住和实际成功通关时间。
2. 验证“按建议建路”到“有效命中北侧敌人”之间的难度跃升。当前试跑证明静态示例路径不足以达标；尚不能推出关卡不可通关。
3. 让提示清楚区分“方向正确/网络接通”与“持续命中有效目标”，并讲明移动出口、战斗中重定向和无效发射对利用率的影响。不要让玩家误以为完成摆放即可等待胜利。
4. 根据真人试验，再用 F2 调整首波方向分布、出敌时机、目标利用率或提示位置；本轮未擅自更改这些平衡值。

复现（在隔离副本下使用 README 的 Invoke-GodotQa，长流程最多 300 秒）：

```powershell
Invoke-GodotQa @('--path', $ProjectPath, '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', '--script', 'res://tools/playthrough_v041.gd')
Invoke-GodotQa @('--headless', '--path', $ProjectPath, '--script', 'res://tools/playthrough_v041.gd', '--', '--exit-main')
Invoke-GodotQa @('--headless', '--path', $ProjectPath, '--script', 'res://tools/playthrough_v041.gd', '--', '--exit-paused')
Invoke-GodotQa @('--path', $ProjectPath, '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', 'res://scenes/tests/capture_frontend_stage.tscn')
Invoke-GodotQa @('--path', $ProjectPath, '--editor', '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', '--', '--test-balance-editor-entry', '--capture-balance-editor')
```
