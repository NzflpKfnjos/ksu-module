# KSU Bundle Installer
123
这是一个 KernelSU 聚合安装模块。安装外层模块时，它会按顺序完成以下操作：

1. 依次安装 `modules/` 目录中的 KernelSU 模块。
2. 依次安装 `apks/` 目录中的 APK 应用。
3. 将 `sdcard/` 目录中的文件和文件夹移动到手机的 `/sdcard/`，并保留相对目录结构。

## 目录结构

```text
ksu-module/
├── modules/       # 放需要安装的 KSU 模块 ZIP
│   ├── 01-module.zip
│   └── 02-module.zip
├── apks/          # 放需要安装的 APK
│   ├── 01-app.apk
│   └── 02-app.apk
├── sdcard/        # 放需要移动到手机 /sdcard/ 的文件或文件夹
│   ├── Download/
│   └── Documents/
└── build.sh
```

三个目录已经预创建。构建时至少需要在其中一个目录放入有效内容。

## 使用

1. 将需要安装的 KSU 模块 ZIP 放入 `modules/`。
2. 将需要安装的 APK 放入 `apks/`。
3. 将需要复制到手机存储的文件放入 `sdcard/`。
4. 执行：

   ```sh
   sh build.sh
   ```

5. 在 KernelSU 管理器中安装生成的 `dist/ksu-bundle-installer.zip`。
6. 等待安装日志完成后重启设备，使 KSU 模块生效。

## 在 KernelSU 中远程更新

外层模块的 `module.prop` 已声明 `updateJson`，KernelSU 管理器会从该地址检查版本。`update.json` 由 GitHub Actions 自动生成；`versionCode` 必须比设备当前安装版本大，管理器才会显示更新。该文件是公开文件，不要在 URL 中放置令牌或私密信息。

## 自动发布 GitHub 更新

仓库已配置 `.github/workflows/release.yml`。每次提交推送到 `main` 分支时（包括只修改 `README.md`），GitHub Actions 都会自动执行构建并创建一个 GitHub Release。版本号和 `versionCode` 由工作流自动生成，标签格式为 `v版本号`。

发布新版本时不需要修改版本字段，直接提交代码即可：

```properties
git add .
git commit -m "update: 调整模块内容"
git push origin main
```

工作流会在构建时临时更新 ZIP 内的 `module.prop`，并把最新的 `update.json` 自动提交回仓库。由于 `module.prop` 的 `updateJson` 指向 GitHub Raw 地址，提交完成后 KernelSU 管理器即可读取最新更新信息。

文件名采用字典序处理。需要严格控制普通模块和 APK 的顺序时，建议使用 `01-xxx.zip`、`02-xxx.zip`，以及 `01-xxx.apk`、`02-xxx.apk` 这样的名称。正常处理顺序为：先所有 KSU 模块，再所有 APK，最后移动 `sdcard/` 内容。模块 ID 为 `m_rcq` 的模块会被特殊延迟到全部模块、APK 和 `/sdcard/` 文件操作完成后再安装，即使它的文件名较早也会保持最后安装。

每个内层 ZIP 必须是标准 KernelSU 模块，并且 ZIP 根目录包含 `module.prop`。脚本会校验 ZIP、模块 ID，并拒绝重复的模块 ID。

## APK 安装

APK 使用手机上的 `su` 提权，并通过 KernelSU 的全局 mount namespace 直接调用 Android 的 `cmd package` 服务，实际执行方式为：

```text
su -M -c "/system/bin/cmd package install -r /data/local/tmp/ksu-bundle-apks/apk-N.apk"
```

这里使用 `cmd package` 而不是 `pm`。部分 KernelSU LKM / Android 设备在 `su` 会话中执行 `pm` 时会出现：

```text
cmd: Failure calling service package: Failed transaction (2147483646)
```

`pm` 本身只是一个 Shell 包装脚本，直接调用 `cmd package` 可以绕过这个问题；`-M` 用于让命令进入全局 mount namespace，使 PackageManager 能够访问安装文件。

脚本会先把 APK 临时复制到 `/data/local/tmp/ksu-bundle-apks/`，设置可读权限和 `shell_data_file` SELinux 标签，再通过 `su -M -> cmd package -> PackageManager` 安装，安装成功后删除临时文件。这样可以避免 PackageManager 直接读取模块暂存目录时遇到权限或 SELinux 问题。安装失败时会把 `cmd package` 的错误输出和退出码显示在安装日志中，并跳过该 APK 继续处理后续 APK。

因此会尝试保留已有应用数据并覆盖安装。APK 安装失败会跳过当前 APK，继续后续流程。普通单 APK 可以直接放入 `apks/`；拆分 APK 请确保设备上的安装方式和文件组合可被 `cmd package` 接受。

## `/sdcard/` 文件移动

例如目录中存在：

```text
sdcard/Download/file.zip
sdcard/Documents/readme.txt
```

安装后会得到：

```text
/sdcard/Download/file.zip
/sdcard/Documents/readme.txt
```

目标目录不存在时会自动创建。如果目标位置已经存在同名文件，脚本会覆盖它；如果文件和目录类型冲突，则安装失败。由于模块目录和 `/sdcard/` 可能不在同一个文件系统，脚本使用“复制成功后删除源文件”的方式实现可靠移动。

## 行为说明

内层模块会作为独立 KernelSU 模块安装，因此各自的 `customize.sh`、`service.sh`、`post-fs-data.sh`、`uninstall.sh` 等脚本仍会正常保留和执行。外层模块只负责本次批量安装，不会在卸载外层模块时删除已经安装的内层模块；如需删除内层模块，请在 KernelSU 管理器中分别操作。

如果某个内层模块安装失败，外层安装会立即停止；APK 安装失败则会跳过当前 APK 并继续。此前已经成功安装的内容不会自动回滚，请修正对应文件后重新安装。

## 构建

`build.sh` 默认生成 `dist/ksu-bundle-installer.zip`。构建脚本、Git 文件和 `dist/` 目录不会被打包；`modules/`、`apks/` 和 `sdcard/` 中的内容会被打包。
