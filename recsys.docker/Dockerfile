# syntax=docker/dockerfile:1

# ==================================================================
# 定义可配置的构建参数
# ==================================================================
# 默认使用 Python 3.10，与 Ubuntu 22.04 的官方默认版本保持一致
ARG PYTHON_VERSION=3.10
ARG CUDA_VERSION=12.1.1
ARG CUDNN_VERSION=8
ARG UBUNTU_VERSION=22.04


# ==================================================================
# Stage: Single Stage Build
#
# 优化点:
# 1. 澄清: uv 不安装 Python 解释器，因此我们仍需使用 apt。
# 2. 动态化: 使用 `update-alternatives` 将 ARG 指定的 Python 版本设为全局默认。
# 3. 灵活性: 动态设置 PATH 和 LD_LIBRARY_PATH，以匹配 PYTHON_VERSION。
# 4. 效率: 合并 RUN 指令以减少镜像层。
# ==================================================================
FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-devel-ubuntu${UBUNTU_VERSION}

# 声明构建参数, 以便在后续指令中使用
ARG PYTHON_VERSION

# --- 设置环境，避免交互式提示并配置默认语言 ---
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# --- 安装系统依赖、多版本 Python 和常用工具 ---
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # --- 构建工具 ---
    git curl build-essential cmake pkg-config \
    # --- 多版本 Python 运行时 (uv 创建虚拟环境时需要) ---
    # 添加 -dev 包以支持需要编译的 Python 模块
    python3.8 python3.8-dev python3.8-venv \
    python3.9 python3.9-dev python3.9-venv \
    python3.10 python3.10-dev python3.10-venv \
    python3.11 python3.11-dev python3.11-venv \
    python3.12 python3.12-dev python3.12-venv \
    # --- 基础工具和调试工具 ---
    ca-certificates locales wget iputils-ping netcat openssh-client iproute2 dnsutils \
    procps htop iotop lsof tmux strace gdb \
    vim nano mc tree findutils less jq ncdu \
    zip unzip p7zip-full \
    sudo bash-completion man-db && \
    # --- 设置指定的 Python 版本为全局默认 ---
    # 格式: update-alternatives --install <链接> <名称> <路径> <优先级>
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 80 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 90 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 100 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 110 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 120 && \
    # 将 ARG 指定的版本设为默认
    update-alternatives --set python3 /usr/bin/python${PYTHON_VERSION} && \
    # --- 设置语言环境 ---
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    # --- 清理 apt 缓存 ---
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- 安装并配置 uv ---
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# --- 在单个 RUN 指令中创建所有 Python 虚拟环境 ---
RUN uv venv --python python3.8 /opt/venv_py38 && \
    uv venv --python python3.9 /opt/venv_py39 && \
    uv venv --python python3.10 /opt/venv_py310 && \
    uv venv --python python3.11 /opt/venv_py311 && \
    uv venv --python python3.12 /opt/venv_py312

# --- 激活由 ARG 指定的默认 Python 虚拟环境 ---
# 使用 ARG 动态设置路径，而非硬编码 '3.11'
# `${PYTHON_VERSION//./}` 会将 '3.10' 转换为 '310'
ENV VENV_PATH="/opt/venv_py${PYTHON_VERSION//./}"
ENV PATH="${VENV_PATH}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${VENV_PATH}/lib/python${PYTHON_VERSION}/site-packages/tensorrt_libs:${LD_LIBRARY_PATH}"

# --- 使用 uv 高效安装所有 Python 包到默认虚拟环境中 ---
COPY requirements.in .
RUN uv pip compile requirements.in -o requirements.txt && \
    uv pip install --no-cache-dir -r requirements.txt

# --- 设置工作目录 ---
WORKDIR /app

# --- 拷贝启动脚本并设置权限 ---
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# --- 设置容器启动命令 ---
ENTRYPOINT ["/usr/local/bin/start.sh"]