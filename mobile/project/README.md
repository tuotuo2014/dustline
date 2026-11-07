# 废土回响 · 手机版 Godot 项目

此目录是独立的 Android / iPhone 触屏版本源代码。完整进入方式、触控操作与打包说明见上一层的 `README.md`、`BUILDING.md`。

用 Godot 4.7.2 打开本目录的 `project.godot` 即可运行和编辑。不要从上层原版的 Godot 编辑器直接修改这个嵌套目录；`mobile/.gdignore` 会让原版忽略手机版。

触屏与界面验证脚本：

- `tests/mobile_touch_regression.gd`：摇杆、并行手势、按钮分发和取消。
- `tests/mobile_gameplay_regression.gd`：真实场景中的进入、治疗、技能、射击、跑跳和暂停。
- `tests/mobile_ui_regression.gd`：横屏布局与教程。
- `tests/mobile_visual_preview.gd`：准确手机尺寸的引擎截图。
- `tests/render_budget_regression.gd`：手机分辨率限制。

测试使用临时存档，避免覆盖实际游戏进度。生成的 Android APK、网页和工具在本项目的上层 `builds/`、`tools/` 中。
