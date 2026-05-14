# LetsWorkout 开发调试指南

## 一、首次配置开发环境

以下步骤只需执行一次。

### 1.1 系统要求

| 项目 | 最低要求 |
|------|----------|
| macOS | 12.0 Monterey+ |
| Xcode | 14.0+（从 App Store 安装） |
| iPhone（可选） | iOS 16+，真机调试用 |

### 1.2 安装命令行工具

打开终端，依次执行：

```bash
# 安装 Homebrew（如已安装跳过）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 XcodeGen（从 project.yml 生成 Xcode 项目）
brew install xcodegen

# 安装 CocoaPods（管理 MediaPipe 依赖）
brew install cocoapods
```

验证安装：
```bash
xcodegen --version    # 应输出版本号，如 2.45.4
pod --version         # 应输出版本号，如 1.16.2
```

### 1.3 生成项目并安装依赖

```bash
# 进入项目目录
cd ~/letsworkout

# 从 project.yml 生成 Xcode 项目文件
xcodegen generate

# 安装 CocoaPods 依赖（MediaPipe）
pod install
```

成功后目录下会出现：
- `LetsWorkout.xcodeproj` — Xcode 项目文件
- `LetsWorkout.xcworkspace` — Xcode 工作空间（**日常必须打开这个**）
- `Pods/` — 第三方依赖

### 1.4 准备测试资源

#### 测试视频（必须，否则算法无输出）

准备 1~2 段健身动作视频（mp4 格式，竖屏，拍摄全身动作）：

| 文件名 | 用途 | 必须？ |
|--------|------|--------|
| `reference_workout.mp4` | 参考教练视频（模拟主播） | 是 |
| `user_workout.mp4` | 模拟用户摄像头输入（模拟器用） | 模拟器调试时需要 |

放入方法：
1. 打开 `LetsWorkout.xcworkspace`
2. 在 Xcode 左侧项目导航中，右键 `LetsWorkout` 文件夹 → Add Files to "LetsWorkout"
3. 选择视频文件，**勾选 "Add to targets: LetsWorkout"** → Add

#### MediaPipe 模型文件（接入姿态检测时需要）

当前 PoseEstimator 为 placeholder 骨架代码，暂时不需要模型文件。待正式接入时：

1. 下载：https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task
2. 同样拖入 Xcode，勾选 Add to targets: LetsWorkout
3. 确保文件名为 `pose_landmarker_lite.task`

---

## 二、首次启动项目

### 2.1 打开项目

```bash
open ~/letsworkout/LetsWorkout.xcworkspace
```

> 注意：必须打开 `.xcworkspace`，不是 `.xcodeproj`，否则 CocoaPods 依赖找不到。

### 2.2 选择运行目标

在 Xcode 顶部工具栏：
- **Scheme** 选择 `LetsWorkout`（不是 BroadcastExtension）
- **设备** 选择：
  - 模拟器：`iPhone 15`（或任意 iOS 16+ 模拟器）
  - 真机：你的 iPhone 名称（需 USB 连接）

### 2.3 模拟器启动（推荐，免费无门槛）

直接按 `Cmd + R` 即可编译运行。

首次编译较慢（约 1~3 分钟，需编译 MediaPipe 依赖），后续增量编译很快。

App 启动后：
1. 看到首页 → 显示"模拟器模式"标签
2. 点击"选择参考视频" → 选一段视频（或跳过使用内置）
3. 点击"开始跟练" → 进入跟练界面
4. 看到评分仪表盘和计时器正常工作即为成功

### 2.4 真机启动（需付费开发者账号）

#### 配置签名（首次）

1. Xcode 左侧选中项目 → TARGETS → `LetsWorkout`
2. Signing & Capabilities → Team 选择你的 Apple Developer 账号
3. 如果 Bundle Identifier 冲突，改为唯一值如 `com.yourname.letsworkout`
4. 切到 TARGETS → `BroadcastExtension`，重复签名（Bundle ID 用 `com.yourname.letsworkout.broadcast`）
5. 确认两个 Target 的 App Groups 中都有 `group.com.letsworkout.shared`

#### 连接设备并运行

1. USB 线连接 iPhone 到 Mac
2. iPhone 弹出"信任此电脑？" → 点击信任
3. 等待 Xcode 准备设备（首次可能 5~10 分钟，状态栏显示 "Preparing iPhone"）
4. 设备就绪后，`Cmd + R` 运行

#### 信任开发者证书（首次安装后）

App 安装后打不开，iPhone 上操作：
> 设置 → 通用 → VPN与设备管理 → 找到开发者 App → 点击"信任"

---

## 三、日常开发：代码改动后如何运行

### 3.1 仅修改了 Swift 代码（最常见）

无需任何额外操作，直接：

```
Cmd + R    运行（自动增量编译）
Cmd + B    仅编译不运行（检查语法错误）
```

Xcode 会自动检测文件变化并增量编译。

### 3.2 新增或删除了 Swift 文件

因为项目用 XcodeGen 管理，新增/删除文件后需重新生成：

```bash
# 终端执行
xcodegen generate
```

然后回到 Xcode，它会自动检测到项目变化并刷新。继续 `Cmd + R` 即可。

> 如果 Xcode 弹出"project.pbxproj has been modified"提示 → 点 "Revert"

### 3.3 修改了 Podfile（添加/更新依赖）

```bash
pod install
```

然后重新打开 workspace（通常 Xcode 会自动刷新，如果没有就关闭重开）。

### 3.4 修改了 project.yml（项目配置变更）

```bash
xcodegen generate
```

如果同时改了 Podfile：
```bash
xcodegen generate && pod install
```

### 3.5 操作速查表

| 改了什么 | 执行什么 | 然后 |
|----------|----------|------|
| Swift 代码 | 不需要额外操作 | `Cmd + R` |
| 新增/删除 .swift 文件 | `xcodegen generate` | `Cmd + R` |
| Podfile | `pod install` | `Cmd + R` |
| project.yml | `xcodegen generate` | `Cmd + R` |
| project.yml + Podfile | `xcodegen generate && pod install` | `Cmd + R` |
| Info.plist / Entitlements | `xcodegen generate` | `Cmd + R` |
| 添加资源文件（视频/图片/模型） | 在 Xcode 中 Add Files 并勾选 Target | `Cmd + R` |

---

## 四、运行模式说明

项目自动检测运行环境，切换不同模式：

### 模拟器模式

```
触发条件：在模拟器上运行（自动检测）
参考源：Bundle 内视频文件 reference_workout.mp4
用户源：Bundle 内视频文件 user_workout.mp4（或静态占位图）
可用功能：UI、算法 pipeline、评分、TTS 语音、CoreData 存储
不可用：真实摄像头、PiP 画中画、ReplayKit 录屏
```

### 真机模式

```
触发条件：在真机上运行（自动检测）
参考源：用户从相册选择视频，或 Bundle 内置视频
用户源：前置摄像头实时画面
可用功能：全部功能
```

---

## 五、常见问题排查

### 编译报错 "No such module 'MediaPipeTasksVision'"

**原因**：打开了 `.xcodeproj` 而不是 `.xcworkspace`

**解决**：
```bash
open LetsWorkout.xcworkspace
```

### 编译报错 "framework not found Pods_LetsWorkout"

**原因**：Pods 未正确安装

**解决**：
```bash
pod deintegrate
pod install
```

### 模拟器运行后白屏或闪退

**排查步骤**：
1. 查看 Xcode 底部 Console 输出的错误信息
2. 确认 Scheme 选的是 `LetsWorkout`（不是 BroadcastExtension）
3. Clean Build：`Cmd + Shift + K`，然后重新 `Cmd + R`

### 真机报错 "Signing requires a development team"

每个 Target 都需要配置签名：
- `LetsWorkout` Target → Signing → 选 Team
- `BroadcastExtension` Target → Signing → 选 Team

### 真机报错 "A valid provisioning profile for this executable was not found"

**原因**：证书过期或 Bundle ID 冲突

**解决**：
1. Xcode → Preferences → Accounts → 刷新证书
2. 修改 Bundle Identifier 为唯一值

### App 运行但评分始终为 0

**原因**：
- 没有放入测试视频（无参考数据）
- PoseEstimator 当前为 placeholder（尚未接入 MediaPipe 模型）

**解决**：放入 `reference_workout.mp4`，接入模型后即可产生真实评分。

### xcodegen generate 报错

**排查**：
```bash
# 验证 project.yml 语法
xcodegen dump 2>&1 | head -20
```

确保 project.yml 没有缩进错误或非法字符。

---

## 六、有用的快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd + R` | 编译并运行 |
| `Cmd + B` | 仅编译 |
| `Cmd + .` | 停止运行 |
| `Cmd + Shift + K` | Clean Build |
| `Cmd + Shift + O` | 快速打开文件 |
| `Cmd + Click` | 跳转到定义 |
| `Cmd + 0` | 显示/隐藏左侧导航 |

---

## 七、项目结构

```
letsworkout/
├── project.yml                  # XcodeGen 项目定义
├── Podfile                      # CocoaPods 依赖声明
├── LetsWorkout.xcworkspace      # ← 日常打开这个
├── LetsWorkout/                 # 主 App 源码
│   ├── App/                     #   应用入口
│   ├── Video/                   #   视频帧读取（参考视频 + 模拟摄像头）
│   ├── Camera/                  #   真机前置摄像头采集
│   ├── Pose/                    #   MediaPipe 姿态检测封装
│   ├── Algorithm/               #   动作比对算法（归一化、DTW、评分）
│   ├── PiP/                     #   画中画保活
│   ├── Session/                 #   会话状态机 + 核心协调器
│   ├── UI/                      #   SwiftUI 界面
│   ├── Storage/                 #   CoreData 数据持久化
│   ├── Feedback/                #   语音 TTS 反馈
│   ├── Performance/             #   设备检测 + 散热管理
│   └── IPC/                     #   Extension 帧通信（完整模式）
├── BroadcastExtension/          # 录屏扩展（完整模式，需付费账号）
├── Shared/                      # 双 Target 共享代码
└── Pods/                        # 第三方依赖（自动生成，不要手动修改）
```
