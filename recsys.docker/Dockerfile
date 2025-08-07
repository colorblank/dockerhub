# syntax=docker/dockerfile:1

# ==================================================================
# 定义可配置的构建参数
# ==================================================================
ARG CUDA_VERSION=12.1.1
ARG CUDNN_VERSION=8
ARG UBUNTU_VERSION=22.04
ARG PYTHON_VERSION=3.10


# ==================================================================
# Stage 1: Builder
#
# 在此阶段，我们安装所有构建工具和依赖，编译并安装所有 Python 包。
# 这个阶段会比较大，但其内容不会进入最终的镜像。
# ==================================================================
FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder

# 声明构建参数
ARG PYTHON_VERSION

# --- 设置环境，避免交互式提示 ---
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

# --- 安装构建所需的系统依赖 ---
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    cmake \
    pkg-config \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- 安装并配置 uv ---
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# --- 创建并激活 Python 虚拟环境 ---
ENV VIRTUAL_ENV=/opt/venv
RUN python${PYTHON_VERSION} -m venv ${VIRTUAL_ENV}
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

# --- 使用 uv 高效安装所有 Python 包 ---
# 拷贝需求文件并一次性安装，以充分利用 Docker 的层缓存机制
COPY requirements.in .
RUN uv compile requirements.in -o requirements.txt
RUN uv pip install --no-cache-dir -r requirements.txt


# ==================================================================
# Stage 2: Final Image
#
# 这是最终的生产镜像。它基于更小的 CUDA runtime 镜像，
# 并且只从 builder 阶段拷贝必要的虚拟环境和 uv 工具。
# ==================================================================
FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

# 声明构建参数
ARG PYTHON_VERSION

# --- 设置环境 ---
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    VIRTUAL_ENV=/opt/venv \
    # 确保动态链接库能被找到
    LD_LIBRARY_PATH="${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/tensorrt_libs:${LD_LIBRARY_PATH}"

# --- 安装 Python 运行时和所有增强的系统工具 ---
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Python
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    # Base
    ca-certificates \
    locales \
    # Version Control
    git \
    # Networking
    curl wget iputils-ping net-tools dnsutils openssh-client \
    # Monitoring
    procps htop iotop lsof \
    # File & Editing
    vim nano mc tree findutils \
    # Compression
    zip unzip p7zip-full \
    # User & Shell
    sudo bash-completion man-db \
    && apt-get clean && \
    # 生成并设置 locale，防止编码问题
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# --- 设置默认语言环境 ---
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# --- 从 builder 阶段拷贝虚拟环境和 uv ---
COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}
COPY --from=builder /root/.local/bin/uv /usr/local/bin/uv

# --- 将虚拟环境的 bin 目录添加到 PATH，使其成为默认环境 ---
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

# --- 设置工作目录 ---
WORKDIR /app

# --- 默认启动命令为 bash ---
CMD ["bash"]
