# v0.5 首关可玩性与战斗教学闭环

日期：2026-09-07。基线仍为 `80c90e2`，本轮没有提交，没有改动原生模拟。

## 范围与实现

- 塔保持 1 发/秒、质量 0.05、初速度 240、HP 1000。与开工隔离副本逐项对比，tower、devices、simulation、entropy、enemies（含 DEV 与教学敌人）、waves/endless 完全相同。
- 首关出口建议改为 `(0, -180)`；第一波北边缘中央半宽 24；第二波近战中央半宽 48、远程中心比例 0.54 / 半宽 48；远程首次生成从 26 秒提前到 8 秒。没有更改人数上限、目标、波长或休整时间。
- `SpawnRegion` 将生成范围编译为强类型 Resource，沿用稳定 ID 分布；完整边缘保留旧 lerp 运算。边缘比例以扣除 spawn_edge_inset 的可用边长计算；区段不允许越出该范围。生成位置不读取玩家装置。无效组在替换波次与重置账本之前拒绝；非法位置不会消耗敌人 ID。
- 敌人索敌缓存登记二极管两个端点。目标包含装置 ID 与端点索引；移动使索引失效，删除立即失去目标；射线按塔优先、稳定装置 ID/端点排序，一次攻击只扣一次共享 HP。
- 教学导演消费真实传送、有效伤害、移除事件及帧末可见敌人摘要。提醒需要自动发射且至少一个活敌人同时处于相机视野和照明范围；停火、没有可见敌人会清除无伤害计时及过期提示。结算后不再接受反馈事件。暂停由已有世界模态机制冻结，不使用墙钟计时。
- 清场状态始终保留在顶部 HUD；教学短句优先显示停火、节点丢失和瞬态反馈，避免清场文案遮住修复指导。重建路由只恢复提示，不重新开始波次或重置账本。

## schema v7 与调参位置

`config/balance/balance.json` 仍是唯一默认来源。新增字段自动进入编辑器和 F2 的完整分类：

- `levels/<id>/waves/<wave>/groups/<group>/spawn_region`：`mode`（full_edge / segment）、`center_ratio`、`half_width`（像素）。DEV 单波生成组同样登记；无尽生成和无参数直接调用默认 full_edge。
- `levels/<id>/feedback`：`no_damage_seconds = 8`、`confirmation_seconds = 3`、`reminder_interval_seconds = 12`。

v6→v7 只在工作副本补入整条边缘和反馈字段，不更改用户的射速、敌人、装置或首关建议位置；v1–v6 串联迁移后仍需点击保存才写回。首关的窄区段与建议位置是本次单独的内容变更，不是迁移行为。JSON 保持稳定排序。

## 基线与失败轨迹

开工快速回归 14 项通过：`artifacts/qa/v05-before-25c8ff7793f84720a2b189c7b03d2e4e/summary.json`。

同一旧版输入脚本从主菜单进入并完成练习，约 12.50 秒开始第一波，50.28 秒达到目标；88.07 秒清场期间塔被摧毁，完成波数 0。结果见该目录 `playthrough.stdout.log`。因此旧的 1.71% 不是当前 1 发/秒配置的基线。

新方案不调整网络的诊断试跑能够完成第一波并达到第二波目标，但剩余压制者停在 `(79.35, -510.54)` 左右，处于 x=0 弹道之外，持续射击二极管出口，最终摧毁节点。没有将这种“达标但未清场”宣布为通关：

- 真实输入未调整试跑 300 秒超时：`artifacts/qa/v05-first-7ecf8acc02af4f41ac343f54849f2eaa/playthrough.stdout.log`。
- 固定步长诊断轨迹：`artifacts/qa/v05-verified-af54ff6eb18c42829282033bb73f5947/project/artifacts/v05-route-trial.json`。该工具使用公开建造命令加速推进，不是 UI 验收，不修改 HP、账本或导演状态。

## 实际通关参考操作

Godot 4.7.1 / D3D12 / 全屏，实际鼠标与键盘事件：主菜单 → 首关 → 放置练习 → 长按 Delete → 建路 → 两波 → 结算 → 保存 → 返回关卡选择。

1. 按教学提示放置、拆除练习二极管。
2. 入口 `(180, 0)`，出口 `(0, -180)`，出口朝北；保持自动发射。
3. 第一波完全不调整。
4. 第二波开始约 24 秒后，向北平移相机，将出口一次拖至 `(80, -340)`，仍朝北。该固定参考动作不读取敌人位置、ID 或 HP，不逐个追踪敌人。

首次实际输入验收结果：全程自动发射、第一波首次至末次有效伤害间隔 **11.68 秒**且无网络操作；第二波 **1 次拖动**，两波完成；约 **91 秒**从主菜单到结算。总实际伤害 172、装置损失 0、塔存活，第二波达标利用率 **18.5294%**。清场继续发生的伤害不修改已锁存的结算值，保持既有规则。成绩 JSON 回读为 completed=true，best_utilization=0.185294114491519。

首次报告：`artifacts/qa/v05-input-ref-7074d049753148f494c5ea7ea57b404d/project/artifacts/v05-input-report.json`。最终复验还加入保存文件断言，以及故意偏置出口后等待真实无伤害提醒、再纠正出口的输入探针；探针与一拖动参考使用独立进度、报告与截图文件，不合并为一条成功轨迹。

## 乐观可达性报告

`tools/report_v05_reachability.gd` 调用真实 WaveDirector 调度，记录固定步长生成时刻与各实例 HP，并计算“当时累计可用 HP / 持续开火源动量”。不进行攻击，不提前锁存目标，假定所有已生成 HP 都能立即转成实际伤害。

| 波次 | 目标 | 截止时 HP / 源动量 | 时序峰值上界 |
| --- | --- | --- | --- |
| 北侧破线 | 10% | 56.89% | 82.05% |
| 北侧压制 | 18% | 41.94% | 112.50% |

这只排查明显不可达配置，不考虑飞行、吸收、敌人行动、遮挡、激活或节点损失，不证明玩家能通关。真实达标会提前停止生成，不为展示全部敌人绕过结束规则。

## 可复现命令

```powershell
.\tools\run_validation.ps1 -Suite Full -Label v05-full
.\tools\run_validation.ps1 -Suite Playthrough -Label v05-input -TimeoutSeconds 300
.\tools\run_validation.ps1 -Suite Performance -Label v05-performance
```

每项使用隔离项目/APPDATA，等待进程结束，检查超时、退出码、错误日志与预算。Full 包含迁移/面板、出生序列、双端索敌、真实传送恢复、反馈冷却、九装置、熵、迷雾、拆除、暂停、导航、进度、单波、无尽 20 波及 C++ 规则回归。Playthrough 的每个进程分别输出独立结果，不能以某一项成功替代另一项失败。

本轮 Fennara 状态确认连接 Godot 4.7.1，但全项目诊断请求超时；后续采用隔离 CLI 导入、规则检查和实际渲染，不修改插件、不重启用户编辑器。新脚本 UID 使用隔离 Godot 导入生成值保留到源项目。

## 最终复验与截图

- 完整套件 **17/17 通过**：`artifacts/qa/v05-final-full-a69719ca874c4c7096b2b3aaeec2318e/summary.json`。
- 实际输入套件 **导入与两条路线全部通过**：`artifacts/qa/v05-final-input-b6ff31fe8273429a8d16fde22d062cca/summary.json`。参考路线 1 次拖动，第一波无调整有效伤害窗口 11.6858 秒；反馈探针 2 次拖动，间隔 8.1148 秒，真实触发无伤害提醒后恢复命中并通关。两条路线塔存活、节点损失 0、自动发射保持开启、保存文件 completed=true。
- 性能套件通过：`artifacts/qa/v05-final-performance-530d74d88f624476affbe23ba7adb3d5/summary.json`。代表场景 9,879 弹丸、50,016 波点、100 装置、300 敌人，1152×648 D3D12：模拟 60 Hz p95 **6.557 ms**、边界 **2.861 ms**、上传 **2.167 ms**、绘制 **0.407 ms**、整帧 **13.026 ms**；300 敌人 AI p95 **1.353 ms**；1000 敌人压力测试无崩溃。分别满足 8 ms、60 FPS 帧预算及 2 ms AI 预算。短时采样，不宣称所有机器或所有网络都能保持该性能。
- `git diff --check` 通过；本轮原生目录无差异。新旧工作树改动均保留，没有提交。

截图来自实际 2560×1440 全屏渲染并逐张目检，不是构造胜利的 UI 夹具。目录为 `artifacts/qa/v05-final-input-b6ff31fe8273429a8d16fde22d062cca/project/artifacts/`：

- [真实传送与接通提示](../artifacts/qa/v05-final-input-b6ff31fe8273429a8d16fde22d062cca/project/artifacts/v05-route-connected.png)
- [首次实际伤害反馈](../artifacts/qa/v05-final-input-b6ff31fe8273429a8d16fde22d062cca/project/artifacts/v05-first-hit-feedback.png)
- [出口受击与共享闪烁](../artifacts/qa/v05-final-input-b6ff31fe8273429a8d16fde22d062cca/project/artifacts/v05-dual-anchor-damage.png)
- [真实无伤害提醒与可见压制者](../artifacts/qa/v05-final-input-b6ff31fe8273429a8d16fde22d062cca/project/artifacts/v05-probe-no-damage-feedback.png)
- [实际两波完成结算](../artifacts/qa/v05-final-input-b6ff31fe8273429a8d16fde22d062cca/project/artifacts/v05-phase-finished-2-finished.png)
- [成绩保存并返回关卡选择](../artifacts/qa/v05-final-input-b6ff31fe8273429a8d16fde22d062cca/project/artifacts/v05-saved-result-return.png)

## 尚待真人验证

自动化通关证明可达和操作负担，不证明陌生玩家理解。尚未安排到真实陌生玩家，因此不宣称教学效果已验证，也不把约 90 秒自动流程拉长成 5–8 分钟。

下一步盲测重点：是否理解长按轮盘与双端选择；首波伤害可能先发生在照明/相机之外，短句与利用率是否足以解释；压制者射程大于装置照明半径，玩家能否由射线与提示理解要前移出口；是否把“达标”误读为无需清场。记录首次激活/命中、停滞、错误操作、调整次数和真实通关时长，再决定局部教学修订，不扩展第二关。
