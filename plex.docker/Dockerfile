# 使用最新的 Arch Linux 作为基础镜像
FROM archlinux:latest

# 作者和标签
LABEL author="Gemini"
LABEL description="Plex Media Server on Arch Linux with Intel DG1 Hardware Acceleration"

# 设置环境变量，避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 初始化 pacman 并安装核心依赖、Intel 驱动和 FFmpeg
RUN \
    # 1. 初始化 pacman keyring
    pacman-key --init && \
    pacman-key --populate archlinux && \
    
    # 2. 更新软件源并升级系统
    pacman -Syu --noconfirm && \
    
    # 3. 安装基础工具、Intel 最新驱动和 FFmpeg
    #    - intel-media-driver: 最新VA-API驱动，支持DG1
    #    - intel-compute-runtime: OpenCL驱动，用于色调映射 (Tone Mapping)
    #    - libva-utils: 提供 vainfo 工具用于验证
    #    - intel-gpu-tools: 提供 intel_gpu_top 工具用于监控
    #    - wget, tar: 用于下载和解压 Plex
    pacman -S --noconfirm \
        intel-media-driver \
        intel-compute-runtime \
        libva-utils \
        intel-gpu-tools \
        ffmpeg \
        wget \
        tar \
        sudo && \
    
    # 4. 清理 pacman 缓存，减小镜像体积
    pacman -Scc --noconfirm

# 安装 Plex Media Server
RUN \
    # 1. 从 Plex 官网获取最新的 64-bit Ubuntu/Debian 版本下载链接
    PLEX_URL=$(wget -qO- "https://plex.tv/api/downloads/5.json" | grep -oP 'https://downloads.plex.tv/plex-media-server-new/.*/plexmediaserver_.*_amd64.deb' | head -n 1) && \
    echo "Downloading Plex from: ${PLEX_URL}" && \
    
    # 2. 下载 .deb 包
    wget -qO plex.deb "${PLEX_URL}" && \
    
    # 3. 创建临时目录并解压 .deb 包的数据
    mkdir -p /tmp/plex-install && \
    tar -xf plex.deb -C /tmp/plex-install data.tar.xz && \
    tar -xf /tmp/plex-install/data.tar.xz -C / && \
    
    # 4. 清理下载和临时文件
    rm -rf plex.deb /tmp/plex-install

# 创建 plex 用户和组，并设置目录权限
RUN \
    groupadd -g 1000 plex && \
    useradd -u 1000 -g plex -m -s /bin/bash plex && \
    # 创建 Plex 需要的目录
    mkdir -p /config /data /transcode && \
    # 将目录所有权交给 plex 用户
    chown -R plex:plex /config /data /transcode && \
    # 将 Plex 的库目录所有权也交给 plex 用户
    chown -R plex:plex /usr/lib/plexmediaserver

# 设置环境变量，让 Plex 知道配置文件在哪里
ENV PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="/config"

# 暴露 Plex 服务端口
# 32400: 主Web界面、API
# 3005: Plex Companion
# 8324: Plex for Roku
# 32469: DLNA
# 1900/UDP: GDM (Plex Discovery)
# 32410/UDP, 32412/UDP, 32413/UDP, 32414/UDP: GDM
EXPOSE 32400/tcp 3005/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp

# 定义挂载点，用于持久化存储
VOLUME ["/config", "/data", "/transcode"]

# 切换到 plex 用户
USER plex

# 设置容器启动命令
# 使用 `exec` 确保 Plex 进程是 PID 1，以便正确处理信号
CMD ["/bin/sh", "-c", "exec /usr/lib/plexmediaserver/Plex\\ Media\\ Server"]