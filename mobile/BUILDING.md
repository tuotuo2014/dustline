# 尘线废土手机版：打开与构建

这是 `/Users/tuotuo/3d/mobile/project` 中的独立 Godot 项目。桌面原版仍在上一层目录；本目录的构建脚本只读取、导入和导出手机版。

## 安卓手机

已生成的测试安装包：`builds/android/Dustline-Mobile.apk`。

把 APK 传到安卓手机并打开，按手机提示允许此次安装，然后从桌面打开“尘线废土·手机版”。这是采用本地调试密钥签名的测试版，未上传任何应用商店。支持 ARM64，清单最低 Android 7.0 / API 24；实际游戏还需要支持 Vulkan 的较新手机，画质和帧率需以真机为准。

如果用数据线安装：开启手机开发者选项和 USB 调试，授权电脑后执行：

```sh
cd /Users/tuotuo/3d/mobile
tools/android-sdk/platform-tools/adb install -r builds/android/Dustline-Mobile.apk
```

没有连接安卓真机，因此尚未完成安装、发热、续航和实际帧率测试。

## iPhone 和安卓浏览器

双击本目录的 `打开手机版.command`，保持启动窗口不关闭。启动器会打开本地游戏服务，并使用 Cloudflare 官方 `cloudflared` 建立免费临时 HTTPS 隧道。手机使用窗口显示的 `https://…trycloudflare.com/` 地址；最新地址也写入 `当前手机网址.txt`。手机不要求同一 Wi-Fi，但手机和电脑都需要联网。

**之前的局域网 HTTP 说明有误，已更正。** 单线程导出依然需要安全连接；它只免除跨源隔离和 SharedArrayBuffer 要求。`localhost` 是浏览器特例，不能用本机测试代替手机访问验证。旧 LAN HTTP 首页现在通过浏览器安全上下文检测跳转 HTTPS，安全页面本身不会重复跳转；未连接隧道时显示中文提示。

网页资源通过 gzip 传输约 32 MB，解压后约 60 MB；大型请求限制输出速度以避免网络缓冲区溢出。下载完成后还需生成三维场景。服务固定读取 `builds/web` 中九个游戏文件，禁止源代码、工具、目录列表及符号链接。

HTTPS 链接为临时公网入口，重启后可能变化，不等于购买或注册了 `feitu.tt`。关闭电脑或启动器后入口失效。日志位于 `builds/logs/https-tunnel.log`。仅本机预览时仍可运行 `python3 serve_mobile.py` 并打开 `http://localhost:8077/`；手机请运行完整启动器 `python3 start_mobile.py`。

浏览器版与安卓原生版是同一手机版项目的不同导出。浏览器真人联机使用同一入口上的 `/multiplayer` WebSocket 中继，公网为 `wss://…trycloudflare.com/multiplayer`；原生局域网联机继续使用 ENet。启动器会同时启动静态资源服务和中继，无需另开端口或安装系统 Python 包。

## 重新构建

所有构建工具保存在 `mobile/tools`，包括一份独立的 Godot 编辑器及其设置。不会改动原版编辑器的导出设置，也不需要安装系统级 Java 或 Android Studio。

```sh
cd /Users/tuotuo/3d/mobile
./build_mobile.sh check    # 检查本机工具
./build_mobile.sh android  # 重新生成安卓 APK
./build_mobile.sh web      # 重新生成手机网页
./build_mobile.sh all      # 安卓 APK 和手机网页
```

导出预设在 `project/export_presets.cfg`。日志在 `builds/logs`。安卓调试密钥在 `tools/keys/debug.keystore`，只用于本地测试，密码是 Android 通用调试密码。它不是商店发布密钥。

原版和手机版的项目内容、存档目录各自独立。之后修改原版不会自动同步到这个副本。

## iPhone 原生应用

已经准备好 `iPhone Mobile` 导出预设、ARM64 配置和与编辑器版本严格匹配的官方 iOS 模板。**本机没有完整 Xcode，也没有用户的 Apple Team ID / 签名配置；尚未生成 Xcode 工程或可安装的 IPA。** 不把网页文件或未签名文件称为 iPhone 安装包。

后续在 Mac 上安装完整 Xcode，完成首次启动和工具安装，在 Xcode 登录自己的 Apple ID，再填入自己的真实 Team ID：

```sh
cd /Users/tuotuo/3d/mobile
IOS_TEAM_ID=你的10位TeamID ./build_mobile.sh ios
```

此命令导出工程文件，不自动签名、分发或上传 App Store。用 Xcode 打开导出的工程，选择自己的 Team、连接 iPhone，再编译运行。预设最低 iOS 15。Godot 官方 4.7.2 的导出器即使仅导出工程也要求 Team ID，因此没有使用虚构身份绕过检查。个人 Apple ID 的免费真机调试是否可用、签名有效期和数量限制由 Apple 决定。

## 已完成的构建验证

- Godot 4.7.2 官方模板下载完成，SHA-256 与官方 GitHub release 元数据一致。
- 安卓 APK 实际导出成功，`apksigner verify` 通过 v2 / v3 签名验证，`zipalign -c -P 16 4` 通过。
- APK 元数据可读取：包名 `com.tuotuo.dustlinemobile`、版本 `0.1.0`、ARM64、API 24 / 36、横屏。
- Web 实际导出了 HTML、JavaScript、WASM 和游戏数据；本地服务器对 HTML 与 WASM 返回 HTTP 200，WASM 类型为 `application/wasm`。
- 没有完成安卓或 iPhone 真机运行验证；本机没有 Xcode，因此不能声称已验证 iPhone 原生编译。

## 来源、版本与本地位置

| 工具 | 来源 | 版本 | 本目录中的位置 |
| --- | --- | --- | --- |
| Godot 编辑器 | 本机原有官方签名应用的独立副本 | 4.7.2.stable.official.ed1daf0bf | `tools/godot/Godot.app` |
| Godot Android / iOS / Web 模板 | [Godot 官方 4.7.2 发布](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) | 4.7.2 stable | `tools/templates/4.7.2.stable` |
| OpenJDK | [Eclipse Adoptium 官方发行](https://adoptium.net/temurin/releases/?version=17) | Temurin 17.0.20.1+1，macOS ARM64 | `tools/jdk/jdk-17.0.20.1+1/Contents/Home` |
| Android Build Tools | [Google Android SDK 仓库](https://dl.google.com/android/repository/repository2-3.xml) | 36.0.0 | `tools/android-sdk/build-tools/36.0.0` |
| Android Platform Tools | [Google 官方 Platform Tools](https://developer.android.com/tools/releases/platform-tools) | 37.0.1，adb 1.0.41 | `tools/android-sdk/platform-tools` |

完整下载地址与校验值记录在 `tools/SOURCES.json`。工具的许可证保留在各自目录。没有购买、使用收费服务或上传项目内容。

## 手机版玩法与画面验证

- 触屏控制：43 项通过；真实游戏触屏操作：31 项通过。
- 手机 UI 与触屏新手教程：96 项通过。
- 既有角色移动：19 项通过；人物动态：15 项通过。
- 1280 × 720 与 1560 × 720 实际 GPU 画面检查：Mobile、Compatibility 渲染器各 108 项通过；最后运行没有脚本或渲染错误。
- 角色眼睛改用独立材质参数，避免 WebGL 实例参数数量限制；保留左右眼方向、视线与眨眼动态。
- 对比手机版复制前的原版 SHA-256 清单，267 个原有源代码与资源文件未变化。
- 上述验证在这台 Mac 上完成，不能代替安卓/iPhone 真机兼容性、帧率和续航测试。

最终网页验证：在独立 Chrome 浏览器中，真实 WASM 游戏完成加载；模拟触屏点击「进入荒原」成功进入游戏和新手教程。截图为 `project/previews/browser-entry.png` 与 `browser-start.png`。该检查不等于 iPhone Safari 真机验证。

HTTPS 工具来源：Cloudflare 官方 GitHub release `2026.10.1`，macOS ARM64。下载地址与 SHA-256 记录在 `tools/cloudflared/SOURCE.json`；实际二进制在 `tools/cloudflared/cloudflared`。

HTTPS 修复验证：从实际 LAN HTTP 入口跳转临时 HTTPS 地址，桌面 Chrome 手机触屏模拟确认 `isSecureContext=true`，Godot 缺失特性为空，完整加载 WASM/PCK 后显示菜单，并实际点击进入新手教程。截图 `project/previews/browser-https-entry.png` 和 `browser-https-start.png`。HTTP 服务回归 9 项通过。原版 267 个文件再次哈希核对无变化。本次没有声称完成手机真机测试。

## 真人联机中继

`coop_relay.py` 使用本目录 `tools/python` 中固定版本的纯 Python 包：wsproto 1.2.0 与 h11 0.16.0，来源为 PyPI 官方包索引，许可证随包保留。`tools/python/SOURCE.json` 记录来源。该服务只转发实际连接用户的 Godot 消息；不会创建 NPC 队友或模拟在线人数。每间房最多四人，房主决定开始行动；房间码使用随机六位大写字母/数字。

中继按真实连接分配玩家身份，客户端只能把游戏数据发给房主；只有房主可管理房间。不同房间互相隔离，行动期间锁定加入，房主离开关闭房间。服务限制每条消息、发送队列、连接数和流量，并保留心跳以支持场景加载。电脑作为中继和资源服务器必须保持运行；临时隧道不是长期托管服务。

本机回归验证命令：

```sh
python3 tests/test_coop_relay.py
python3 tests/test_https_entry.py
```

WebSocket 回归使用独立真实 TCP 连接检查房间创建、加入、两到四人、消息路由与身份、广播、房间隔离、锁定、踢出、退出、房主掉线、错误数据与消息分片。该检查不等于手机真机网络或性能测试。

2026-10-18 真人联机验证：

- 实际 Godot 两进程通过 WebSocket 完成 61 项检查：共享地图、移动、拾取、治疗、技能、射击、修复、狼兽目标、倒地救援、撤离与断开清理。
- 四进程 71 项检查通过：四个独立连接及角色、全队失败、再次出发、换地图、房主退出。
- 真实公网 WSS 上的 Godot 传输检查 18/18 通过，包括 RPC、广播、身份、锁房、踢出及明确断线原因。
- 桌面 Chrome 以触屏模式实际打开 HTTPS 游戏，创建房间；另一个独立 Godot 玩家经公网房间码加入并准备。点击开始进入同图，浏览器摇杆移动被另一玩家收到，退出后队伍移除该连接。浏览器无脚本错误。截图：`project/previews/online-two-players-lobby.png`、`online-round-check.png`、`online-touch-multiplayer.png`。
- 测试玩家是验证用独立客户端；产品不创建机器人或伪造在线玩家。未进行安卓和 iPhone 实机联机测试。
- Android APK 与 Web 重新导出；原版 267 个文件哈希无变化。
- 启动器检查本机隧道状态和公网健康路径后才公布链接；断线或状态超过 30 秒后，旧 LAN 入口不再跳转到失效链接。恢复时复用同一个隧道网址。重启启动器仍会分配新的临时域名。

扩展回归：`python3 tests/test_tunnel_status.py`；项目内 `python3 tests/run_coop_regressions.py --relay ws://127.0.0.1:8077/multiplayer`，加 `--capacity` 验证四个独立游戏进程。
