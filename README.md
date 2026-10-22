# 印象笔记 SideNotes (Yinxiang SideNotes for macOS)

仿造 macOS 顶级效率神器 **SideNotes**，打造基于 **印象笔记（Yinxiang Biji）/ Evernote** 的屏幕边缘悬浮笔记应用。

> 拒绝 Electron 臃肿！全面采用 **macOS 原生（Swift / SwiftUI + AppKit）超轻架构**，应用体积仅 **1.5 MB**，待机内存仅 **~30 MB**，毫秒级快速启动，带来 120Hz 丝滑交互与原生毛玻璃视效！

---

## ✨ 核心特性

- 🖥️ **屏幕边缘停靠**：原生悬浮吸附于屏幕左侧或右侧，适配多显示器与 MenuBar/Dock 工作区。
- 📌 **常驻与自收起**：
  - **Pin 模式**：点击图钉锁定常驻，适合边查资料、浏览网页边做记录；
  - **轻量模式**：失焦或鼠标移开时原生动画平滑隐入边缘，不遮挡工作视线。
- ☁️ **印象笔记无缝对接**：
  - 支持 **国内版印象笔记**（`app.yinxiang.com`）与 **国际版 Evernote**（`www.evernote.com`）；
  - 自动识别并创建默认 **"SideNotes"** 笔记本，支持自由切换已有的任意印象笔记笔记本；
  - 支持在应用内直接新建印象笔记笔记本；
  - 支持双向读写与离线秒开（未填 Token 时亦可本地使用，填入即刻同步）。
- 📑 **SideNotes 经典卡片流**：
  - 优雅圆角卡片，时间戳、首行摘要与多色心情分类标签（红、橙、绿、蓝、紫、灰）；
  - 即时搜索：毫秒级响应标题与全文过滤；
  - 卡片就地编辑：Markdown 标记（标题、加粗、斜体、代码）与待办复选框（Checklist）。
- ⌨️ **系统级集成**：
  - macOS 顶部菜单栏图标（点击唤出/隐藏，右键弹出快捷操作）；
  - 全局快捷键：`Command + Option + S` 随时呼出。

---

## 🚀 架构对比：原生 Swift vs Electron

| 对比维度 | 原生 Swift 版 (本项目) | 传统 Electron 方案 |
| :--- | :--- | :--- |
| **应用体积** | **1.5 MB** | 150 MB ~ 250 MB |
| **内存占用** | **约 30 MB ~ 45 MB** | 150 MB ~ 300 MB |
| **启动速度** | **< 0.1 秒 (毫秒级秒开)** | 2 ~ 4 秒 |
| **系统融合** | 原生毛玻璃材质与系统 Panel 吸附 | 依赖 Webview 模拟 |

---

## 🛠️ 安装与构建

### 1. 快速构建与运行
在终端中进入项目目录，执行：
```bash
# 编译应用
make build

# 编译并运行
make run

# 安装到系统的“应用程序”文件夹
make install
```

构建生成的应用位于 `dist/YinxiangSideNotes.app`。

---

## 🔑 获取印象笔记 Developer Token

由于印象笔记开放平台对于个人开发者接入推荐使用开发者令牌（免去繁琐资质审核）：
1. **国内版印象笔记**：登录网页端访问 [https://app.yinxiang.com/api/DeveloperToken.action](https://app.yinxiang.com/api/DeveloperToken.action) 点击“创建开发者令牌”；
2. **国际版 Evernote**：访问 [https://www.evernote.com/api/DeveloperToken.action](https://www.evernote.com/api/DeveloperToken.action)；
3. 打开 SideNotes 偏好设置（齿轮图标），粘贴 Token 并点击“测试连接”即可！

---

## 📂 项目结构

```
yinxiang-sidenotes/
├── src/
│   ├── App/
│   │   ├── main.swift              # App 入口与生命周期
│   │   ├── SideNotesPanel.swift    # 原生无边框边缘吸附 NSPanel
│   │   ├── WindowManager.swift     # 贴边吸附算法与滑动动画控制
│   │   ├── StatusItemManager.swift # macOS 状态栏托盘管理
│   │   └── HotKeyManager.swift     # 全局热键 Cmd+Option+S 注册
│   ├── Models/
│   │   └── Models.swift            # 笔记、笔记本、设置与颜色模型
│   ├── Services/
│   │   ├── StorageManager.swift    # 本地数据持久化 (Application Support)
│   │   └── YinxiangSyncEngine.swift# 印象笔记按需轻量同步桥接引擎
│   └── UI/
│       ├── SideNotesView.swift     # 主视图 (工具栏、搜索、卡片流)
│       ├── NoteCardView.swift      # SideNotes 圆角卡片视图
│       ├── NoteEditorView.swift    # 极简 Markdown 卡片编辑器
│       ├── SettingsView.swift      # 偏好设置面板
│       └── NoteViewModel.swift     # 状态管理与数据联动
├── worker/
│   ├── sync_worker.js              # 印象笔记 Thrift/ENML 协议通信微核心
│   └── package.json
├── scripts/
│   └── build.sh                    # 原生编译打包脚本
└── Makefile
```
