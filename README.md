# TermFlow — 跨平台四级计划与时间管理软件（Windows + Android）

支持 **日 / 周 / 月 / 学期** 四级计划联动、本地离线优先 SQLite（Drift）与 **Supabase** 多端增量双向同步（LWW + Realtime）。

---

## 一、云端 Supabase 初始化

1. 登录 [Supabase](https://supabase.com/) 创建一个新项目。
2. 打开 **SQL Editor**，将本项目中的 [`supabase/schema.sql`](./supabase/schema.sql) 全文粘贴并点击 **Run** 执行。
3. 在 **Project Settings → API** 中复制你的：
   - `Project URL` (`SUPABASE_URL`)
   - `anon public` key (`SUPABASE_ANON_KEY`)
4. 启动 TermFlow 后，进入 **设置与云端配置** 页面粘贴以上两项，点击 **保存并连接**，然后注册/登录邮箱账号即可开启多端同步。

> **离线优先**：不配置 Supabase 时所有功能 100% 本地离线可用；后续配置并登录后，离线阶段创建的数据会自动归属当前账号并推送上云。

---

## 二、开发环境准备（Windows + Android）

1. 安装 **Flutter SDK**（建议 `>= 3.24.0`）并加入系统 `PATH`，运行 `flutter doctor` 检查环境：
   ```powershell
   flutter doctor
   ```
2. **Windows 桌面端打包依赖**：安装 Visual Studio 2022（勾选 **使用 C++ 的桌面开发 / Desktop development with C++**）。
3. **Android 端打包依赖**：安装 Android Studio、Android SDK 与 Java 17，并执行：
   ```powershell
   flutter doctor --android-licenses
   ```

---

## 三、初始化原生平台壳与生成 Drift 代码

首次拉取本项目后，在 `termflow` 根目录依次执行：

```powershell
# 1. 补全 windows 与 android 原生工程目录（不会覆盖 lib/ 和 pubspec.yaml）
flutter create --platforms=windows,android --project-name=termflow --org=com.termflow .

# 2. 安装所有 Dart/Flutter 依赖
flutter pub get

# 3. 生成 Drift 本地数据库代码 (lib/data/local/app_database.g.dart)
dart run build_runner build --delete-conflicting-outputs
```

> **Android 网络权限提醒**：发布 Android Release APK 前，请确认 `android/app/src/main/AndroidManifest.xml` 的 `<manifest>` 下包含网络权限（`flutter create` 的 debug manifest 自带，但 `main/AndroidManifest.xml` 建议显式添加）：
> ```xml
> <uses-permission android:name="android.permission.INTERNET"/>
> ```

---

## 四、本地运行与双端打包命令

### 1. Windows 桌面端运行与打包 `.exe`

```powershell
# 开发调试运行
flutter run -d windows

# 打包发布版 Windows 可执行程序
flutter build windows --release
```

打包产物位于：
`build\windows\x64\runner\Release\termflow.exe`（发布分发时请将整个 `Release` 目录打包，或使用 Inno Setup / MSIX 封装为安装包）。

### 2. Android 端运行与打包 `.apk`

```powershell
# 连接手机或模拟器调试运行
flutter run -d android

# 打包通用 APK
flutter build apk --release

# 或按 CPU 架构分包（体积更小，推荐 arm64-v8a）
flutter build apk --release --split-per-abi
```

打包产物位于：
- 通用包：`build\app\outputs\flutter-apk\app-release.apk`
- 分架构包：`build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`

---

## 五、核心特性与快捷操作

- **四级目标联动**：`学期目标 (OKR) → 月度里程碑 → 周目标 → 日计划待办`，勾选完成日任务时自动沿上级链路推进完成百分比。
- **周待办一键分配到日**：在 **周计划** 页面可直接在待办池点击 `周一`~`周日` 分配到具体日期。
- **昨日未完成顺延**：在 **日计划** 顶部一键将昨日及往期未完成任务顺延至今天；Android 端支持列表 **右滑完成**、**左滑顺延 / 删除**。
- **桌面全局快捷键**：Windows 端在任意视图按 `Ctrl + N` 快速新建当前维度的任务或目标。
