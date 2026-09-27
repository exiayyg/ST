# v0.6 抽象能量视觉与基础音效

## 运行与边界

用 Godot 4.7.1 打开项目，F5 运行主菜单。通过「首关试玩」体验完整首关，或进入原建造／无尽实验场。主菜单和暂停菜单的「视听设置」支持即时音量、静音和减少动态效果，不重置世界、不影响记录授权或试玩配置哈希。

本轮保留 C++、塔／九装置／敌人／波次／首关数值和冻结规则。与本轮前的配置相比，排除 schema 版本及新增 `presentation`、`audio` 后完全一致。没有修改 Fennara 插件，没有新增第二关、音乐、语音或发行包，没有创建 Git 提交；HEAD 仍为 `80c90e2`。

自动化验证不等于听感认可。作者实际试听、音量舒适度及陌生玩家教学验证仍待完成，使用 [观察表](presentation-observation.md) 记录。

## 实现

- `PresentationDirector` 通过 `configure / ingest_event / advance / reset` 管理有限生命周期效果、可见性、声音冷却、优先级和播放器池。表现通知独立于原有玩法事件，塔发射与敌人攻击从真实行为处发出；不消费模拟随机流。
- 先按对象／事件类型合并，再在帧末查询可见性。装饰脉冲默认上限为 8；溢出只限制表现，不回收非零动量实体。音频候选独立于装饰槽位，摧毁／预警／结算优先于密集命中。
- 世界音效暂停／恢复与世界状态同步，UI 声音不随世界暂停。个人减少动态效果停止装饰时钟和强脉冲，保留形状、方向、HP、激活及操作标识。
- `EnergyGlyphs` 是世界与轮盘共用的矢量轮廓；普通弹丸和波点仍使用已有 MultiMesh，仅增加局部形状 Shader。场纹、传送、命中和破坏效果在迷雾遮罩下绘制，不引入全屏后处理、镜头震动或自动镜头移动。
- 主菜单、关卡卡片、暂停、授权、结算与 F2 使用共享 Theme。设置窗口有显式 Esc 关闭；设置模态阻止 F2 穿透，从暂停进入设置后关闭仍保持暂停。教学短句紧凑换行，选中端点与重叠建议文字不重复显示。
- schema v9 串联历史迁移，共享字段描述驱动编辑器与 F2；现有颜色和反馈配置继续复用。合成参数改变仅在统一重置时重建音库，不在每次命中时合成。
- [14 个原创短音效](../assets/audio/README.md) 以 WAV 资源保存；个人偏好写入 `user://presentation_settings.json`，与 balance 工作副本及正式成绩分离。设备无可用输出或偏好保存失败时单独提示，不阻断游戏流程。

## 验证记录

所有套件使用隔离项目和 APPDATA，等待进程结束、检查退出码、超时及日志。失败的中间尝试保留在 `artifacts/qa/`，没有用成功日志覆盖失败证据。

| 验证 | 结果 | 证据目录 |
|---|---|---|
| 修改前 Fast | 17/17 | `v06-before-479fa3add27f4ba2aac48c8a31defcc5` |
| 完整回归 | 20/20 | `v06-release-full-a9bebc8a3080493db40df863c85c3df2` |
| 最终真实输入：授权、首关、录制、偏置出口 | 5/5 | `v06-delivery-route-eb31b6334470414e80e3df8fa40c9d67` |
| 全屏及 1280×720／1920×1080 视听设置、F2、轮盘 | 4/4 | `v06-release-visual-4b4e29b8796a475ca2aeb350d89d1957` |
| 真实音频设备、离线烘焙、优先级、暂停 | 4/4 | `v06-final-audio-2981254ffcc84b1d90b9a2083268ff4a` |
| 代表性能与 AI | 3/3 | `v06-verified-performance-0de70b0e599544a08e22e31e09c91dcd` |

以上目录均位于项目 `artifacts/qa/`，各有 `summary.json`。完整回归包含 C++ 九装置／熵规则、配置迁移、建造／拆除／照明、暂停、导航、进度、单波、无尽及 20 波耐久，以及试玩授权／写入失败／进程异常恢复。新增测试比较视听接入前后的固定输入事件顺序、账本、实体快照与会话结果，并验证 500 次同敌人事件只执行一次帧末可见性查询。

真实输入参考路线约 91 秒，首波有效运行窗口约 11.68 秒，第二波一次拖动；偏置出口路线约 99 秒、两次调整，均保持自动发射，实际达成两波和 18.53% 利用率。没有修改 HP／账本、停火脚本或合成胜利。

音频专项使用 Godot 4.7.1 / D3D12 和实际 Default 输出设备，枚举到 Realtek 扬声器、NVIDIA 显示器输出和 iKF 耳机；实际开始播放、暂停及高优先级抢占通过，日志无设备错误。PCM 样本有界、首尾静音，混音采用最坏并发增益上界。其他套件的 Dummy 音频不计入听觉验收；没有把软件播放成功解释为人耳已听到或音色舒适。

## 性能与测量口径

代表场景生成 10,000 弹丸、50,016 波点、100 装置、300 敌人代理。末帧仍存活 9,879 弹丸、50,016 波点，快照可见 7,989 弹丸及全部 50,016 波点；减少的弹丸来自真实碰撞后的零动量回收。

最终 1152×648、D3D12 Mobile、实际物理窗口和渲染纹理均为 1152×648：模拟 60 Hz p95 **4.216 ms**，边界 **1.593 ms**，上传（含事件消费与表现）**2.725 ms**，整帧墙钟 p95 **10.425 ms**；300 敌人 AI p95 **0.341 ms**，1,000 敌人压力样本最大 **1.097 ms**，无崩溃。

本轮曾实测整帧 22–26 ms，性能门槛明确判失败。单因素对照排除弹体 Shader 为主要原因，关闭脉冲绘制明显减小成本。随后先合并表现事件、缓存音效描述、只在暂停状态变化时更新播放器，并将纯装饰脉冲限制为 8、取消高密度瞬态圆环的抗锯齿；实体／碰撞／原生算法没有变化。原生时间也随本机负载变化，因此不能把全部前后差值归因于这些修改。

基准另发现 CLI 窗口参数在本次启动未覆盖项目全屏设置。现在显式设置测试窗口、渲染逻辑尺寸及关闭测试垂直同步，等待渲染稳定并输出实际纹理尺寸；整帧改用墙钟间隔，不依赖经过引擎平滑的 delta。先静态预热 60 个渲染帧，不推进／清除代表实体，然后测原有 30 个固定输入样本。此口径与旧文档的短时结果不能直接视为严格同口径性能提升，也不覆盖冷启动、任意机器或长时间无尽负载。

基准 `--presentation-probe=no-presentation / plain-particles / no-effects` 仅用于单因素诊断；正式 Performance 套件始终使用全部表现开启的 normal 模式。失败和对照日志保留在 `v06-performance-d76c802f95f144cd828f82207a46c9c7`，包括关闭 Shader、关闭事件处理、关闭脉冲、修正尺寸前后以及同机旧工作树对照。

## 实际画面与对照

不是设计稿或合成胜利；装置目录为生产绘制代码的诊断夹具。

- 修改前：[v0.5.1 首关及画面](v051-acceptance.md#实际画面)。
- 修改后：[主菜单 1920×1080](../artifacts/qa/v06-release-visual-4b4e29b8796a475ca2aeb350d89d1957/project/artifacts/v06-menu-1920.png)、[设置 1280×720](../artifacts/qa/v06-release-visual-4b4e29b8796a475ca2aeb350d89d1957/project/artifacts/v06-settings-1280.png)。
- [九装置轮廓](../artifacts/qa/v06-release-visual-4b4e29b8796a475ca2aeb350d89d1957/project/artifacts/v06-device-catalog.png)、[轮盘](../artifacts/qa/v06-release-visual-4b4e29b8796a475ca2aeb350d89d1957/project/artifacts/v06-radial.png)、[F2](../artifacts/qa/v06-release-visual-4b4e29b8796a475ca2aeb350d89d1957/project/artifacts/v06-tuning.png)。
- [真实有效命中](../artifacts/qa/v06-delivery-route-eb31b6334470414e80e3df8fa40c9d67/project/artifacts/v05-visible-hit-flash.png)、[真实首关结算](../artifacts/qa/v06-delivery-route-eb31b6334470414e80e3df8fa40c9d67/project/artifacts/v05-phase-finished-2-finished.png)。

Fennara 状态查询确认连接到本项目 Godot 4.7.1；实际脚本诊断调用随后超时，因此运行验收改用隔离 CLI，未修改插件、重启用户编辑器或切换项目渲染器。界面和音频专项使用项目 Forward+；代表性能套件沿用 D3D12 Mobile 的明确测试参数。原生全屏为本机 2560×1440，同时实际切换窗口验证 720p／1080p。

## 复现与下一步

```powershell
.\tools\run_validation.ps1 -Suite Full -Label local-full
.\tools\run_validation.ps1 -Suite Visual -Label local-visual
.\tools\run_validation.ps1 -Suite Audio -Label local-audio
.\tools\run_validation.ps1 -Suite Playthrough -Label local-input
.\tools\run_validation.ps1 -Suite Performance -Label local-performance
```

视听／真实输入测试会打开本机窗口，请勿同时操作测试窗口；性能测试单独运行以减少系统负载干扰。音频专项会实际播放短音，请先调低系统音量。

下一优先级：作者视听试玩 → 修正识别／音色／舒适度问题 → 确定第二关教学能力和装置组合 → 制作第二关。陌生玩家教学验证仍独立待办，不把当前作者反馈和自动测试替代它。

技术参考：[Godot Window 主题接口](https://docs.godotengine.org/en/4.7/classes/class_window.html)；嵌入窗口使用 `embedded_border`，避免保留默认灰色窗体。
