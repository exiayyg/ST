# Singular Tower / 一炮千径

最新操作说明与验收：[统一鼠标操作](docs/mouse-input-acceptance.md)（轮盘松开放置、右键精确旋转、鼠标拆除与暂停；整帧性能稳定性仍待收尾）。

默认入口现为正式前端：玩家可进入“关卡模式”或“无尽模式”；开发构建额外显示首关试玩、单波战斗和九装置建造实验场。关卡目录当前只展示二极管教学切片“第一关：改写路径”，不会用空白卡片暗示尚未制作的内容。教学关使用“教学·破线者”和“教学·压制者”验证正式近战/远程机制，但名称和数值仍属于可替换的教学配置。

## v0.6 抽象能量视听

塔、九装置、两类现有敌人、弹丸／波点与轮盘采用统一的能量轮廓；菜单、暂停、结算和 F2 共享样式。主菜单和暂停菜单新增 **视听设置**：总音量、音效音量、静音、减少动态效果，可立即调整且不重置世界。

14 个原创短合成音效已随项目保存。个人选择仅写入 `user://presentation_settings.json`，不改动 balance、成绩或试玩配置哈希。世界音效只响应可见事件；音色与舒适度仍需实际试听，不把自动播放测试当作真人验收。

详见 [v0.6 验收与前后画面](docs/v06-acceptance.md)、[音效清单](assets/audio/README.md) 与 [视听观察表](docs/presentation-observation.md)。

## 本机试玩

在 Godot 4.7.1 中按 F5，选择开发区域的 **首关试玩**。成功、失败、重试和退出均不会修改正式成绩。记录默认关闭；可在开始前勾选“同意记录本次试玩”，仅向本机 `user://playtests/<run_id>/` 写入语义事件及聚合战况，不联网、不录屏、不记录原始按键或逐弹丸轨迹。

重试保留本次授权并创建新记录；返回主菜单后授权结束。F2 成功应用会结束旧记录并用新配置哈希开始新局；无效修改不会中断当前记录。结算后可打开报告目录或填写可跳过的意见。运行异常中断后，下一次启动标记已授权的未完成报告，同时保留原始日志。

试玩前请先阅读不含通关路线的 [观察表](docs/playtest-observation.md)。真人理解效果和通关时长仍待验证，不以自动化结果代替。实现与验证见 [v0.5.1 交付说明](docs/v051-acceptance.md)。

## 运行环境

- Godot 4.7.x（本机 `GODOT_PATH` 为 `E:\Godot\godot.exe`，当前版本 4.7.1）
- CMake、Ninja、MSVC 2022 Build Tools
- `native/third_party/godot-cpp` 子模块，API 目标为 Godot 4.7
- Fennara Godot AI 位于 `addons/fennara`
- mattpocock/skills 及项目准则位于 `.agents/skills`
- 默认以原生全屏启动；逻辑视口基准为 1920×1080，并随显示器比例扩展。

## 架构边界

- `native/src/core`：1/120 秒确定性固定步进、紧凑弹丸/波点存储、扫掠碰撞、装置与敌人动态空间哈希、九种装置高频规则与批量事件。
- `native/src/godot`：窄 GDExtension 适配层，负责批量命令、原子敌人代理同步、可见区域 MultiMesh 缓冲、事件传输，以及超过迁移门槛的迷雾覆盖栅格计算。
- `scripts/prototype`：强类型装置 Resource、模拟协调、建造、相机、迷雾失效/贴图、批量渲染和 HUD。HP、选择与流程留在 GDScript。
- `scripts/config`：`BalanceProfile`、显式 schema、事务 JSON 仓库，以及编辑器/运行时共用的数值控件生成器。
- `scripts/combat`：敌人 AI/HP/表现、远程蓄力射线、确定性无尽波生成、单波/无尽/教学会话导演、方向预警和战斗 HUD。
- `scripts/runtime`：组合式世界运行、薄场景宿主、建造输入状态机和屏幕模态协调。
- `scripts/campaign`：强类型关卡目录、顺序解锁、本地进度仓库、启动上下文与场景路由；关卡元数据与数值配置保持分离。
- `scripts/frontend`：正式模式入口和关卡选择；`scenes/levels`、`scenes/combat` 与 `scenes/prototype` 仍可从编辑器直接运行回归场景。
- `.agents/skills/singular-tower-development`：冻结玩法、未决边界与 C++/GDScript 分工准则。

项目默认数值的唯一来源是 schema v9 的 `config/balance/balance.json`。`DeviceCatalog`、模拟、敌人、波次、教学关、前端、暂停及视听模块都从同一个 `BalanceProfile` 读取；生效配置编译后只读，面板使用独立工作副本。C++ 默认值只用于非法配置防护。弹丸和非零波点不会因寿命、数量或越界消失，只在动量归零后回收。

中心塔发射的所有初始弹丸从同一炮口、沿世界右方向完全重合前进，不存在横向轨道、角度随机或自由飞行熵漂移。弹丸接触装置后恢复常规装置与熵规则；转换器和蓄积器重构的弹丸从各自装置出口发射。

熵在 `start_entropy`（默认 50）及以下只积累和预警，机械不确定性严格为 0；随后按单调 Curve 增长，并在 `full_effect_entropy` 饱和。熵只影响不确定性，不直接修改伤害、攻速、移动速度或硬控制。

## 构建

在已加载 MSVC x64 环境的 PowerShell 中执行：

```powershell
git submodule update --init --recursive
cmake -S native -B native/build-debug -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DGODOTCPP_TARGET=template_debug -DGODOTCPP_API_VERSION=4.7 -DBUILD_TESTING=ON
cmake --build native/build-debug --parallel
ctest --test-dir native/build-debug --output-on-failure
```

若当前终端没有 MSVC 环境，先运行：

```powershell
& cmd.exe /d /s /c 'call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 && cmake --build native\build-debug --parallel'
```

启动项目：

```powershell
& $env:GODOT_PATH --path . --editor
```

## 实验场操作

- `WASD` 或中键拖动：平移；滚轮：0.5–1.5 缩放。
- 在亮区空地长按左键 0.35 秒：打开九分区径向菜单；拖到分区并松开以放置。
- 短按空地取消选择；短按装置选择；按住装置并拖动即可移动，无须等待。
- 右键拖拽装置或端点：预览朝向，松开提交；左键或 Esc 取消预览。真实装置在提交前保持原方向，不使用固定角度步进。
- 二极管：轮盘松开一次生成整对端点，默认出口在入口右侧 96 像素；两端均需亮区合法，建成后可分别移动和旋转。
- 短按蓄积器立即释放全部存量；长按、移动或旋转不会触发释放。
- 选中后按住“拆除”按钮（可选 Delete）：达到配置时长后拆除；提前松开、切换选择或打开模态界面取消。二极管整对拆除，所有存量永久丢失、不返还弹丸。
- 右上角提供自动发射开关及暂停按钮；暂停菜单可进入操作说明、视听设置及开发数值编辑。R、Space、WASD、Esc 仅为可选快捷方式。
- `Shift+Delete`：开发模式下对选中装置造成 25 HP 伤害；右键或 `Esc`：取消当前建造。
- `F2`：开发构建运行时数值面板，打开时自动暂停；关闭恢复先前状态（从暂停菜单打开则仍保持暂停）。修改只进入工作副本，“应用并重置”后统一生效。
- `F3`：战斗性能调试层。正式战斗 HUD 仅显示波次、时间和动量利用率。
- `Esc`：优先关闭 F2 或取消轮盘、旋转预览、拖动和拆除；没有待取消操作时打开暂停菜单。暂停冻结模拟、敌人、塔发射和计时。进行中的重试、返回和退出会先确认“当前局面不会保存”，默认聚焦取消；结算后返回/重试无需确认。
- 无尽节奏：20 秒实时准备 → 战斗 → 达标后清除现存敌人 → 15 秒实时休整 → 下一波；装置、照明、蓄积和非零动量实体不会因换波清理。
- 关卡成功结算默认返回关卡选择，也可重新挑战；失败结算默认重试，也可返回关卡选择。无尽模式不写入关卡进度，返回主菜单。

二极管教学首关依次引导观察唯一弹道、自由放置练习、拆除同一组端点、把真实弹丸重定向到北侧，以及两波防守。教学只给出世界建议位置和方向，不锁死建造坐标，也不限制径向菜单中的其他装置。

Godot 编辑器加载完成后会自动展开底部的“一炮千径数值”面板；关闭后可点击底部同名按钮，或使用“项目 → 工具 → 一炮千径：打开数值编辑器”重新打开。运行主场景时按 `F2` 打开运行时工作副本。两套面板使用同一 JSON、schema 和控件生成器。保存会先写临时文件并回读校验，再替换正式文件；`.tmp` / `.bak` 均忽略版本控制。

本地关卡进度保存在 `user://campaign_progress.json`，首版只记录完成状态和最佳动量利用率；最佳值允许超过 100%，失败尝试也可刷新最佳值，但不会完成关卡或解锁后续关卡。写入采用临时文件回读验证和原子替换；正式文件缺失时恢复有效 `.bak`；损坏文件独立保留为 `.corrupt.*`，不覆盖有效备份；无有效数据时提示并以空白内存进度启动。结算保存失败时显示“成绩未保存 · 重试保存”，重试仍提交原始结算且保持幂等。关卡顺序解锁不会锁定九种装置。

## 验证

推荐使用统一入口。每次创建隔离项目和应用数据目录，等待每个进程结束并检查退出码、超时、错误日志；性能套件还检查 p95 预算。不会写入真实关卡进度，也不向正在运行的编辑器导入测试副本：

```powershell
.\tools\run_validation.ps1 -Suite Fast
.\tools\run_validation.ps1 -Suite Full
.\tools\run_validation.ps1 -Suite Visual
.\tools\run_validation.ps1 -Suite Performance
.\tools\run_validation.ps1 -Suite Playthrough -TimeoutSeconds 300
```

可用 `-GodotPath 'E:\Godot\godot.exe'` 指定引擎，`-TimeoutSeconds 300` 设置单进程超时；报告和截图在 `artifacts/qa/<label-id>/`。Full 要求已经构建 `native/build-debug`。下面是历史单项命令，仅在隔离项目中使用：

```powershell
$GodotPath = 'E:\Godot\godot.exe'
$ProjectPath = $PWD.Path
$QaOut = Join-Path $env:TEMP 'singular-tower-qa-out.log'
$QaErr = Join-Path $env:TEMP 'singular-tower-qa-err.log'
function Invoke-GodotQa([string[]] $GodotArgs) {
    $process = Start-Process -FilePath $GodotPath -ArgumentList $GodotArgs -Wait -PassThru `
        -WindowStyle Hidden -RedirectStandardOutput $QaOut -RedirectStandardError $QaErr
    Get-Content $QaOut -ErrorAction SilentlyContinue
    Get-Content $QaErr -ErrorAction SilentlyContinue
    if ($process.ExitCode -ne 0) { throw "Godot QA failed: $($process.ExitCode)" }
}
Invoke-GodotQa @('--headless', '--path', $ProjectPath, '-s', (Resolve-Path tools/smoke_momentum_extension.gd).Path)
Invoke-GodotQa @('--headless', '--path', $ProjectPath, 'res://scenes/tests/balance_config_test.tscn')
Invoke-GodotQa @('--headless', '--path', $ProjectPath, 'res://scenes/tests/native_lifecycle_test.tscn')
Invoke-GodotQa @('--headless', '--path', $ProjectPath, '-s', (Resolve-Path tools/test_combat_skeleton.gd).Path)
Invoke-GodotQa @('--headless', '--path', $ProjectPath, '-s', (Resolve-Path tools/test_endless_mode.gd).Path)
Invoke-GodotQa @('--headless', '--path', $ProjectPath, 'res://scenes/tests/runtime_ux_regressions_test.tscn')
Invoke-GodotQa @('--headless', '--path', $ProjectPath, 'res://scenes/tests/v03_tutorial_test.tscn')
Invoke-GodotQa @('--headless', '--path', $ProjectPath, 'res://scenes/tests/campaign_framework_test.tscn')
Invoke-GodotQa @('--headless', '--path', $ProjectPath, 'res://scenes/tests/frontend_navigation_test.tscn')
Invoke-GodotQa @('--headless', '--path', $ProjectPath, 'res://scenes/tests/prototype_logic_test.tscn')
Invoke-GodotQa @('--headless', '--path', $ProjectPath, '--quit-after', '900')
```

`tools/format_balance.gd` 用于校验并按稳定字段顺序格式化 JSON。Release GDExtension 的 10k/50k/100/300 端到端管线使用 `scenes/tests/pipeline_benchmark.tscn` 验收；运行前应确保 `.gdextension` 的当前构建特性加载 Release DLL。开发 DLL 使用 `RelWithDebInfo + template_debug`，兼顾 Godot 开发特性、符号和稳定 CRT 边界。CMake 已为注册单元显式登记原生类布局依赖；若切换编译器或更新 godot-cpp，仍建议使用 `cmake --build native/build-debug --clean-first` 完整重建一次。

Release 性能基准与结果记录见 [artifacts/performance-baseline.md](artifacts/performance-baseline.md)。单波视觉回归由 `tools/capture_combat_stage.gd` 生成；无尽准备、跨区预警、清场、休整、多方向压力和失败结算由 `tools/capture_endless_stage.gd` 生成。v0.3 教学验收由 `tools/capture_diode_tutorial_stage.gd` 生成；v0.4 的正式主菜单、未完成/已完成关卡卡片、暂停和双操作结算由 `tools/capture_frontend_stage.gd` 生成到 `artifacts/frontend-*.png`。v0.4.1 同一截图工具现在输出 `artifacts/v041-*.png`，包括常用调参、操作说明、退出确认及成绩重试。PNG 默认不纳入版本控制。

2026-09-05 的 v0.4 验收环境未向当前任务暴露 Fennara MCP，因此使用本机 Godot 4.7.1、D3D12 和隔离项目副本完成等价运行验证与全屏截图；没有修改 Fennara 插件。代表管线为约 10,000 弹丸、50,016 波点、100 装置和 300 敌人；1152×648 实测原生模拟 p95 `3.895 ms`、完整帧 p95 `8.333 ms`，2560×1440 全屏补充测试的完整帧 p95 为 `14.069 ms`。

## v0.4.1 调参与操作修整

数值面板首屏置顶“常用参数”：弹丸初速度、每秒发射数、质量、塔 HP、照明和熵阈值/饱和值。射速是 `tower/fire_interval` 的倒数视图，不增加第二份 JSON 字段；只读展示间隔、单发动量和每秒源动量。常用区与完整分类实时双向同步，宽面板双列、窄面板单列；模拟/诊断/迷雾默认折叠，搜索结束恢复折叠状态。

“保存 JSON”不改变当前运行世界；“撤销未应用”在运行时回到最近应用状态，在编辑器回到最近加载/保存状态。已移除容易误解的“恢复默认”。主菜单新增操作说明与退出游戏，建造实验场也复用统一暂停/返回/退出流程。结算使用真实可聚焦按钮，支持 Tab、方向键和 Enter。

详细验收、首关试玩结果与下一步建议见 [v0.4.1 验收记录](docs/v041-acceptance.md)。本轮没有修改高频 C++，没有创建新 Git 提交。

## 框架整理与 schema v6

建造与战斗场景现在组合使用 `WorldRuntime`，不再让战斗继承建造实验场实现。建造输入、屏幕模态、配置编辑工作副本和关卡启动规格分别由独立模块管理。后续同类关卡通过 `balance_key` 绑定配置，不需要修改场景私有状态或教学导演中的首关路径。

接口、配置迁移、扩展方式与前后验证结果见 [框架整理交付说明](docs/framework-refactor.md)。本轮保留冻结玩法、首关平衡和原生模拟，未创建新 Git 提交。

## v0.5 首关可玩性与 schema v7

首关使用可配置边缘区段生成，二极管入口/出口均可被敌人攻击且共用 HP。教学反馈基于真实传送、实际伤害、路由丢失和玩家可见敌人；停火、暂停和结算不会误报网络失效。出生区段与反馈时间可在编辑器/F2 的关卡分类调整；旧配置迁移只补整条边缘，不覆盖用户数值。

保持塔 1 发/秒、0.05 质量、240 初速度、1000 HP，九装置、敌人和无尽数值不变。已用真实键鼠输入验证一套全程自动发射的二极管通关方案：第一波不调整、第二波一次拖动出口，两波完成并保存成绩。`Playthrough` 套件同时运行固定参考和故意偏置/纠正的反馈探针；不以合成伤害或导演状态跳转证明可玩性。

范围、基线失败轨迹、参考操作、可达性报告、截图和真人试玩限制见 [v0.5 验收记录](docs/v05-acceptance.md)。本轮 Fennara 已连接但项目诊断超时，使用 Godot 4.7.1 隔离 CLI 完成验证；没有修改插件或创建提交。
