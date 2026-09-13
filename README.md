# KSU Bundle Installer

这是一个 KernelSU 聚合安装模块。安装这个外层模块时，它会按照压缩包文件名的排序顺序，依次调用 KernelSU 官方安装入口安装内层模块。

## 使用

1. 将要安装的 KernelSU 模块压缩包放在本目录根目录，例如 `1.zip`、`2.zip`、`3.zip`。也可以放进 `packages/` 目录。
2. 执行 `sh build.sh`，生成 `dist/ksu-bundle-installer.zip`。
3. 在 KernelSU 管理器中安装 `dist/ksu-bundle-installer.zip`。
4. 等所有安装日志显示成功后重启设备，使模块生效。

压缩包按文件名字典序处理。因此需要严格控制顺序时，建议使用 `01.zip`、`02.zip`、`03.zip` 这样的名称。每个内层压缩包都必须是标准 KernelSU 模块，并且根目录包含 `module.prop`。

## 行为说明

内层模块会作为独立模块安装到 KernelSU 中，因此各自的 `customize.sh`、`service.sh`、`post-fs-data.sh`、`uninstall.sh` 等脚本都会正常保留和执行。外层模块只负责本次批量安装，不会在卸载外层模块时删除已经安装的内层模块；如需删除内层模块，请在 KernelSU 管理器中分别操作。

如果某个内层模块安装失败，外层安装会立即停止，并保留之前已经成功提交的内层模块。修正对应压缩包后可以重新安装整个聚合包。

## 构建

`build.sh` 默认把产物放到 `dist/`，因此不会把上一次构建的外层压缩包再次打进新包。构建脚本、Git 文件和 `dist/` 目录不会被打包；根目录或 `packages/` 目录中的内层 `.zip` 文件会被打包。
