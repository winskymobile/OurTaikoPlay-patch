# OurTaikoPlay 补丁包 · play-preferences

给已安装的 **OurTaikoPlay.app**（Unity 6000.6.7f1 / 6000.6.8f1 + Mono 后端）打补丁，
**不需要 Unity 编辑器**。补丁按模块拆分，可以只装数据目录、只装译文，或加装飞出音符。

## 1.0.1-507

当前基线是 `patches/1.0.1-507/`，对应上游提交 `a5c3501`。模块清单和依赖写在
`patches/1.0.1-507/manifest.txt`，补丁文件本身也都是独立的 git patch。

- 韩文已经从 `UiText` 译文表移除；保留日文、简体、繁体三列。
- 设置页语言行仍按上游提供英 / 日 / 简；繁体译文表保留给已有 `zh_tw` 设置和结算测试。
- 简繁字体、结算切图、段位切图仍然嵌入 `OurTaiko.Runtime.dll`。
- 飞出音符是可选模块；不加它时，显示页只有上游的背景影片设置。

旧版存档仍在仓库根目录：`play-preferences-1.0.1-505.patch`、`play-preferences-1.0.1-480.patch`、
`play-preferences.patch`（467 及以前）。

## 快速使用

```bash
# 看当前 app 版本可用的模块
tools/patch-app.sh --list

# 交互选择；直接回车等于 core
tools/patch-app.sh

# 除飞出音符外的全部模块
tools/patch-app.sh --preset core

# 全部模块，包含飞出音符
tools/patch-app.sh --preset full

# 只迁移 macOS 数据目录
tools/patch-app.sh --preset data-only

# 只装界面译文核心
tools/patch-app.sh --preset language-only

# core 加飞出音符
tools/patch-app.sh --preset core --with flying-notes

# core 去掉结算页
tools/patch-app.sh --preset core --without result-page

# 手工解决冲突后，直接编译当前源码树
tools/patch-app.sh --source tools/build/source-1.0.1-507 --from-tree

# 只编译和检查，不安装
tools/patch-app.sh --preset full --no-install

# 离线：不 fetch 上游
tools/patch-app.sh --preset full --no-install --no-fetch
```

脚本会按 app 的 `CFBundleShortVersionString` 找 `patches/<版本>/`，在清单的基线提交上
按顺序应用选中的模块，自动补齐依赖，然后编译、过布局 / 译文两道闸门，最后安装并合并
`settings.json`。没有显式选择时，终端里会先列出模块并询问；非交互环境默认 `core`。
不传 `--source` 时优先使用 `tools/build/source-<版本>`，避免在 `../OurTaikoPlay`
的其它分支或未提交改动上误操作。

## 模块

| id | 内容 | 依赖 |
| --- | --- | --- |
| `macos-data-root` | macOS 数据目录迁到 `~/Library/Application Support/OurTaiko/OurTaikoPlay/`，首次启动从 `.app` 内复制 `Songs`、`cache`、`settings.json`、`options.json`、`player.json`、`servers.json`、`scores.sqlite3`；旧文件保留不删 | 无 |
| `interface-language` | `UiText` 译文表、设置页、语言行、游戏内简繁字体、`InGameFont` | 无 |
| `entry-online-text` | 入口看板、账号与登录状态提示、在线文字 | `interface-language` |
| `play-text` | 演奏、暂停、练习、选项板、加载文字 | `interface-language` |
| `song-select-text` | 选曲界面文字 | `interface-language` |
| `result-page` | 结算页文字，难度 / 判定 / 成绩 / 通关简繁切图 | `interface-language` |
| `dan-page` | 段位道场文字，合格条件与确认框简繁切图 | `interface-language` |
| `flying-notes` | 显示设置新增「飞出音符」（图片 / 精灵）与「飞出数量」（高 / 中 / 低） | `interface-language` |

预设：`core`（除飞出音符外的全部）、`full`（全部）、`data-only`、`language-only`。

## 补丁规则

- 每个模块是一个正常的 `git apply --3way` 补丁，基线固定写在 `manifest.txt` 的 `base` 行。
- 模块按清单顺序应用；只跳过未选中的模块，不会改动它们的文件。
- `--with` 会递归补齐 `requires`；`--without` 在依赖解析之后移除模块，若还有模块需要它，脚本会停下说明。
- 上游更新后，先为对应 app 版本新建 `patches/<版本>/`，把模块补丁重放到该版本上游提交，再更新 `base`。
- 手工解决冲突后，用 `--from-tree` 直接以当前源码树编译和检查。
- 只选 `data-only` 时没有 `UiText.cs`，译文闸门会跳过；结算 / 段位的切图脚本只在
  对应模块存在时运行，字体只在 `interface-language` 存在时嵌入。

## 目录

```
patches/1.0.1-507/                        507 的模块补丁与清单
  manifest.txt                            基线、预设、模块依赖
  01-macos-data-root.patch                macOS 数据目录
  02-interface-language.patch             界面译文核心
  03-entry-online-text.patch              入口与在线文字
  04-play-text.patch                      演奏与练习文字
  05-song-select-text.patch               选曲文字
  06-result-page.patch                    结算页文字与切图
  07-dan-page.patch                       段位页文字与切图
  08-flying-notes.patch                   飞出音符（可选）
play-preferences-1.0.1-507.patch          507 的合并补丁（手工重放时用）
play-preferences-1.0.1-505.patch          505 存档
play-preferences-1.0.1-480.patch          480 存档
play-preferences.patch                    旧基线补丁（467 及以前）
FOT-OedKtrStdE.otf                        简繁界面与结算切图字体（构建时嵌入 DLL）
README.md                                 本文
tools/patch-app.sh                        选择模块 → 重放 → 编译 → 闸门 → 安装
tools/build-runtime-dll.sh                用 app 自带程序集编译 OurTaiko.Runtime.dll
tools/make-result-art.py                  生成简繁结算贴图
tools/make-dan-exam-art.py                生成简繁段位切图
tools/make-font.py                        重新生成 FOT-OedKtrStdE.otf（需要 fontTools）
tools/save-original.sh                    保存未打补丁的原版 DLL
tools/install.sh                          关游戏、校验布局、备份、安装、合并 settings.json
tools/restore.sh                          还原原版 DLL
tools/check-layout.sh                     字段布局闸门
tools/check-translations.py               译文表完整性检查
tools/fieldcheck/                         字段差分工具源码
backup/                                   原版 DLL 与设置备份（不进仓库）
```

## 手工编译与安装

```bash
# 0) 留一份原版 DLL（升级 app 后先做）
tools/save-original.sh

# 1) 编译
tools/build-runtime-dll.sh tools/build/source-1.0.1-507 /Applications/OurTaikoPlay.app tools/build/1.0.1-507

# 2) 安装
tools/install.sh tools/build/1.0.1-507/OurTaiko.Runtime.dll
```

安装前会检查 `backup/OurTaiko.Runtime.<版本>.original.dll` 的字段布局；布局不一致会直接
中止，不会覆盖 app。

## APP 更新后

官方更新会覆盖 `OurTaiko.Runtime.dll`，补丁随之失效。正常情况：

```bash
tools/patch-app.sh --list
tools/patch-app.sh --preset core --launch
```

如果 app 版本还没有对应目录，先从上游建立新的 `patches/<版本>/`。当前 507 的流程是：

```bash
cd tools/build/source-1.0.1-507
git fetch upstream
git checkout -B play-preferences a5c3501

# 逐个应用模块，或直接用合并补丁
git apply --3way ../../../play-preferences-1.0.1-507.patch
```

更推荐直接用脚本：它按 manifest 顺序逐个应用，自动补依赖，并在安装前跑布局与译文闸门。

```bash
tools/patch-app.sh --preset full --no-install
```

## 自检

```bash
tools/check-layout.sh backup/OurTaiko.Runtime.1.0.1-507.original.dll tools/build/1.0.1-507/OurTaiko.Runtime.dll
python3 tools/check-translations.py tools/build/source-1.0.1-507
```

`check-layout.sh` 必须输出 `MonoBehaviour layout breaks: 0`，`check-translations.py` 必须输出
`translations OK`。给已经存在于场景中的 MonoBehaviour 加序列化字段会让 Unity 读错后续字段，
进设置页时可能报 `The file 'level2' is corrupted!` 并崩溃；要加状态就用私有字段、
`[NonSerialized]`，或者放进不挂在场景上的新类。

## 注意

- 替换 DLL 会让 `codesign --verify` 报 "sealed resource is missing or invalid"。原包是 adhoc
  签名，实测不影响启动。
- 首次启动迁移后，数据在 `~/Library/Application Support/OurTaiko/OurTaikoPlay/`；
  `.app` 内的旧文件保留，可自行删除。
- 编译依赖 .NET SDK（`dotnet`）和带 Pillow 的 `python3`；`check-layout.sh` 首次会构建
  `tools/fieldcheck`。
- `backup/*.dll`、`tools/build/`、`tools/fieldcheck/bin|obj/` 是本机产物，不进仓库。
