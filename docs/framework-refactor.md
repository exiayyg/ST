# 框架整理交付说明

日期：2026-09-06。基线仍为 `80c90e2`，没有创建提交。本轮比较对象是开始整理前的 v0.4.1 工作树副本，而不是较早的 v0.2 Git 提交。原生模拟、敌人参数和首关目标没有调整；正式目录仍只有第一关。

## 模块与责任

| 模块 | 对外边界 | 隐藏的实现细节 |
| --- | --- | --- |
| `WorldRuntime` | `initialize / advance / handle_command / snapshot / shutdown` | 模拟、装置、照明、敌人代理和会话的帧内协调 |
| `WorldScreen` | 场景生命周期、导航意图、视图刷新 | 相机、HUD、模态层和成绩提交；不实现教学判定 |
| `ConstructionInputController` | `handle_input / advance / cancel / snapshot` | 轮盘长按、拖动、二极管待放置、旋转和拆除按住状态 |
| `ScreenModalCoordinator` | Esc/F2 处理、公开查询和取消接口 | 确认框、调参、建造与暂停的优先级 |
| `BalanceEditSession` | `edit / edit_shots_per_second / apply / save / reload / undo / snapshot` | 工作副本、生效参照、保存参照、校验和派生动量 |
| `BalanceEditAdapter.Runtime / Editor` | 加载、保存和应用 | 运行时场景重置与编辑器保存语义的差别 |
| `BalanceProfile / RuntimeBalance` | 只读生效配置、强类型子配置 | JSON 编译、深层只读容器、已编译路径索引 |
| `SessionSpec / CombatSessionFactory` | 类型及绑定校验、创建导演 | 启动来源、关卡 ID、会话类型、配置键及导演选择 |

`momentum_prototype.gd` 是薄场景适配器；`combat_sandbox.gd` 只声明会话选项。二者通过同一个 `WorldScreen` 组合世界运行模块，战斗不再继承整个建造场脚本。`ConstructionSession` 是无战斗适配器，其余导演继续复用。

世界帧内顺序保持为：

```text
会话推进/生成
  → 敌人行动/代理同步
  → 建造交互/发射
  → 原生模拟
  → 原生事件批次派发
  → 敌人 HP 事件应用/装置同步/照明失效
  → 获取本阶段统计/胜负评估
  → 快照/表现
```

原生事件必须先按原顺序完整派发，再将该批次应用到敌人 HP；这不是可以任意交换的两个循环。统计只能在相同模拟阶段内复用，不能拿上一步统计做本步结算。`WorldRuntime` 不给每个原生方法添加转发包装，批量边界仍在 `SimulationController`。

视图消费 `snapshot()`，不读取场景私有字段。运行模块仍提供命名清晰的领域对象供协调和部分旧测试使用；这不表示视图可以越过快照改世界状态。新模块测试优先验证公开接口，旧截图/特征测试仍保留少量私有访问，尚未声称全部测试已经改写。

## 输入和暂停

Esc 优先关闭确认框，再关闭 F2，再取消临时建造，最后切换暂停/执行已有结算返回。打开任意世界模态统一取消临时操作。确认框在前时不打开 F2；从暂停菜单打开 F2，关闭后仍暂停。

暂停原因继续由 `RuntimePauseState` 管理；菜单层发出重试/返回意图，场景宿主调用路由。调参层不再读取宿主 `_runtime_menu`，搜索焦点通过 `focus_search()` 公开方法设置。退出时释放交互回调、世界事件连接和各自暂停原因；应用重置恢复 SceneTree。

## 配置与关卡绑定

运行时输入编辑只更改 `BalanceEditSession.working`。保存不会应用，撤销运行时工作副本返回最近应用状态；编辑器撤销返回最近加载/保存状态。校验和场景可重载检查成功后，服务编译候选配置并安排重建；错误返回面板，重载失败会保留此前配置。

生效 `BalanceProfile` 的嵌套 Dictionary/Array 全部只读，`duplicate_profile()` 生成可写副本。塔发射和输入使用编译后的强类型字段；尚保留的 `value(path)` 在生效配置上访问预建索引，不逐帧拆路径遍历 JSON。设备行为、敌人定义继续使用既有 Resource，原生接口仍使用批量 Dictionary/PackedArray。

schema v6 串联 v1–v5 的内存迁移，只有保存才写回文件。新增的 HUD 尺寸、教学线长、方向提示长度和面板布局字段保留原默认表现。

特别注意：迁移时 `route_min_north_distance` 从用户旧配置的实际 `marker_radius` 复制。迁移后视觉标记大小和最小北向距离互不影响；测试使用旧半径 77、新视觉半径 12，判定距离仍为 77。

配置链：

```text
LevelDefinition(balance_key)
  → CampaignService 启动上下文
  → SessionSpec
  → CombatSessionFactory：会话类型 + 配置形状校验
  → DiodeTutorialConfig
  → DiodeTutorialSession
```

目录验证与工厂复用会话类型登记。未知类型、缺失配置、错误形状整体拒绝，不回退第一关。开发场景默认键集中在 `SessionSpec.DEFAULT_KEYS`；教学导演不再硬编码首关路径。

新增同类型关卡只需添加 `levels/<稳定配置 ID>`（声明 `session_kind: tutorial_diode`），以及指向该配置的关卡 Resource。工厂和场景不需要加入关卡 ID 分支。新会话类型仍需明确实现并登记，不提供尚未需要的通用任务图。测试专用第二配置把观察时间改为 9 秒，证明相同导演读取不同绑定；它不进入正式目录。

## 数值覆盖检查的边界

`BalanceFieldCatalog` 统一字段类型、范围、说明和控件描述；跨字段约束留在 schema。Godot 测试检查所有配置叶子的描述/面板覆盖和运行配置编译。

`tools/check_balance_coverage.ps1` 对游戏脚本新增数值字面量做保守检查，配合 `config/balance/numeric_literal_allowlist.json` 的 353 条已登记源码行。数学、索引、单位换算、迁移/校验及遗留配置防护有说明；历史视觉/算法常量明确记录为保留债务，不伪装成已经配置化。修改或新增这些行需重新审查。该检查不能理解全部玩法语义，也不覆盖测试夹具、字符串中的数字或 C++ 内存布局；不能替代代码审查。

## 验证命令

在 PowerShell 7 中执行：

```powershell
.\tools\run_validation.ps1 -Suite Fast
.\tools\run_validation.ps1 -Suite Full
.\tools\run_validation.ps1 -Suite Visual
.\tools\run_validation.ps1 -Suite Performance
```

默认 Godot 为 `E:\Godot\godot.exe`；可通过 `-GodotPath` 覆盖。每次复制隔离项目并使用独立 APPDATA，测试间恢复同一默认 JSON。输出 `summary.json`、各进程标准输出/错误日志；Visual 截图在该副本 `project/artifacts/`。每个进程必须退出，超时只结束本次工具创建的进程树。Full 额外执行已构建的 `native/build-debug` CTest。Performance 解析测量值并对 8 ms / 2 ms / 60 FPS 预算给出失败退出码。

实际发现并修正的验收工具问题：旧面板测试在 setup 后直接替换保存服务，抽出 Adapter 后该替换不再有效，曾使隔离 JSON 写入测试值；现在通过 setup 注入假保存服务，并在测试间恢复配置。另补建隔离截图输出目录。两次失败记录保留在 QA 目录，未计为通过。

## 前后结果

完整套件通过：配置、九装置/建造、运行 UX、唯一弹道/拆除/教学、目录/进度/导航、原生生命周期、单波、无尽及 20 波耐久、模块公开接口、真实前端/关卡应用重置、C++ 规则测试。最终报告：`artifacts/qa/handoff-20ac75bd88e9464499c8c9e910fde75b/summary.json`。

另使用键盘输入脚本分别验证主菜单退出和建造场暂停后确认退出：默认取消焦点正确，确认后两个进程均以 0 结束并输出 `V041_EXIT_CONFIRMED`；对应 `exit-main` / `exit-paused` 日志保留在同一报告目录。

确定性对照使用相同引擎、种子和 `1/120 s` 步长，先自由发射 240 步，再放置二极管及蓄积器，运行 4800 步，中途从第二端拆除二极管。原始与重构版各产生 574 个相同顺序事件，包含 186 次传送、181 次蓄积和完整拆除事件。比较仅忽略 Godot Resource 的进程内对象编号，不忽略稳定装置 ID、数值或顺序。最终两者均为 tick 5040、333 个弹丸、1 个装置、蓄积质量约 9.05/动量 2172、当前波塔源动量 3300；照明和会话结果也一致。更复杂的跨波/胜负语义由无尽和教学回归单独覆盖，这段对照本身不等于完整通关测试。

代表性 D3D12 Mobile 管线：1152×648，初始 10,000 弹丸、50,016 波点、100 装置、300 敌人代理；采样时 9,879 弹丸（其余按真实规则被吸收）。

| p95 指标 | 整理前同副本采样 | 整理后采样 | 最终预算检查采样 | 预算 |
| --- | ---: | ---: | ---: | ---: |
| 原生模拟 | 5.866 ms | 5.652 ms | 6.047 ms | ≤ 8 ms |
| 边界传输 | 2.519 ms | 2.501 ms | 2.657 ms | 记录 |
| 渲染上传 | 1.845 ms | 1.876 ms | 2.269 ms | 记录 |
| 绘制 | 0.396 ms | 0.393 ms | 0.448 ms | 记录 |
| 整帧 | 12.395 ms | 11.667 ms | 13.119 ms | ≤ 16.667 ms |
| 300 敌人 AI | 1.400 ms | 0.816 ms | 0.785 ms | ≤ 2 ms |

最终 1000 敌人压力样本无崩溃，AI 最大样本 3.014 ms。短时样本会随编辑器和系统负载波动，不据此宣称确定的性能提升。性能报告：`artifacts/qa/delivery-performance-b5a0df540de640d5827f4aabf18d25dc/summary.json`。

## 运行与视觉验收

本轮 Fennara MCP 可用，未修改插件。Godot 4.7.1 实际 D3D12 全屏 2560×1440 验证了主菜单 → 关卡 → Esc 暂停 → F2 → 关闭 F2 仍暂停 → 继续 → 左键长按轮盘；暂停叠加期间原生 tick 不增长。Fennara 会话 `runtime-265705168` 正常退出、无运行错误。脚本诊断仍有历史警告，不能将其描述为全项目零警告。

菜单、最佳利用率、退出确认和结算的补充 CLI 截图已目检，输出位于 `artifacts/qa/framework-visual-fixed-6102f3824cbc48059d52255a2b1527bb/project/artifacts/v041-*.png`。其中 121%/142% 和成功结算是构造的 UI 夹具，不是实际通关成绩。Fennara 实际输入截图在该会话日志目录；CLI 工具可在无 Fennara 环境重现静态画面。

## 单独保留的问题

首关此前按建议路径静态建路后，约 82 秒以 1.71% 利用率超时；没有证明完成两波或达到 5–8 分钟切片目标。详细记录见 `docs/v041-acceptance.md`。本轮不修改敌人、目标利用率或提示坐标来掩盖这个问题。下一轮应验证教学可达性、持续命中反馈和真人试玩，再考虑第二关。
