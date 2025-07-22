# #############################################################################
# # 阶段 1: 构建环境 (Builder)
# #
# # 融合了官方 build 文件的最佳实践，提供一个非常健壮的编译环境。
# #############################################################################
FROM ubuntu:22.04 AS builder

# -- 设置环境变量 --
ENV DEBIAN_FRONTEND=noninteractive
ENV TF_SERVING_VERSION=2.18.0
# 使用官方文件验证过的 Bazel 版本
ENV BAZEL_VERSION=6.5.0
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_VERSION=2.7.1
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV PATH=${PATH}:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

# -- 安装系统和编译依赖 (参考官方文件) --
# 增加了更多 TensorFlow 编译时可能需要的库，使构建过程更稳定。
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    automake \
    build-essential \
    ca-certificates \
    curl \
    git \
    libcurl4-openssl-dev \
    libfreetype6-dev \
    libpng-dev \
    libtool \
    libzmq3-dev \
    openjdk-8-jdk \
    pkg-config \
    python3.10 \
    python3-dev \
    python3-pip \
    software-properties-common \
    swig \
    unzip \
    wget \
    zip \
    zlib1g-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# -- 安装 Python 构建依赖 (参考官方文件) --
RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir \
    future \
    grpcio \
    h5py \
    keras_applications \
    keras_preprocessing \
    mock \
    numpy \
    portpicker \
    requests \
    setuptools \
    six

# -- 安装 Bazel --
RUN wget https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh && \
    chmod +x bazel-*.sh && \
    ./bazel-*.sh && \
    rm bazel-*.sh

# -- 安装 Hadoop --
RUN wget -q https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt/ && \
    mv /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME} && \
    rm hadoop-${HADOOP_VERSION}.tar.gz

# -- 克隆 TensorFlow Serving 源码 --
WORKDIR /
RUN git clone --depth=1 --recurse-submodules --branch=${TF_SERVING_VERSION} https://github.com/tensorflow/serving.git

# -- 编译 TensorFlow Serving --
WORKDIR /serving
# 【优化】: 使用 ARG 定义可覆盖的构建选项，这是官方文件的最佳实践。
# 默认使用 --config=release 进行优化编译。
ARG TF_SERVING_BUILD_OPTIONS="--config=release"
# 默认的 Bazel 选项，包括了之前为解决资源问题而加的 jobs 限制。
ARG TF_SERVING_BAZEL_OPTIONS="--jobs=2 --local_ram_resources=HOST_RAM*0.5"
RUN echo "--- Building with Build Options: ${TF_SERVING_BUILD_OPTIONS}" && \
    echo "--- Building with Bazel Options: ${TF_SERVING_BAZEL_OPTIONS}" && \
    bazel build \
    ${TF_SERVING_BAZEL_OPTIONS} \
    ${TF_SERVING_BUILD_OPTIONS} \
    --define=with_hdfs_support=true \
    --verbose_failures \
    tensorflow_serving/model_servers:tensorflow_model_server

# #############################################################################
# # 阶段 2: 最终运行环境 (Final Image)
# #
# # 保持了我们之前的优势：创建一个非常小且干净的最终镜像。
# #############################################################################
FROM ubuntu:22.04

# -- 设置核心环境变量 --
ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV LD_LIBRARY_PATH=${JAVA_HOME}/jre/lib/amd64/server

# -- 安装最小运行时依赖 --
# 除了 JRE，还包括编译时链接的库的运行时版本 (如 libzmq5, zlib1g)。
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-8-jre-headless \
    libzmq5 \
    zlib1g \
    python3.10 \
    python3-dev \
    python3-pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
    
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
RUN pip install --no-cache-dir \
    pyarrow \
    filelock \
    schedule \
    pyyaml


# -- 从构建阶段复制产物 --
COPY --from=builder ${HADOOP_HOME} ${HADOOP_HOME}
COPY --from=builder /serving/bazel-bin/tensorflow_serving/model_servers/tensorflow_model_server /usr/local/bin/

# -- 配置环境 --
RUN mkdir -p ${HADOOP_CONF_DIR}
EXPOSE 8501 8500
ENV MODEL_NAME=default_model
ENV MODEL_BASE_PATH=/models

# -- 容器启动命令 --
ENTRYPOINT ["/usr/local/bin/tensorflow_model_server"]
CMD ["--port=8500", "--rest_api_port=8501", "--model_name=${MODEL_NAME}", "--model_base_path=${MODEL_BASE_PATH}"]