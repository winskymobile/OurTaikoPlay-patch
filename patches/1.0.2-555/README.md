# 1.0.2-555 补丁集

- 目标 app：OurTaikoPlay `1.0.2-555`
- 基线提交：上游 `067a25a99602f2fa7de7e68cde48a678665a40df`
- 工作树：`tools/build/source-1.0.2-555`（分支 `play-preferences-1.0.2-555`）
- 模块清单：`manifest.txt`
- 合并补丁：仓库根目录 `play-preferences-1.0.2-555.patch`

555 在 553 的基础上只多了两个上游提交：`bd738a6d`（练习 HUD 保留上一次成绩）和
`067a25a9`（桌面 / 安卓自定义设置侧栏分类，安卓账号输入与刷新率）。十一个模块（553 的九个加音符平滑、窗口等比缩放）按
`manifest.txt` 顺序重放，其中两个模块需要手工对位：

- `02-interface-language`：555 把设置侧栏的「关闭」从列表项拆成了独立的 `railClose`，
  译文不再改列表项文字，而是把 `railClose.label.text` 接到 `UiText.Settings("Close")`。
- `09-bpm-readout`：555 把显示页的帧率 / 垂直同步 / 3D 咚抽成了 `Rendering(platform)`，
  BPM 分组改为接在该辅助函数后面，不再重复声明那三行。

其余模块（含 `01`、`03`–`08`）在 555 上直接应用即可。全量模块的闸门输出：

```
changed types: 3, MonoBehaviour layout breaks: 0
462 rows, 84 keys used by the runtime
translations OK
```

## 模块与文件

| id | 内容 | 依赖 |
| --- | --- | --- |
| `macos-data-root` | macOS 数据根、首次迁移、路径测试 | 无 |
| `interface-language` | `UiText` 译文表、设置页语言行、游戏内简繁字体 | 无 |
| `entry-online-text` | 入口看板、账号、登录状态、在线文字 | `interface-language` |
| `play-text` | 演奏、暂停、练习、选项板、加载文字 | `interface-language` |
| `song-select-text` | 选曲界面文字 | `interface-language` |
| `result-page` | 结算页文字、难度 / 判定 / 成绩 / 通关简繁切图 | `interface-language` |
| `dan-page` | 段位道场文字、合格条件、确认框简繁切图 | `interface-language` |
| `flying-notes` | 显示设置里的飞出音符绘制方式与数量 | `interface-language` |
| `bpm-readout` | BPM 小字：歌曲板、难度选择页、演奏 HUD | `interface-language` |
| `note-filter` | 音符图集改用 Bilinear 采样（可在显示设置关闭） | `interface-language` |
| `window-mode` | 全屏 / 16:9 窗口（1280×720–2560×1440） | 无 |
| `pause-settings` | 暂停菜单里的「游戏设置」入口 | `interface-language` |

### 01 `macos-data-root`

```
Assets/OurTaiko/Runtime/Core/GamePaths.cs
Assets/OurTaiko/Runtime/Core/MacPlayerData.cs (+ .meta)
Assets/OurTaiko/Tests/EditMode/GamePathsTests.cs (+ .meta)
Assets/OurTaiko/Tests/EditMode/MacPlayerDataTests.cs (+ .meta)
```

数据根迁到 `~/Library/Application Support/OurTaiko/OurTaikoPlay/`，首次启动只复制
`Songs/`、`cache/`、`settings.json`、`options.json`、`player.json`、`servers.json`、
`scores.sqlite3`，旧文件保留不删。

### 02 `interface-language`

```
Assets/OurTaiko/Runtime/Core/InGameFont.cs (+ .meta)
Assets/OurTaiko/Runtime/Core/UiText.cs (+ .meta)
Assets/OurTaiko/Runtime/Scenes/SettingManager.cs
Assets/OurTaiko/Runtime/Settings/SettingsCatalog.cs
Assets/OurTaiko/Runtime/Settings/SettingsNavigator.cs
Assets/OurTaiko/Runtime/Settings/SettingsOverlay.cs
Assets/OurTaiko/Runtime/Settings/SettingsOverlayView.cs
Assets/OurTaiko/Tests/EditMode/UiTextTests.cs (+ .meta)
Assets/OurTaiko/Tests/PlayMode/SongLanguageFlowTests.cs
```

译文表仍是日文、简体、繁体三列。

### 03 `entry-online-text`

```
Assets/OurTaiko/Runtime/Online/OnlineManager.cs
Assets/OurTaiko/Runtime/Scenes/EntryScene.cs
Assets/OurTaiko/Runtime/Scenes/PresentedScene.cs
```

### 04 `play-text`

```
Assets/OurTaiko/Runtime/Play/PauseMenuView.cs
Assets/OurTaiko/Runtime/Play/PlayScene.cs
Assets/OurTaiko/Runtime/Play/PracticeView.cs
Assets/OurTaiko/Runtime/Scenes/OptionPanel.cs
Assets/OurTaiko/Runtime/Scenes/SongLoadingScene.cs
```

### 05 `song-select-text`

```
Assets/OurTaiko/Runtime/Scenes/SongSelectManager.Search.cs
Assets/OurTaiko/Runtime/Scenes/SongSelectScene.Boards.cs
Assets/OurTaiko/Runtime/Scenes/SongSelectScene.cs
Assets/OurTaiko/Runtime/Scenes/SongSelectView.cs
```

### 06 `result-page`

```
Assets/OurTaiko/Runtime/Scenes/ResultAnalysisView.cs
Assets/OurTaiko/Runtime/Scenes/ResultArt.cs (+ .meta)
Assets/OurTaiko/Runtime/Scenes/ResultBoard.cs
Assets/OurTaiko/Runtime/Scenes/ResultScene.cs
Assets/OurTaiko/Tests/PlayMode/ResultLanguageFlowTests.cs (+ .meta)
```

切图在构建时由 `tools/make-result-art.py` 生成并嵌入 DLL。

### 07 `dan-page`

```
Assets/OurTaiko/Runtime/Play/DanPlayScene.cs
Assets/OurTaiko/Runtime/Scenes/DanExamArt.cs
Assets/OurTaiko/Runtime/Scenes/DanResultScene.cs
Assets/OurTaiko/Runtime/Scenes/DanSelectScene.cs
Assets/OurTaiko/Runtime/Scenes/DanSelectWidgets.cs
```

段位切图由 `tools/make-dan-exam-art.py` 生成并嵌入 DLL。

### 08 `flying-notes`（可选）

```
Assets/OurTaiko/Runtime/Core/GameSettings.cs
Assets/OurTaiko/Runtime/Core/UiText.cs
Assets/OurTaiko/Runtime/Play/LaneSprite.cs
Assets/OurTaiko/Runtime/Play/LaneSpriteLayer.cs
Assets/OurTaiko/Runtime/Play/NoteArcView.cs
Assets/OurTaiko/Runtime/Play/PlayerLane.cs
Assets/OurTaiko/Runtime/Settings/SettingsCatalog.cs
Assets/OurTaiko/Tests/EditMode/FlyingNoteDrawTests.cs (+ .meta)
```

### 09 `bpm-readout`

```
Assets/OurTaiko/Runtime/Core/GameSettings.cs
Assets/OurTaiko/Runtime/Core/UiText.cs
Assets/OurTaiko/Runtime/Play/PlayScene.cs
Assets/OurTaiko/Runtime/Scenes/BpmReadout.cs (+ .meta)
Assets/OurTaiko/Runtime/Scenes/SongSelectScene.cs
Assets/OurTaiko/Runtime/Scenes/SongSelectScene.Boards.cs
Assets/OurTaiko/Runtime/Scenes/SongSelectScene.Drawing.cs
Assets/OurTaiko/Runtime/Settings/SettingsCatalog.cs
```

显示设置新增 `BPM` 分组，开关 `Show BPM`（默认开），存在 `settings.json` 的
`display.showBpm`；关闭后三处读数同时隐藏。

### 10 `note-filter`

```
Assets/OurTaiko/Runtime/Core/GameSettings.cs
Assets/OurTaiko/Runtime/Core/UiText.cs
Assets/OurTaiko/Runtime/Play/NoteLaneRenderer.cs
Assets/OurTaiko/Runtime/Settings/SettingsCatalog.cs
```

音符图集（`notes_atlas.png`、`moji.png`）导入时是 Point 采样。1920 的设计在 Retina Mac 上
会被放大到 1.8 倍，Point 采样下每个纹素占 2–3 个设备像素且随音符移动来回跳，看起来像边缘在
蠕动。这个模块在运行时把音符、连打、文字、气球尾的贴图切成 Bilinear：

- 显示设置 → 渲染 → **平滑音符**，默认开启；关掉即恢复皮肤的 Point 采样。
- 每帧比较一次开关状态，改了设置暂停返回后立刻生效，不需要重开歌曲。
- 只改采样方式，不动贴图尺寸；要真正提升清晰度仍需重建资源（`maxTextureSize` 4096 + 不压缩）。

### 11 `window-mode`

```
Assets/OurTaiko/Runtime/Core/GameSettings.cs
Assets/OurTaiko/Runtime/Core/UiText.cs
Assets/OurTaiko/Runtime/Settings/SettingsCatalog.cs
```

显示 → 渲染 顶部新增两行：

- **窗口模式**：全屏 / 窗口，默认全屏（保持出厂行为）。
- **窗口大小**：1280×720 / 1600×900 / 1920×1080 / 2560×1440，全部 16:9，窗口正好铺满
  1920×1080 舞台，不会多出黑边。

生效点在 `DisplaySettings.Apply()`：只有模式或尺寸真的变化时才调用 `Screen.SetResolution`，
所以调其它设置项不会把玩家刚拖过的窗口弹回去。移动端平台不出这两行。

macOS 上窗口按 **2 倍像素**开：List 里的 1600×900 就是 1600×900 点（3200×1800 像素）。
显示器装不下时自动缩到能放下的最大 16:9，不会把窗口挂到屏幕外。

第一版试过用 Objective-C 运行时给窗口加 `NSWindowStyleMaskResizable` + `contentAspectRatio`
做自由拖拽，实机不起作用：Unity 给不可缩放的窗口把 `contentMinSize` / `contentMaxSize`
钉成同一个值，样式改了也拖不动。那一版已删除，改成上面的固定档位。

### 12 `pause-settings`

```
Assets/OurTaiko/Runtime/Play/PauseMenuView.cs
Assets/OurTaiko/Runtime/Core/UiText.cs
```

暂停面板是烤在预制体里的四条按钮（继续 / 重新开始 / 模式切换 / 返回选曲），设置只能从入口进，
打歌中想改偏移就得退出去。这个模块在 `Awake` 里克隆「返回选曲」那一行，清掉克隆来的点击与
`LocalizedText`，改名「游戏设置」，放在 Back 下面（y=-630，750×72），并把提示行从 -657 移到
-714 让出位置。

- 点击或键盘选中回车都会调用 `SettingsOverlay.Open()`；面板盖在暂停菜单上，关掉回到暂停菜单。
- 暂停菜单的 `HandleInput` 在 `SettingsOverlay.IsOpen` 时直接返回，避免和设置面板重复吃按键。
- 设置在面板里改了语言，关闭时 `ApplyLanguage()` 会把暂停菜单（含新入口）重新翻译。
- 只动这一处布局，其它按钮坐标保持预制体原值。

## 预设与功能序号

- `core`：除 `flying-notes` 外的全部模块（含 `bpm-readout`、`note-filter`、`window-mode`、`pause-settings`）
- `full`：全部 9 个模块
- `data-only`：只装 `macos-data-root`
- `language-only`：只装 `interface-language`

| 序号 | 功能 | 展开的模块 |
| --- | --- | --- |
| 1 | 数据目录迁移 | `macos-data-root` |
| 2 | 界面与游戏内文字（含 BPM 读数） | `interface-language`、`entry-online-text`、`play-text`、`song-select-text`、`result-page`、`dan-page`、`bpm-readout` |
| 3 | 飞出音符 | `flying-notes`（自动补 `interface-language`） |
| 4 | 音符平滑 | `note-filter`（自动补 `interface-language`） |
| 5 | 窗口模式与尺寸 | `window-mode` |
| 6 | 暂停菜单设置入口 | `pause-settings`（自动补 `interface-language`） |

## 命令

```bash
cd /Users/vincent/Documents/开发/OurTaikoPlay-patch

tools/patch-app.sh --list
tools/patch-app.sh --preset full
tools/patch-app.sh --preset full --no-install --no-fetch
tools/patch-app.sh --status
tools/patch-app.sh --restore --yes
```

## 构建注意

新开的源码工作树默认跳过 LFS 实体文件（`GIT_LFS_SKIP_SMUDGE=1`），而结算 / 段位切图
脚本要读真实 PNG。构建前补一次：

```bash
cd tools/build/source-1.0.2-555
git -c http.proxy= -c https.proxy= lfs checkout -- \
  Assets/OurTaiko/Art/result Assets/OurTaiko/Art/dan_select \
  Assets/OurTaiko/Art/dan_result Assets/OurTaiko/Art/game
```

另外 `dotnet` 编译产物每次都会带新的模块标识，两次构建的 DLL 哈希不同是正常的；
判断是否一致请看文件大小与闸门，不要拿 sha256 比对。

## 上游更新

1. 用新 app 的 `CFBundleShortVersionString` 建 `patches/<版本>/`。
2. 在对应上游提交上开工作树，逐个重放 `manifest.txt` 里的模块。
3. 更新 `base`、模块文件、预设与依赖。
4. 重新生成合并补丁：

   ```bash
   git -C tools/build/source-<版本> diff <base> -- '*.cs' '*.meta' > play-preferences-<版本>.patch
   ```

5. 用 `--preset full --no-install` 和最少模块组合各跑一遍布局 / 译文闸门。
