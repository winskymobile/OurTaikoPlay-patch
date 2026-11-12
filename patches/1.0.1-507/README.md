# 1.0.1-507 补丁集

- 目标 app：OurTaikoPlay `1.0.1-507`
- 基线提交：上游 `a5c3501`
- 工作树：`tools/build/source-1.0.1-507`（分支 `modular-507`）
- 模块清单：`manifest.txt`
- 合并补丁：仓库根目录 `play-preferences-1.0.1-507.patch`

每个模块都是对着 `a5c3501` 切出的独立 git patch，按 `manifest.txt` 的顺序应用。
模块只依赖 `interface-language`，可以单独选、组合选，或者跳过任何文字模块。

## 数据目录

`macos-data-root` 把 macOS 正式版的数据根从 `.app` 内部迁到：

```
~/Library/Application Support/OurTaiko/OurTaikoPlay/
├── Songs/                 谱面与歌曲文件
├── cache/                 缓存
├── settings.json          设置
├── options.json           选项
├── player.json            玩家名牌
├── servers.json           服务器列表
└── scores.sqlite3         本地成绩与待上传队列
```

首次启动时的迁移规则：

- 只处理上面列出的 5 个文件和 2 个目录，不会把 `.app` 里的 `Contents`、可执行文件等一起搬走。
- 目标文件已存在且非空时跳过；目标目录已存在且非空时整个目录跳过。
- 空的 `Songs/` 视为未迁移，下次启动会再补。
- 只复制，不删除 `.app` 内的旧文件；确认新目录正常后可自行清理旧文件。
- Windows / Linux 仍保持“可执行文件旁边”；iOS / Android / Editor 仍用 `Application.persistentDataPath`。

`tools/install.sh` 在安装后还会合并设置：玩家的 `settings.json` 优先，只补入新版本新增、
玩家文件里还没有的键，并在合并前写 `settings.json.bak-<时间戳>`。

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

### 01 `macos-data-root`

```
Assets/OurTaiko/Runtime/Core/GamePaths.cs
Assets/OurTaiko/Runtime/Core/MacPlayerData.cs (+ .meta)
Assets/OurTaiko/Tests/EditMode/GamePathsTests.cs (+ .meta)
Assets/OurTaiko/Tests/EditMode/MacPlayerDataTests.cs (+ .meta)
```

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

译文表只有三列：日文、简体、繁体。韩文列与韩文界面已经移除。

### 03 `entry-online-text`

```
Assets/OurTaiko/Runtime/Online/OnlineManager.cs
Assets/OurTaiko/Runtime/Scenes/EntryScene.cs
Assets/OurTaiko/Runtime/Scenes/LocalSongLibrary.cs
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

切图在构建时由 `tools/make-result-art.py` 生成并嵌入 DLL，不向 `.app` 写额外文件。

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

显示设置新增两项：

- 飞出音符绘制方式：图片 / 精灵
- 飞出数量：高 / 中 / 低

不选这个模块时，显示页只有上游原有的背景影片设置。

## 预设

- `core`：除 `flying-notes` 外的全部模块
- `full`：全部 8 个模块
- `data-only`：只装 `macos-data-root`
- `language-only`：只装 `interface-language`

## 命令

```bash
cd /Users/vincent/Documents/开发/OurTaikoPlay-patch

# 列出 507 的模块
tools/patch-app.sh --list

# 只编译检查，不安装
tools/patch-app.sh --preset full --no-install --no-fetch

# 只迁移数据目录
tools/patch-app.sh --preset data-only --no-install

# 只要界面译文核心
tools/patch-app.sh --preset language-only --no-install

# core 去掉结算页
tools/patch-app.sh --preset core --without result-page --no-install

# 只加飞出音符；脚本会自动补 interface-language
tools/patch-app.sh --with flying-notes --no-install

# 手工解决冲突后，直接编译当前源码树
tools/patch-app.sh --source tools/build/source-1.0.1-507 \
  --from-tree --no-install --no-fetch
```

不传 `--source` 时，脚本优先使用 `tools/build/source-<app 版本>`；该目录不存在或
不可用时才回退到 `../OurTaikoPlay`。

## 验证

全量模块的预期闸门：

```
MonoBehaviour layout breaks: 0
458 rows, 84 keys used by the runtime
translations OK
```

`data-only` 没有 `UiText.cs`，脚本会输出
`translations skipped (interface-language not selected)`；`language-only` 或去掉某个
文字模块时，未被选中的模块里的占位符键会以 `note:` 形式提示，不算失败。

## 上游更新

1. 用新 app 的 `CFBundleShortVersionString` 建 `patches/<版本>/`。
2. 在对应上游提交上开工作树，逐个重放 `manifest.txt` 里的模块。
3. 更新 `base`、模块文件、预设与依赖。
4. 重新生成合并补丁：

   ```bash
   git -C tools/build/source-<版本> diff <base> HEAD > play-preferences-<版本>.patch
   ```

5. 用 `--preset full --no-install` 和最少模块组合各跑一遍布局 / 译文闸门。
