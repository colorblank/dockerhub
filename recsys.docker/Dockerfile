# syntax=docker/dockerfile:1

# ==================================================================
# 定义可配置的构建参数
# ==================================================================
ARG PYTHON_VERSION=3.10
ARG CUDA_VERSION=12.1.1
ARG CUDNN_VERSION=8
ARG UBUNTU_VERSION=22.04

# ==================================================================
# Stage 1: builder (Corrected)
# ==================================================================
FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder

# 声明构建参数
ARG PYTHON_VERSION

# 设置环境
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

# FIX: 添加 'deadsnakes' PPA 以获取所有 Python 版本
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    git curl build-essential cmake pkg-config \
    "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" \
    ca-certificates \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装 uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# 定义目标虚拟环境的路径
ARG VENV_PATH="/opt/venv"

# 创建虚拟环境并安装 Python 包
COPY requirements.in .
RUN uv venv --python "python${PYTHON_VERSION}" "${VENV_PATH}" && \
    . "${VENV_PATH}/bin/activate" && \
    uv pip compile requirements.in -o requirements.txt && \
    uv pip install --no-cache-dir -r requirements.txt

# ==================================================================
# Stage 2: final (Corrected)
# ==================================================================
FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-base-ubuntu${UBUNTU_VERSION}

# 声明构建参数
ARG PYTHON_VERSION

# 设置环境
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# FIX: 添加 'deadsnakes' PPA 以获取所有 Python 版本
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-venv" \
    ca-certificates locales \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 从 builder 阶段拷贝已经构建好的虚拟环境
ARG VENV_PATH="/opt/venv"
COPY --from=builder "${VENV_PATH}" "${VENV_PATH}"

# 激活 Python 虚拟环境
ENV PATH="${VENV_PATH}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${VENV_PATH}/lib/python${PYTHON_VERSION}/site-packages/tensorrt_libs:${LD_LIBRARY_PATH}"

# 设置工作目录
WORKDIR /app

# 拷贝启动脚本并设置权限
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 设置容器启动命令
ENTRYPOINT ["/usr/local/bin/start.sh"]