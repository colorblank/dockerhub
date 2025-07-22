# #############################################################################
# # 阶段 1: 构建环境 (Builder)
# #
# # 这个阶段负责编译 TensorFlow Serving。它包含了所有必要的开发工具和源代码。
# #############################################################################
FROM ubuntu:22.04 AS builder

# 设置环境变量，避免在安装过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新软件包列表并安装编译所需的基础依赖和工具
# - build-essential: 编译 C++ 代码所需的核心工具链 (gcc, g++, make)
# - git: 用于克隆 TensorFlow Serving 的源代码
# - openjdk-8-jdk: Java 开发环境，Hadoop 和 Bazel 需要
# - python3.10, python3-dev, python3-pip: Python 环境
# - curl, wget, unzip: 常用的网络和文件处理工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    openjdk-8-jdk \
    python3.10 \
    python3-dev \
    python3-pip \
    curl \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 将 python3.10 设置为默认的 python 和 python3
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# -- 设置 Java 和 Bazel 环境变量 --
# Bazel 是 TensorFlow 使用的构建工具。TensorFlow Serving 2.18.0 需要一个兼容的 Bazel 版本。
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV BAZEL_VERSION=6.5.0
RUN wget https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh && \
    chmod +x bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh && \
    ./bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh && \
    rm bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh

# -- 下载并解压 Hadoop --
# HADOOP_VERSION 必须与您的集群匹配。这里使用 2.7.1。
ENV HADOOP_VERSION=2.7.1
RUN wget -q https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt/ && \
    rm hadoop-${HADOOP_VERSION}.tar.gz
# 将解压后的目录重命名为 /opt/hadoop，以符合您的 HADOOP_HOME 要求
RUN mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop

# -- 设置 Hadoop 相关的环境变量 --
# 这些环境变量将由 TensorFlow 的构建脚本使用，以找到 Hadoop 库。
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/etc/hadoop
# 将 Hadoop 的 bin 目录添加到 PATH，虽然在构建阶段不是必须的，但这是个好习惯。
ENV PATH=$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

# -- 克隆 TensorFlow Serving 源代码 --
# 我们克隆指定的版本标签，并拉取所有子模块（包括 TensorFlow 本身）。
ENV TF_SERVING_VERSION=r2.18
WORKDIR /
RUN git clone --depth=1 --recurse-submodules --branch=${TF_SERVING_VERSION} https://github.com/tensorflow/serving.git

# -- 配置并编译 TensorFlow Serving --
WORKDIR /serving
# TensorFlow 的编译配置脚本是交互式的。我们使用 'yes' 命令自动回答所有问题，
# 这样就可以在 Docker build 期间自动完成配置。
# 这一步会探测系统环境，并生成 Bazel 的编译配置文件。
# RUN yes "" | tensorflow/configure.sh

# 使用 Bazel 编译 TensorFlow Model Server。
# --config=release: 启用优化以获得更好的性能。
# --define=with_hdfs_support=true: 这是启用 Hadoop HDFS 支持的关键标志。
# tensorflow_serving/model_servers:tensorflow_model_server: 这是要编译的目标。
RUN bazel build --config=release \
    --define=with_hdfs_support=true \
    tensorflow_serving/model_servers:tensorflow_model_server


# #############################################################################
# # 阶段 2: 最终运行环境 (Final Image)
# #
# # 这个阶段构建最终的镜像。它非常轻量，只包含运行服务所必需的组件。
# #############################################################################
FROM ubuntu:22.04

# 再次设置非交互式环境变量
ENV DEBIAN_FRONTEND=noninteractive

# 安装运行时的最小依赖
# - openjdk-8-jre-headless: Java 运行时环境，Hadoop Client 需要。
# - python3.10: 即使服务是C++编写的，一些脚本或工具可能需要Python。
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    vim \
    openjdk-8-jre-headless \
    python3.10 \
    python3-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*
# 将 python3.10 设置为默认的 python 和 python3
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

RUN pip install --no-cache-dir \
    pyarrow \
    filelock \
    schedule \
    pyyaml

# -- 设置核心环境变量 --
# 这些环境变量在容器运行时是必需的。
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin
ENV HADOOP_CONF_DIR=/etc/hadoop
# 将 Java 的 JNI 库路径添加到 LD_LIBRARY_PATH，这是 Hadoop client 正确加载本地库所必需的。
ENV LD_LIBRARY_PATH=${JAVA_HOME}/jre/lib/amd64/server

# 从构建阶段复制 Hadoop 发行版
COPY --from=builder /opt/hadoop ${HADOOP_HOME}

# 创建 Hadoop 配置目录，并允许用户通过卷挂载自己的配置文件。
# 即使没有挂载，Hadoop 也会使用默认配置。
RUN mkdir -p ${HADOOP_CONF_DIR}

# 从构建阶段复制已编译的 TensorFlow Model Server 二进制文件到最终镜像的 PATH 中
COPY --from=builder /serving/bazel-bin/tensorflow_serving/model_servers/tensorflow_model_server /usr/local/bin/

# -- 暴露端口 --
# 8501: REST API 端口
# 8500: gRPC API 端口
EXPOSE 8501 8500

# -- 设置模型服务的默认环境变量 --
# 这些可以在 `docker run` 时被覆盖。
ENV MODEL_NAME=default_model
ENV MODEL_BASE_PATH=/models

# -- 容器启动命令 --
# 启动 TensorFlow Model Server。
# 它会监听 gRPC 和 REST API 端口，并从 MODEL_BASE_PATH 加载名为 MODEL_NAME 的模型。
# 当 MODEL_BASE_PATH 以 "hdfs://" 开头时，它将自动使用 HDFS 文件系统。
ENTRYPOINT ["/usr/local/bin/tensorflow_model_server"]
CMD ["--port=8500", "--rest_api_port=8501", "--model_name=${MODEL_NAME}", "--model_base_path=${MODEL_BASE_PATH}"]