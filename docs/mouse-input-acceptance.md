# 统一鼠标操作：实现与验收

2026-09-09。保持工作树，不创建提交；基线仍是 `80c90e2`。本轮对照的是实施前 schema v9 工作树副本，而不是早期 Git 版本。

## 当前操作

| 目的 | 鼠标操作 | 提交与取消 |
| --- | --- | --- |
| 放置九装置 | 亮区空地长按左键，滑到轮盘分区，松开 | 在最初按下的位置创建；右键取消 |
| 放置二极管 | 与其他装置完全相同 | 一次创建整对，出口默认向右 96 世界像素；任一端点非法则整次拒绝，不消耗 ID |
| 选择 | 短按装置或端点 | 选中当前端点 |
| 蓄积释放 | 短按蓄积器 | 有效短按才释放一次；长按、拖动、取消、旋转均不会误释放 |
| 移动 | 按住装置并拖动，超过 4 屏幕逻辑像素立即开始 | 闭合抓手表示正在拖动；保留抓取偏移，取消不回滚已发生的移动，无移动计时环 |
| 精确旋转 | 直接对装置/端点右键拖拽 | 虚影跟随鼠标，松开提交；左键或 Esc 取消。真实装置在预览期间不变 |
| 拆除 | 选中后按住左下角“按住拆除” | 沿用现有拆除时长；离开按钮、松开或模态开启即取消 |
| 发射/暂停 | 右上角按钮 | 暂停菜单提供继续、重试、返回、视听设置、操作说明、开发数值编辑和退出 |
| 相机 | 中键拖动、滚轮缩放 | 世界手势互斥，旋转时不能同时移动相机 |

没有角度吸附、步进或平滑。反弹板显示板面，以法线指向鼠标；二极管仅修改操作中的端点。中心死区默认 12 屏幕逻辑像素，保留最后有效角度。短按容差默认 4 屏幕逻辑像素。键盘仍可用于可选动作，Q/E 步进旋转已经移除。

轮盘保持原建造坐标和边缘适配，中心改为透明，避免遮住入口预览。选中上下文、旋转角度与暂停面板的重叠已修整。数值面板有鼠标关闭按钮，关闭后恢复原先暂停状态。

## 代码边界

- 输入仍由每个世界的 `ConstructionInputController` 管理，不是全局单例。空闲、左键判定、轮盘、移动、旋转、拆除、相机拖动互斥；公开入口为 `handle_input / advance / cancel / snapshot`。
- `WorldScreen` 负责 GUI 与世界事件路由，活动鼠标手势捕获后续移动/释放，防止释放落在 UI 上导致残留操作。模态协调器负责取消和暂停原因。
- `WorldMouseControls` 只消费快照、发出意图；旋转虚影也仅存在于交互快照。绝对角度经 `ConstructionController.set_anchor_rotation()` 一次提交。旋转不触发圆形照明重建。
- 试玩记录按真实手势统计：一次实际移动、一次旋转提交各计一次；取消预览不计旋转，不记录鼠标轨迹。
- 当前 schema v11：v10 的 `move_hold_seconds` 原值迁移为 `click_max_seconds`，仅用于蓄积器短按防误释放；旧配置只在保存后写回。所有字段仍经过同一字段目录、强类型运行配置、编辑器和 F2。
- 与实施前配置逐分类对比，仅 `construction_ux`、`playtest`、`schema_version` 变化；塔、九装置、敌人、关卡和熵参数保持不变。原生 C++ 无改动。开发准则已同步以上鼠标约定。

## 功能验证

PowerShell 7：

```powershell
.\tools\run_validation.ps1 -Suite Full -Label mouse-full
.\tools\run_validation.ps1 -Suite Playthrough -Label mouse-route
.\tools\run_validation.ps1 -Suite Performance -Label mouse-performance
```

测试使用隔离项目、配置与 APPDATA，等待进程结束并检查退出码和错误日志。

- 改动前快速基线 18/18；最终完整回归 21/21，包含 C++ 规则、九装置、配置、熵、拆除、重叠照明、教学、导航、进度、试玩生命周期、单波、无尽及 20 波耐久。
- 新增 `tools/test_mouse_interactions.gd`：九装置轮盘释放、二极管原子创建及 ID、非整数角度、原生预览隔离、取消吞掉后续释放、移动缓冲、真实蓄积存量只释放一次、目标删除、缩放上下限、板面法线换算、失焦/模态取消、v9→v10 非破坏迁移。
- 实际 Godot 输入路线 5/5：授权界面、普通首关、记录试玩、偏置出口反馈。普通首关从主菜单通过鼠标练习/建路/旋转/拆除进入两波、成功结算、保存并返回；没有改角度、HP、账本或导演状态来代替输入。
- 参考通关利用率 18.5294%，全程自动发射；第一波首次命中后约 11.68 秒不改网络；第二波仅一次拖动。偏置出口路线两次拖动，相隔约 8.30 秒。授权试玩记录为放置 2 次、拆除 1 次、移动 3 次、旋转 1 次；不写正式成绩。
- 曾发现自动化对嵌入式授权窗口使用了错误坐标系；已修正为根窗口坐标路由并重跑通过，没有绕过授权或直接修改复选框状态。

报告目录：

- `artifacts/qa/mouse-final-full-98748a89b1c84db9854b0051cca0b5a9/summary.json`
- `artifacts/qa/mouse-final-route-06d2a80d67e546edace6be7c34092a37/summary.json`
- 最后文字/按钮修整后的专项复测日志：`artifacts/mouse-interactions/mouse_final.*.log` 和 `recorded_mouse_final.*.log`。

## 实际画面与操作演示

Fennara 可用，实际 Godot 4.7.1 / D3D12 Forward+ 检查 1280×720、1920×1080 和全屏。最后会话 `runtime-80214762` 的操作探针无运行错误；项目仍有历史静态警告，未声称全项目零警告。测试会话已关闭，未修改 Fennara 插件。

可复用演示脚本 `tools/capture_mouse_interactions.gd`：先通过 Fennara 启动建造实验场，再用 `runtime_script` 执行该脚本。它通过实际鼠标输入放置、预览并提交 −37.25°、切换窗口尺寸、暂停、打开/关闭数值编辑并继续；不修改 HP 或模拟状态。

- [成对放置预览](../artifacts/mouse-interactions/pair-preview.png)
- [1280×720 精确旋转](../artifacts/mouse-interactions/rotation-1280.png)
- [1920×1080 精确旋转](../artifacts/mouse-interactions/rotation-1920.png)
- [全屏旋转](../artifacts/mouse-interactions/rotation-fullscreen.png)
- [鼠标暂停菜单](../artifacts/mouse-interactions/pause.png)
- [数值面板鼠标关闭](../artifacts/mouse-interactions/tuning.png)

## 性能：尚不能标记稳定达标

代表负载保持初始 10,000 弹丸、50,016 波点、100 装置、300 敌人代理，实际渲染 1152×648；正常吸收后采样为 9,879 弹丸。D3D12 Mobile，表现开启。

首次验收：原生模拟 p95 **7.055 ms**（通过 8 ms 预算），300 敌人 AI p95 **1.291 ms**（通过 2 ms 预算）；1000 敌人压力测试无崩溃。整帧 p95 **17.735 ms**，超过 16.667 ms，性能套件因此正确返回失败。

同机、相同负载、交替运行三次：

| 整帧 p95 | 第 1 次 | 第 2 次 | 第 3 次 |
| --- | ---: | ---: | ---: |
| 改动前 schema v9 副本 | 16.948 ms | 18.115 ms | 17.090 ms |
| 改动后 schema v10 副本 | 18.632 ms | 18.768 ms | 16.982 ms |

随后正常模式一次为 16.155 ms；禁用表现事件处理的诊断样本为 15.857 ms，移除弹丸装饰材质反而为 20.093 ms。样本短且有波动，不能据此断言单一根因，也不能只挑一次通过结果宣称稳定 60 FPS。原有表现事件处理开销值得后续单独剖析；本轮没有通过关闭表现、减少真实实体或修改原生算法掩盖问题。

原始日志保留在 `artifacts/mouse-interactions/perf-*.log`、`probe-*.log`，首次性能报告在 `artifacts/qa/mouse-performance-e1f4bfab23a243129c5a47dbf9d781a7/summary.json`。**操作功能已实现并通过验证；稳定整帧预算仍是未关闭的验收项。**

## 请你实际确认

1. 连续右键拖拽二极管出口，确认角度随鼠标且松开才固定；左键取消是否符合直觉。
2. 试试 4 逻辑像素的拖动容差是否容易误触；可在数值面板调整。
3. 蓄积器短按释放与按住拖动是否容易区分；停留达到短按时限后松开不会释放。

自动化输入不替代你的手感评价，也不替代陌生玩家试玩。

### 历史：0.5 秒长按反馈修整（已被位移拖拽替代）

按最新试玩反馈，项目拖拽阈值由 0.2 秒调为 0.5 秒。进度条围绕装置外圈，二极管只围绕按住的端点；满圈表示可以移动，移动开始、松开或取消后清除。空地轮盘及拆除计时未改。复用现有描边、选中外距和配色参数，C++ 与冻结玩法不变。

快速回归 19/19 通过：`artifacts/qa/hold-half-second-44e5bfc3537e4e3aa47c205fde996b1f/summary.json`。新增半程进度、阈值前不得移动、端点圆心及开始移动后清除进度测试。Fennara 实际输入验证 0.2 秒时 40%、等待满圈、移动及松开清除；截图通过暂停精确保留观察状态，未改交互规则。

[拖拽进度环截图](../artifacts/mouse-interactions/drag-hold-half-second.png)

### 位移拖拽修整（schema v11）

装置移动在越过屏幕逻辑位移容差的 MouseMotion 当次生效，保持原抓取偏移，不等待、不平滑追赶。移动开始后回到起点也不转为点击。当前 `click_max_seconds = 0.5` 只负责蓄积器短按判断；长按不动仍不释放。空地轮盘和拆除计时保持原样。

Windows 的 Godot 默认 CURSOR_DRAG 实际是移动箭头，因此注册项目自己的 `assets/ui/closed_grab.svg`，退出世界后清理。[Godot 官方说明](https://docs.godotengine.org/en/stable/classes/class_input.html)。交互快照提供光标形状，屏幕负责应用；设备移动计时环已移除，选择轮廓保留。

与前次 0.5 秒版本配置逐分类对比，仅 `construction_ux`（字段重命名，值未变）及 `schema_version` 改动，塔、九装置、敌人、关卡和熵参数未变，C++ 未改。开发准则同步更新为位移识别，容差与短按时限仍是可调参数。

验证入口：

```powershell
.\tools\run_validation.ps1 -Suite Full -Label drag-distance-full
.\tools\run_validation.ps1 -Suite Interaction -Label drag-visual
.\tools\run_validation.ps1 -Suite Playthrough -Label drag-distance-route
```

- 完整回归 **21/21**：`artifacts/qa/drag-distance-full-6a907f398fa04d4bb63f60a5d58657c4/summary.json`。包含原生规则、九装置、配置旧版迁移、教学、无尽耐久、照明、拆除、暂停、进度与试玩生命周期。新增快速拖动、容差边界、初始抓取偏移、往返不释放、长按不释放、模态与失焦取消、缩放及 v10 自定义时限迁移测试。
- 真实运行 **2/2**：`artifacts/qa/drag-visual-9dd2f77a11ab4593880090f3d18a079b/summary.json`。Godot 4.7.1、D3D12、RTX 5060，实际 Viewport 鼠标输入覆盖 1280×720、1920×1080、2560×1440 全屏；在不推进下一帧时即验证位置改变。输入后系统查询返回拖拽形状 6，松开与失焦后恢复箭头。
- 首关输入套件 **5/5**：`artifacts/qa/drag-distance-route-363453bd67a942e4877bf18ef8c89d27/summary.json`。普通通关、授权记录通关、偏置出口反馈路线及试玩 UI 全部通过。普通路线两波通关约 90.2 秒，第二波利用率约 18.53%，第一波连续不调整网络的有效伤害窗口约 11.69 秒；保持全程自动发射，未改 HP、账本、导演状态或原操作负担门槛。拖拽驱动已移除旧的强制等待。
- 截图位于该运行目录的 `project/artifacts/drag-distance/`：`moving-1280.png`、`moving-1920.png`、`moving-0.png`、`paused.png` 和光标资源 `closed-grab.png`。已目检三种尺寸下端点标签、选择轮廓、移除后的计时环及上下文文案。Viewport 截图不包含硬件光标；光标资源另行目检，切换由运行状态验证。
- Fennara 状态查询连接成功，但项目诊断和运行启动均返回等待 Godot 插件结果超时；本轮运行验收采用隔离 CLI，导入与测试检查退出码、超时和错误日志。未修改 Fennara 插件或用户正在运行的游戏。
- 首次检查发现并修正了字段目录版本范围漏更新；新测试中的浮点精确比较和移动后仍使用旧坐标也已修正。报告保留失败运行，不以它们宣称通过。
- 本轮未重测高密度性能，不将功能通过解释为新的 60 FPS 承诺。真人手感仍待确认。
- 开发准则仅更新操作参考页；独立 skill YAML 验证器因环境缺少 PyYAML 未能运行，主技能 frontmatter 未改，参考链接与约定已人工核对。

### 装置操作收尾（2026-09-14，仍为 schema v11）

正常拖拽松开时现在采用释放事件的最终坐标，保留抓取偏移和地图限制；取消或删除后忽略迟到释放。本轮未调整 4 像素容差、0.5 秒短按时限或任何玩法配置。真实 Viewport 测试扩展至九装置、蓄积器防误释放、端点旋转、HUD 收尾及打断恢复；详见[验收报告与真人观察表](gesture-boundary-acceptance.md)。
