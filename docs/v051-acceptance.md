# v0.5.1 本机试玩交付

## 使用方式

用 Godot 4.7.1 打开项目并运行默认主菜单，在开发区域选择「首关试玩」。授权框默认不勾选；不勾选也能完整游玩。试玩不会修改正式关卡完成状态、最佳利用率或解锁。重试沿用本次授权，返回主菜单后重新选择授权。

同意记录后，报告仅保存在 `user://playtests/<run_id>/`：语义事件日志、每秒聚合战况及摘要 JSON。没有联网、录屏、个人身份、原始按键流或逐弹丸轨迹。结算后可打开报告目录、填写可跳过的意见。正常退出、重试、返回、配置重置各结束旧记录一次；下次启动会识别已保存但未正常结束的记录。写入失败单独提示，不阻断游戏，也不冒充正式成绩保存失败。

首次真人试玩请使用 [简短观察表](playtest-observation.md)，不要先查看自动化通关脚本。[示例报告](playtests/README.md) 来自真实引擎中的自动化输入，不是真人意见。

## 本轮实现

- 独立试玩启动上下文、同意记录开关、正式进度防写、授权生命周期、报告目录与可选意见。
- 独立 `PlaytestRecorder` 只观察现有事件和帧摘要。关闭记录不创建记录对象、文件或采样数据；日志不接管玩法。
- 拖动按实际完成的调整计数；取消但已移动仍记调整，选中不算移动。连续端点旋转按可调间隔合并；模态取消、非法初放、暂停分别记录。
- 长按轮盘进度、选中二极管入口／出口说明与出口箭头、正伤害命中闪烁、视野外首次命中文字、清场与波间指导。
- 死亡命中仅保留短暂绘制记录；敌人 AI、HP、碰撞仍立即移除。闪烁不会扩大照明，迷雾外不额外显示死亡闪烁。
- schema v8 增加 `playtest` 分类，串联旧版本迁移，记录节奏、旋转分组、反馈表现与布局参数均进入共享编辑器／F2。配置成功应用才分割记录与配置哈希。
- 修复测试暴露的单波会话信号闭包引用环，用等价具名回调释放会话；事件顺序回归不变。

与本轮开始时配置比较，排除 schema 版本和新增 `playtest` 分类后完全相同。未调整塔、装置、敌人、波次或首关难度；未修改 C++、Fennara 插件和项目场景资源。Git HEAD 保持 `80c90e2`，未创建提交。

## 验证记录

每项均使用隔离项目和 APPDATA，等待进程结束，检查退出码、超时及标准输出／错误日志。

| 验证 | 结果 | 证据目录（相对项目根） |
|---|---|---|
| 修改前 Fast 基线 | 16/16 | `artifacts/qa/v051-before-57f92ab5594e433fbbcb7f3451f0b48b/` |
| 最终 Full：配置、原生、建造、教学、暂停、导航、进度、单波、无尽及耐久 | 19/19 | `artifacts/qa/v051-delivery-full-18030477bd35494aaec014f802dffcd7/` |
| 实际输入：授权／未授权 UI、原路线、录制路线、偏置出口路线 | 5/5 | `artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/` |
| 最终代表管线与 AI | 3/3 | `artifacts/qa/v051-final-performance-a343ca5f24b849ef8e0c2d2d57776c5d/` |

Full 包含记录开关下相同事件顺序／动量账本／实体结果、未授权无文件、正式成绩文件不变、记录完成幂等、浮点 JSON 精度、写入失败、暂停、配置重置成功／失败和雾中命中隐藏。独立进程测试验证正常关闭及强制结束本测试子进程后的恢复，恢复不更改已写事件日志。

实际录制路线从菜单到结算约 91.10 秒，记录内游戏时间约 89.96 秒；全程自动发射，第一波首次命中后 11.69 秒无需调整的有效运行窗口，第二波一次拖动，塔 HP 保持 1000。偏置出口反馈路线约 98.82 秒，两次调整且间隔超过 5 秒。未合成胜利、修改 HP／账本或用停火提高利用率。

示例摘要的实际伤害包含清场伤害，而 HUD 利用率和源动量遵循既有达标锁存口径；字段解释见 [示例说明](playtests/README.md)。不要用清场累计伤害反算达标时锁存利用率。

最终性能为 Godot 4.7.1 / D3D12 / 1152×648，9,879 弹丸、50,016 波点、100 装置、300 敌人：原生模拟 60 Hz p95 **4.239 ms**，整帧 p95 **8.333 ms**；300 敌人 AI p95 **0.340 ms**。1,000 敌人压力样本无崩溃。该短时代表负载通过 8 ms／2 ms／60 FPS 预算，不代表长时间无尽游玩或任意硬件保证。

## 实际画面

以下为 Godot 4.7.1、D3D12、2560×1440 全屏的实际渲染，不是界面设计图：

- [默认未授权](../artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/project/artifacts/v051-consent-unchecked.png)
- [长按进度](../artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/project/artifacts/v051-hold-progress.png)
- [选择入口](../artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/project/artifacts/v051-selected-entry.png)／[选择出口](../artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/project/artifacts/v051-selected-exit.png)
- [视野外首次伤害提示](../artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/project/artifacts/v051-first-hit-feedback.png)
- [真实可见命中闪烁](../artifacts/qa/v051-hit-delivery-3430f7c446c7412890489f9a0d28657b/project/artifacts/v051-visible-hit-flash.png)：按参考路线移动出口和相机后拍摄，避免首波命中被顶部 HUD 遮住；此补拍在事件后结束，仅作为表现证据，不计作一次通关。
- [清场](../artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/project/artifacts/v051-phase-combat-2-clearing.png)
- [报告入口](../artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/project/artifacts/v051-report-actions.png)／[可选意见](../artifacts/qa/v051-audio-isolated-input-9944e1d1f64846eabef7ffb7df48c1fd/project/artifacts/v051-optional-feedback.png)

本轮 Fennara MCP 工具已暴露，但实际脚本诊断请求超时，因此使用隔离 Godot CLI 替代，没有改动插件或用户正在运行的编辑器。一次输入验证遭遇 WASAPI 输出设备失效，即使玩法断言通过也判为失败；随后测试进程使用 `--audio-driver Dummy` 完整重跑通过。本阶段没有音频内容，该选项仅隔离测试设备状态，不修改项目音频设置。

## 复现与剩余边界

在项目根运行：

```powershell
.\tools\run_validation.ps1 -Suite Fast -Label local-fast
.\tools\run_validation.ps1 -Suite Full -Label local-full
.\tools\run_validation.ps1 -Suite Playthrough -Label local-input
.\tools\run_validation.ps1 -Suite Performance -Label local-performance
```

Playthrough 会启动真实渲染和输入验收，请不要同时操作该测试窗口。日志、截图及报告留在各自 `artifacts/qa/` 隔离目录；失败用例也保留，不用成功重跑覆盖失败证据。

未制作独立发行包。尚需项目作者不参照脚本试玩，再安排陌生玩家；理解偏差和真实教学效果仍待观察，不能由自动化通关代替。恢复测试覆盖有效起始摘要已写入后的中断，不承诺修复任意文件损坏。
