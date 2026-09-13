# KSU Bundle Installer

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

文件名采用字典序处理。需要严格控制安装顺序时，建议使用 `01-xxx.zip`、`02-xxx.zip`，以及 `01-xxx.apk`、`02-xxx.apk` 这样的名称。处理顺序固定为：先所有 KSU 模块，再所有 APK，最后移动 `sdcard/` 内容。

每个内层 ZIP 必须是标准 KernelSU 模块，并且 ZIP 根目录包含 `module.prop`。脚本会校验 ZIP、模块 ID，并拒绝重复的模块 ID。

## APK 安装

APK 使用 Android Package Manager 的以下方式安装：

```text
pm install -r <apk>
```

因此会尝试保留已有应用数据并覆盖安装。APK 安装失败会终止后续流程。普通单 APK 可以直接放入 `apks/`；拆分 APK 请确保设备上的安装方式和文件组合可被 `pm` 接受。

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

如果某个内层模块或 APK 安装失败，外层安装会立即停止。此前已经成功安装的内容不会自动回滚，请修正对应文件后重新安装。

## 构建

`build.sh` 默认生成 `dist/ksu-bundle-installer.zip`。构建脚本、Git 文件和 `dist/` 目录不会被打包；`modules/`、`apks/` 和 `sdcard/` 中的内容会被打包。
