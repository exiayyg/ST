# Singular Tower / 一炮千径

当前仓库包含三个开发入口：保留的“完整网络建造实验场”用于九装置、建造、迷雾和性能回归；单波战斗场用于 v0.1 规则回归；默认入口是“DEV 无尽模式骨架 v0.2”，贯通实时准备、逐波战斗、达标清场、实时休整、跨区调度、跨波网络积累和失败重开。`DEV_近战测试体`、`DEV_远程测试体` 仍是开发样本，不是正式敌人或关卡内容。

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
- `scripts/combat`：敌人 AI/HP/表现、远程蓄力射线、确定性无尽波生成、单波/无尽会话导演、方向预警和战斗 HUD。
- `scenes/prototype`：建造回归场；`scenes/combat`：默认战斗骨架场。
- `.agents/skills/singular-tower-development`：冻结玩法、未决边界与 C++/GDScript 分工准则。

项目默认数值的唯一来源是 `config/balance/balance.json`。`DeviceCatalog`、模拟、敌人、波次和 UI 都从同一个 `BalanceProfile` 读取；C++ 默认值只用于非法配置防护。弹丸和非零波点不会因寿命、数量或越界消失，只在动量归零后回收。

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
- 短按空地：取消选择；拖动已有装置：移动；`Q` / `E`：旋转。
- 二极管：先放入口，再放出口；完成后可移动装置并旋转出口方向。
- `R`：释放选中的动量蓄积器；`Space`：切换塔自动发射。
- `Shift+Delete`：开发模式下对选中装置造成 25 HP 伤害；右键或 `Esc`：取消当前建造。
- `F2`：开发构建运行时数值面板；所有输入先进入工作副本，“应用并重置”后统一生效。
- `F3`：战斗性能调试层。正式战斗 HUD 仅显示波次、时间和动量利用率。
- 无尽节奏：20 秒实时准备 → 战斗 → 达标后清除现存敌人 → 15 秒实时休整 → 下一波；装置、照明、蓄积和非零动量实体不会因换波清理。
- 无尽失败后：点击结算面板的“重新开始”，或按 `Enter`，完整重建本局。

Godot 编辑器加载完成后会自动展开底部的“一炮千径数值”面板；关闭后可点击底部同名按钮，或使用“项目 → 工具 → 一炮千径：打开数值编辑器”重新打开。运行主场景时按 `F2` 打开运行时工作副本。两套面板使用同一 JSON、schema 和控件生成器。保存会先写临时文件并回读校验，再替换正式文件；`.tmp` / `.bak` 均忽略版本控制。

## 验证

```powershell
$GodotPath = 'E:\Godot\godot.exe'
& $GodotPath --headless --path $PWD -s (Resolve-Path tools/smoke_momentum_extension.gd).Path
& $GodotPath --headless --path $PWD -s (Resolve-Path tools/test_balance_config.gd).Path
& $GodotPath --headless --path $PWD -s (Resolve-Path tools/test_native_lifecycle.gd).Path
& $GodotPath --headless --path $PWD -s (Resolve-Path tools/test_combat_skeleton.gd).Path
& $GodotPath --headless --path $PWD -s (Resolve-Path tools/test_endless_mode.gd).Path
& $GodotPath --headless --path $PWD -s (Resolve-Path tools/benchmark_enemy_ai.gd).Path
& $GodotPath --headless --path $PWD -s (Resolve-Path tools/test_runtime_ux_regressions.gd).Path
& $GodotPath --headless --path $PWD res://scenes/tests/prototype_logic_test.tscn
& $GodotPath --headless --path $PWD --quit-after 900
```

`tools/format_balance.gd` 用于校验并按稳定字段顺序格式化 JSON。Release GDExtension 的 10k/50k/100/300 端到端管线使用 `scenes/tests/pipeline_benchmark.tscn` 验收；运行前应确保 `.gdextension` 的当前构建特性加载 Release DLL。开发 DLL 使用 `RelWithDebInfo + template_debug`，兼顾 Godot 开发特性、符号和稳定 CRT 边界。CMake 已为注册单元显式登记原生类布局依赖；若切换编译器或更新 godot-cpp，仍建议使用 `cmake --build native/build-debug --clean-first` 完整重建一次。

Release 性能基准与结果记录见 [artifacts/performance-baseline.md](artifacts/performance-baseline.md)。单波视觉回归由 `tools/capture_combat_stage.gd` 生成；无尽准备、跨区预警、清场、休整、多方向压力和失败结算由 `tools/capture_endless_stage.gd` 生成到 `artifacts/`，PNG 默认不纳入版本控制。
