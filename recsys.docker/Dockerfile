# syntax=docker/dockerfile:1

# ==================================================================
# 定义可配置的构建参数
# ==================================================================
ARG CUDA_VERSION=12.1.1
ARG CUDNN_VERSION=8
ARG UBUNTU_VERSION=22.04
ARG PYTHON_VERSION=3.10


# ==================================================================
# Stage: Single Stage Build
#
# 在此阶段，我们安装所有构建工具和依赖，编译并安装所有 Python 包，
# 并构建最终的生产镜像。
# ==================================================================
FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-devel-ubuntu${UBUNTU_VERSION}

# 声明构建参数
ARG PYTHON_VERSION

# --- 设置环境，避免交互式提示 ---
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

# --- 安装构建所需的系统依赖和 Python 运行时 ---
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    cmake \
    pkg-config \
    python3.8 \
    python3.8-venv \
    python3.9 \
    python3.9-venv \
    python3.10 \
    python3.10-venv \
    python3.11 \
    python3.11-venv \
    ca-certificates \
    locales \
    wget iputils-ping netcat openssh-client iproute2 dnsutils \
    procps htop iotop lsof tmux strace gdb \
    vim nano mc tree findutils less jq ncdu \
    zip unzip p7zip-full \
    sudo bash-completion man-db \
    && apt-get clean && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# --- 设置默认语言环境 ---
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# --- 安装并配置 uv ---
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# --- 创建并激活 Python 虚拟环境 ---
ENV VIRTUAL_ENV=/opt/venv
RUN python3.11 -m venv ${VIRTUAL_ENV}
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

# --- 确保动态链接库能被找到 ---
ENV LD_LIBRARY_PATH="${VIRTUAL_ENV}/lib/python3.11/site-packages/tensorrt_libs:${LD_LIBRARY_PATH}"

# --- 使用 uv 高效安装所有 Python 包 ---
# 拷贝需求文件并一次性安装，以充分利用 Docker 的层缓存机制
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
