# KakaADB (卡卡ADB) v3
> iOS 无线 ADB 管理工具 —— 深度对标 Scarab（甲壳虫），ADB 引擎打包原生 adb 客户端

## 特性

- **原生 ADB 引擎**：内置 `adb-mobile`（AOSP adb 35.0.2 移植，Scarab 同款），非纯 Swift 协议实现
- **连接**：WiFi 经典模式（IP + 端口）与 Android 11+ 无线调试配对（IP + 配对码）
- **首页**：设备状态卡（型号 / IP / 电量 / 连接状态）+ 快捷操作 + 最近操作
- **应用管理**：应用列表 / 搜索 / 系统应用徽标 / 安装 APK / 卸载 / 清除数据 / 强制停止
- **文件管理**：路径导航 / 快捷入口（根目录、存储、下载、音乐、图片）/ 上传 / 下载 / 重命名 / 删除 / 新建文件夹 / 图片保存到相册
- **命令中心**：四大分类 30+ 快捷命令（重启、关机、Recovery、Fastboot、深浅色、WiFi、移动数据、分辨率密度、CPU/内存/存储/电池、Ping、logcat）+ 自定义命令 + 参数输入
- **Shell 终端**：自由命令执行
- **电视遥控**：ADB 键码遥控（电源 / 方向键 / 音量 / 频道 / 数字键）
- **操作历史**：今天 / 昨天分组、类型筛选、状态跟踪
- **设置**：自动连接、保持连接、主题、语言、清空历史、恢复默认、帮助中心
- **Pro 界面**：对标 Scarab Pro（侧载版本地解锁全部功能，无内购）

## 架构

```
KakaADB/
├── adb-mobile/            # 原生 ADB 引擎（git submodule，AOSP adb 35.0.2 移植）
│   └── output/            # CI 构建产物：libadb.a + include/（adb_public.h）
├── KakaADB/
│   ├── ADBEngine.swift    # Swift 封装 adb_commandline_porting()，串行队列执行
│   ├── AdbCallback.m      # 连接状态回调（弱符号覆盖 → NotificationCenter）
│   ├── Services.swift     # 会话 / 连接 / 设备信息
│   ├── AppManager.swift   # 应用管理
│   ├── FileService.swift  # 文件管理
│   ├── CommandCenter.swift# 命令中心 / 截图录屏 / 遥控
│   ├── Stores.swift       # 设置 / 操作历史
│   └── Views/             # SwiftUI 界面（6 Tab）
└── .github/workflows/build.yml  # 自动构建 unsigned IPA（TrollStore 可用）
```

## 构建

本地需要 macOS + Xcode；或直接推送到 GitHub 由 Actions 自动构建：

```bash
# 1. 拉取子模块（含 adb-mobile 及其依赖）
git submodule update --init --recursive

# 2. 构建 libadb（需要 protoc 28.3、cmake、fmt 等，见 workflow）
make -C adb-mobile
cp adb-mobile/output/iphoneos/arm64/libadb-full.a adb-mobile/output/libadb.a

# 3. 生成工程并构建
xcodegen generate
xcodebuild -project KakaADB.xcodeproj -scheme KakaADB \
  -configuration Release -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build

# 4. 打包
mkdir -p Payload && cp -R "build/Build/Products/Release-iphoneos/KakaADB.app" Payload/
zip -r KakaADB.ipa Payload
```

## 安装

- **TrollStore**：直接安装未签名 IPA
- **自签**：AltStore / Sideloadly 等工具签名后安装
- 首次使用请在 Android 设备开启「开发者选项 → USB 调试 / 无线调试」

## 致谢

- ADB 引擎：`wsvn53/adb-mobile`（AOSP adb 移植）
- UI 设计深度参考：Scarab（甲壳虫）iOS ADB 工具
