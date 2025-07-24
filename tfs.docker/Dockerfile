# 基础镜像设置为 Ubuntu 22.04
FROM ubuntu:22.04

# 维护者信息
LABEL maintainer="Your Name <your.email@example.com>"

# 设置非交互式安装，避免安装过程中断
ENV DEBIAN_FRONTEND=noninteractive

# --- 环境准备与基础软件安装 ---

# 更新软件包列表并安装基础依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # 网络工具
        curl \
        git \
        wget \
        # 文本编辑器
        vim \
        # 压缩解压工具
        unzip \
        tar \
        # SSH客户端，Hadoop需要
        openssh-client \
        # FUSE (Filesystem in Userspace)，用于挂载HDFS
        fuse \
        # 其他基础工具
        gnupg \
        build-essential && \
    # 清理APT缓存
    rm -rf /var/lib/apt/lists/*

# --- 安装 OpenJDK 8 ---

# 安装 OpenJDK 8
RUN apt-get update && \
    apt-get install -y --no-install-recommends openjdk-8-jdk && \
    # 清理APT缓存
    rm -rf /var/lib/apt/lists/*

# 设置 JAVA_HOME 环境变量
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# --- 安装 Python 3.10 ---

# 安装 Python 3.10 及其开发包和pip
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.10 \
        python3.10-dev \
        python3-pip && \
    # 清理APT缓存
    rm -rf /var/lib/apt/lists/* && \
    # 更新 pip
    python3.10 -m pip install --no-cache-dir --upgrade pip

# 设置 Python 3.10 为默认 python
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 && \
    update-alternatives --set python3 /usr/bin/python3 


# --- 安装 Hadoop 2.7.1 ---

# 设置 Hadoop 版本和下载地址
ARG HADOOP_VERSION=2.7.1
ARG HADOOP_URL=https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz

# 下载、解压并移动 Hadoop
RUN curl -fSL "${HADOOP_URL}" -o /tmp/hadoop.tar.gz && \
    tar -xvf /tmp/hadoop.tar.gz -C /opt/ && \
    rm /tmp/hadoop.tar.gz && \
    ln -s /opt/hadoop-${HADOOP_VERSION} /opt/hadoop

# 设置 Hadoop 相关环境变量
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV PATH=$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${HADOOP_HOME}/lib/native

# --- 配置 Hadoop ---

# 创建 Hadoop 配置目录
RUN mkdir -p ${HADOOP_CONF_DIR}

# 复制 Hadoop 默认配置文件
RUN cp ${HADOOP_HOME}/etc/hadoop/* ${HADOOP_CONF_DIR}

# 修改 hadoop-env.sh 以使用系统的 JAVA_HOME
RUN sed -i "s#^export JAVA_HOME=.*#export JAVA_HOME=${JAVA_HOME}#" ${HADOOP_CONF_DIR}/hadoop-env.sh

# 用户需在此处提供自己的 core-site.xml 和 hdfs-site.xml
# ADD core-site.xml ${HADOOP_CONF_DIR}/
# ADD hdfs-site.xml ${HADOOP_CONF_DIR}/


RUN git clone --depth=1 --recurse-submodules --branch=r2.18 https://github.com/tensorflow/serving.git

WORKDIR /serving

# -- Build the Python Wheel --
# This script seems to be custom. Ensure it's in the build context.
COPY build_config_api.sh /serving/
RUN pip install --no-cache-dir \
    pyarrow \
    filelock \
    schedule \
    pyyaml \
    dacite \
    protobuf==4.25.3 \
    grpcio==1.64.1 \
    wheel
RUN chmod +x build_config_api.sh && ./build_config_api.sh


# --- 安装 TensorFlow Serving ---

# 设置 TensorFlow Serving 版本
ARG TF_SERVING_VERSION=2.18.0

# 安装 TensorFlow Serving
# 添加 TensorFlow Serving 发行版的 URI 作为包源
RUN echo "deb [arch=amd64] http://storage.googleapis.com/tensorflow-serving-apt stable tensorflow-model-server tensorflow-model-server-universal" | tee /etc/apt/sources.list.d/tensorflow-serving.list && \
    # 添加 Google Cloud public key
    curl https://storage.googleapis.com/tensorflow-serving-apt/tensorflow-serving.release.pub.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y --no-install-recommends tensorflow-model-server=${TF_SERVING_VERSION}-1 && \
    # 清理APT缓存
    rm -rf /var/lib/apt/lists/*

# --- FUSE HDFS 挂载支持 ---

# 允许非root用户挂载 FUSE
RUN echo "user_allow_other" >> /etc/fuse.conf

# 创建 HDFS 挂载点
RUN mkdir -p /hdfs

# 工作目录
WORKDIR /

# 暴露 TensorFlow Serving 的 gRPC 和 REST API 端口
EXPOSE 8500 8501

# 默认启动命令
CMD ["/usr/bin/tensorflow_model_server"]