# 基础镜像：使用 TensorFlow Serving 2.18.0
# 这个镜像是基于 Ubuntu 22.04 的
FROM tensorflow/serving:2.18.0

# 作者信息（可选）
LABEL maintainer="Your Name <your.email@example.com>"

# --- 1. 定义构建参数 ---
# 使用 ARG 定义版本号，方便在构建时修改或集中管理
ARG HADOOP_VERSION=2.7.1
ARG PYTHON_VERSION=3.10
ARG PYTHON_VERSION_SHORT=310

# --- 2. 设置环境变量 ---
# DEBIAN_FRONTEND=noninteractive: 防止 apt-get 在构建过程中弹出交互式提示
# JAVA_HOME: 指定 Java 的安装路径，Hadoop 运行需要
# HADOOP_HOME: 指定 Hadoop 的安装目录
# HADOOP_CONF_DIR: 指定 Hadoop 配置文件的目录，这是一个标准实践
# PATH: 将 Hadoop 的可执行文件目录添加到系统路径中
ENV DEBIAN_FRONTEND=noninteractive \
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/etc/hadoop \
    PATH=$PATH:/opt/hadoop/bin:/opt/hadoop/sbin

# --- 3. 安装系统依赖、Java、Python 3.10 和其他工具 ---
# 在一个 RUN 指令中完成所有 apt 操作，以减少镜像层数
RUN apt-get update && \
    # 安装 software-properties-common 以便添加 PPA (用于 Python 3.10)
    apt-get install -y --no-install-recommends software-properties-common && \
    # 添加 deadsnakes PPA，这是获取旧版 Ubuntu 上较新 Python 版本的常用方法
    add-apt-repository ppa:deadsnakes/ppa && \
    # 再次更新 apt 缓存以包含新的 PPA
    apt-get update && \
    # 安装所有需要的软件包：
    #   - openjdk-8-jdk: Hadoop 2.7.x 兼容性最好的 Java 版本
    #   - python${PYTHON_VERSION}: 我们需要的新 Python 版本
    #   - python${PYTHON_VERSION}-distutils: 安装 pip 需要
    #   - git, curl, vim, fuse: 用户要求的工具
    #   - libssl-dev, zlib1g-dev: 编译 Hadoop 本地库可能需要的依赖
    apt-get install -y --no-install-recommends \
    openjdk-8-jdk \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-distutils \
    git \
    curl \
    vim \
    fuse \
    libssl-dev \
    zlib1g-dev && \
    # --- 4. 设置 Python 3.10 为默认 Python ---
    # 使用 update-alternatives 来管理系统中的默认 python 和 python3 命令
    update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 && \
    # 为新的 Python 安装 pip
    curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION} && \
    # --- 5. 清理 apt 缓存 ---
    # 删除缓存文件，减小最终镜像的体积
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /serving

# -- Build the Python Wheel --
# This script seems to be custom. Ensure it's in the build context.
RUN pip install --no-cache-dir \
    pyarrow \
    filelock \
    schedule \
    pyyaml \
    dacite \
    protobuf==4.25.3 \
    grpcio==1.64.1 \
    grpcio-tools \
    wheel

# 复制 setup.py, test.py, build_config_api 文件到工作目录，并安装 Python 包
COPY setup.py test.py build_config_api.sh /serving/
RUN chmod +x build_config_api.sh && ./build_config_api.sh

# --- 6. 安装 Hadoop ---
RUN \
    # 创建 Hadoop 的安装目录和配置目录
    mkdir -p ${HADOOP_HOME} && \
    mkdir -p ${HADOOP_CONF_DIR} && \
    # 从 Apache 归档下载指定版本的 Hadoop 并解压到正确的目录
    curl -fsSL https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    | tar -xz -C ${HADOOP_HOME} --strip-components=1 && \
    # --- 7. 配置 Hadoop 环境 ---
    # 在 hadoop-env.sh 中明确设置 JAVA_HOME
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    # 创建 libhdfs.so 的符号链接，供 TensorFlow Serving 调用
    ln -s ${HADOOP_HOME}/lib/native/libhdfs.so.0.0.0 /usr/lib/libhdfs.so

# --- 8. 暴露 TensorFlow Serving 默认端口 ---
# gRPC 端口 和 REST API 端口
EXPOSE 8500 8501


# 继承自基础镜像的 CMD，通常是 /usr/bin/tf_serving_entrypoint.sh
# 我们不需要修改它，除非有特殊需求
# CMD ["/usr/bin/tf_serving_entrypoint.sh"]