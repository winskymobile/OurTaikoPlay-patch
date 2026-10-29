# OurTaikoPlay 补丁包 · play-preferences

给已安装的 **OurTaikoPlay.app**（1.0-349，Unity 6000.6.7f1 + Mono 后端）打上
`play-preferences` 补丁，**不需要 Unity 编辑器**。

游戏逻辑全在 `Contents/Resources/Data/Managed/OurTaiko.Runtime.dll` 里。补丁的落地方式：
用 **app 自带的那套 Unity 程序集**把补丁源码编译成同名 DLL 替换进去。

## 补丁内容

| 分组 | 内容 |
| --- | --- |
| macOS 数据目录 | 正式版数据从 `.app` 内迁到 `~/Library/Application Support/OurTaiko/OurTaikoPlay/`；首次启动复制 `Songs`、`cache`、`settings.json`、`options.json`、`player.json`、`servers.json`、`scores.sqlite3`，旧文件保留不删 |
| 界面语言 | 设置菜单（英 / 日 / 简 / 繁 / 韩）与游戏内文字（日 / 简 / 繁，英韩回落日文）；设置页标题、入口看板、声音页、账号页、按键项、提示与状态行全部走译文表 |
| 飞出音符绘制 | 显示设置新增「飞出音符」（图片 / 精灵）与「飞出数量」（高 / 中 / 低） |

保留上游的背景影片设置（背景影片、影片时轨道不透明度），显示页共 6 项。

## 目录

```
play-preferences.patch                    完整补丁（基于 upstream/main @ e8fc18a = 1.0-349）
play-preferences-upstream-e8fc18a.patch   上一版存档
README.md                                 本文
tools/build-runtime-dll.sh                用 app 自带程序集编译 OurTaiko.Runtime.dll
tools/save-original.sh                    保存未打补丁的原版 DLL（升级 app 后先跑）
tools/install.sh                          关掉游戏、校验布局、备份、安装、合并 settings.json
tools/restore.sh                          还原为未打补丁的 DLL
tools/update-source.sh                    把补丁重放到新的上游版本
tools/check-layout.sh                     字段布局闸门（MonoBehaviour 加序列化字段会让场景崩溃）
tools/check-translations.py               译文表完整性检查
tools/fieldcheck/                         字段差分工具源码（check-layout.sh 调用）
backup/                                   原版 DLL 与设置备份（不进仓库）
```

## 首次安装

```bash
# 0) 先从官方包里留一份原版 DLL（只做一次，之后升级 app 再重做）
tools/save-original.sh

# 1) 编译
tools/build-runtime-dll.sh "/Users/vincent/Documents/开发/OurTaikoPlay" /Applications/OurTaikoPlay.app

# 2) 安装（默认不启动游戏，需要启动时加 --launch）
tools/install.sh
```

## APP 更新后重新打补丁

官方更新会覆盖 `OurTaiko.Runtime.dll`，补丁会失效：

```bash
# 1) 重新留原版 DLL（版本号会写进文件名）
tools/save-original.sh

# 2) 把补丁重放到新的上游代码（有冲突会列出来）
tools/update-source.sh upstream/main "/Users/vincent/Documents/开发/OurTaikoPlay"
#    在 ../OurTaikoPlay 里解冲突 → 重新生成 play-preferences.patch：
#    cd ../OurTaikoPlay && git add -A && git diff --cached HEAD > ../OurTaikoPlay-patch/play-preferences.patch

# 3) 用新装 app 自带的程序集重新编译
tools/build-runtime-dll.sh "/Users/vincent/Documents/开发/OurTaikoPlay" /Applications/OurTaikoPlay.app

# 4) 安装
tools/install.sh
```

冲突高发文件：`PlayScene.cs` / `PlayerLane.cs`（判定逻辑位置）、
`SettingsMenu.cs` + `GameSettings.cs`（设置项顺序）、`UiText.cs`（译文表键）。

## 每次改代码后的自检

```bash
tools/build-runtime-dll.sh
tools/check-layout.sh          # 必须输出 MonoBehaviour layout breaks: 0
tools/check-translations.py    # 必须输出 translations OK
tools/install.sh               # 内含布局闸门，失败会直接中止
```

`check-layout.sh` 拦的是这一类事故：Unity 按**字段声明顺序**把组件数据写进
`data.unity3d` 里的 `level0-3`。给已经存在于场景中的 MonoBehaviour 加一个
`public` / `[SerializeField]` 字段，后面所有字段都会错位，进设置页时 Unity 报
`The file 'level2' is corrupted!` 并 SIGTRAP。

本次就是这么修的：设置页标题改成**私有、不序列化**的 `TMP_Text title`，运行时用
`transform.Find("Header")` 兜底；场景文件里新增的 `title:` 行也删掉了。要加状态就用
`[NonSerialized]`、私有字段，或者放进新类（如 `UiText`、`MacPlayerData` 这种不挂在场景上的类型）。

`DisplaySettings` / `Arc` 不是 MonoBehaviour，加字段只影响 `settings.json` 与运行时数据，安全。

## 还原

```bash
tools/restore.sh                      # 用 backup/ 里最新的原版 DLL
tools/restore.sh path/to/other.dll    # 指定某个 DLL
```

## 注意

- 替换 DLL 会让 `codesign --verify` 报 "sealed resource is missing or invalid"。
  原包本身是 adhoc 签名，实测不影响启动。
- 首次启动迁移后，数据在 `~/Library/Application Support/OurTaiko/OurTaikoPlay/`；
  `.app` 内的旧文件保留，可自行删除。
- 编译依赖 .NET SDK（`dotnet`），`check-layout.sh` 依赖 `tools/fieldcheck`（首次会 `dotnet build`）。
- `backup/*.dll`、`tools/build/`、`tools/fieldcheck/bin|obj/` 是本机产物，不进仓库。
