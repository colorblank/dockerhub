# dockerhub

这是一个包含多个 Docker 镜像定义的仓库，旨在提供预配置的、针对特定用例优化的容器环境。目前包含以下服务：

-   **Plex Media Server**: 基于 Arch Linux，支持 Intel DG1 硬件加速和色调映射。
-   **TensorFlow Serving**: 基于 Ubuntu 22.04，支持 HDFS 模型加载，并采用多阶段构建以减小镜像体积。

## 1. Plex Media Server (plex.docker)

此 Docker 镜像提供了一个基于 Arch Linux 的 Plex Media Server 实例，特别优化了对 Intel DG1 显卡的硬件加速支持，包括 VA-API 视频解码/编码和 OpenCL 色调映射。

### 特性

-   **基础镜像**: `archlinux:latest`
-   **硬件加速**: 内置 `intel-media-driver` 和 `intel-compute-runtime`，为 Intel DG1 显卡提供 VA-API 和 OpenCL 支持。
-   **FFmpeg**: 包含最新版 FFmpeg，用于媒体处理。
-   **精简**: 通过清理 pacman 缓存，保持镜像体积较小。

### 使用方法

#### 构建镜像

```bash
docker build -t your-repo/plex-media-server:latest ./plex.docker
```

#### 运行容器

为了启用硬件加速和持久化数据，您需要挂载设备和卷。

```bash
docker run -d \
  --name plex \
  --network host \
  --restart unless-stopped \
  --device /dev/dri:/dev/dri \
  -v /path/to/your/plex/config:/config \
  -v /path/to/your/media:/data \
  -v /path/to/your/transcode:/transcode \
  -e PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="/config" \
  your-repo/plex-media-server:latest
```

**参数说明**:

-   `-d`: 后台运行容器。
-   `--name plex`: 为容器指定名称。
-   `--network host`: 使用主机网络，简化端口映射（Plex 需要多个端口）。
-   `--restart unless-stopped`: 容器退出时自动重启，除非手动停止。
-   `--device /dev/dri:/dev/dri`: **关键**，将主机的 `/dev/dri` 设备（包含 Intel GPU 设备文件）挂载到容器内，以启用硬件加速。
-   `-v /path/to/your/plex/config:/config`: 挂载 Plex 配置目录，用于持久化设置和元数据。
-   `-v /path/to/your/media:/data`: 挂载您的媒体文件目录。
-   `-v /path/to/your/transcode:/transcode`: 挂载转码临时目录。
-   `-e PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="/config"`: 设置 Plex 应用程序支持目录。

**Plex 端口**:

Plex Media Server 使用以下端口：

-   `32400/tcp`: 主 Web 界面和 API
-   `3005/tcp`: Plex Companion
-   `8324/tcp`: Plex for Roku
-   `32469/tcp`: DLNA
-   `1900/udp`: GDM (Plex Discovery)
-   `32410/udp`, `32412/udp`, `32413/udp`, `32414/udp`: GDM

由于使用了 `--network host`，这些端口将直接在主机上暴露。

## 2. TensorFlow Serving (tfs.docker)

此 Docker 镜像提供了一个基于 Ubuntu 22.04 的 TensorFlow Serving 实例，支持从 HDFS 加载模型，并采用多阶段构建以生成一个轻量级的运行时镜像。

### 特性

-   **基础镜像**: `ubuntu:22.04`
-   **多阶段构建**: 分为 `builder` 和 `final` 两个阶段，确保最终镜像只包含必要的运行时组件，减小体积。
-   **TensorFlow Serving 版本**: `2.18.0` (可配置)。
-   **HDFS 支持**: 内置 Hadoop 客户端，支持从 HDFS 加载模型。
-   **Python 环境**: 包含 Python 3.10 及必要的库，用于模型同步脚本。
-   **模型同步**: `entrypoint.sh` 脚本会在启动 TensorFlow Serving 之前，在后台运行一个 HDFS 模型同步守护进程 (`sync.py`，需自行提供)。

### 使用方法

#### 构建镜像

```bash
docker build -t your-repo/tensorflow-serving:latest ./tfs.docker
```

您可以通过 `TF_SERVING_BUILD_OPTIONS` 和 `TF_SERVING_BAZEL_OPTIONS` ARG 参数来定制构建过程，例如：

```bash
docker build \
  --build-arg TF_SERVING_BUILD_OPTIONS="--config=opt" \
  --build-arg TF_SERVING_BAZEL_OPTIONS="--jobs=4" \
  -t your-repo/tensorflow-serving:latest ./tfs.docker
```

#### 运行容器

```bash
docker run -d \
  --name tf-serving \
  -p 8500:8500 \
  -p 8501:8501 \
  -v /path/to/your/local/models:/models \
  -e MODEL_NAME="my_model" \
  -e MODEL_BASE_PATH="/models" \
  your-repo/tensorflow-serving:latest
```

**参数说明**:

-   `-d`: 后台运行容器。
-   `--name tf-serving`: 为容器指定名称。
-   `-p 8500:8500`: 映射 gRPC 端口。
-   `-p 8501:8501`: 映射 REST API 端口。
-   `-v /path/to/your/local/models:/models`: 挂载本地模型目录到容器内的 `/models`。
-   `-e MODEL_NAME="my_model"`: 设置要加载的模型名称。
-   `-e MODEL_BASE_PATH="/models"`: 设置模型的基础路径。

**HDFS 模型加载**:

如果您需要从 HDFS 加载模型，您需要确保 Hadoop 相关的环境变量和配置正确设置。`entrypoint.sh` 会自动设置 `CLASSPATH`。您还需要在容器内提供 `sync.py` 脚本，该脚本负责将 HDFS 上的模型同步到本地文件系统（例如 `/models` 目录），以便 TensorFlow Serving 可以加载它们。

**注意**: `sync.py` 脚本未包含在此仓库中，您需要根据您的 HDFS 环境和模型同步逻辑自行创建并添加到镜像中。

## 3. GitHub Actions

本仓库包含一个 GitHub Actions 工作流 (`.github/workflows/docker-publish.yml`)，用于自动化 Docker 镜像的构建和发布过程。该工作流通常会在代码推送到特定分支时触发，自动构建 `plex.docker` 和 `tfs.docker` 镜像并推送到配置的 Docker 镜像仓库。
