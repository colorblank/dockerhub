# #############################################################################
# # STAGE 1: Build Environment (Builder)
# #
# # This stage builds the TensorFlow Serving config API Python wheel.
# # It uses best practices from the official build files for a robust environment.
# #############################################################################
ARG TF_SERVING_VERSION=2.18.0
FROM ubuntu:22.04 AS builder

# -- Set Environment Variables --
ENV DEBIAN_FRONTEND=noninteractive

# -- Install System and Build Dependencies --
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    libcurl4-openssl-dev \
    libfreetype6-dev \
    libtool \
    libzmq3-dev \
    pkg-config \
    python3.10 \
    python3-dev \
    python3-pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# -- Install Python Build Dependencies --
RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir \
    protobuf==4.25.3 \
    grpcio==1.64.1 \
    wheel

# -- Clone TensorFlow Serving Source Code --
WORKDIR /
# Use the tag format "2.18.0" which is more common than "r2.18" for releases
RUN git clone --depth=1 --recurse-submodules --branch=r2.18 https://github.com/tensorflow/serving.git

WORKDIR /serving

# -- Build the Python Wheel --
# This script seems to be custom. Ensure it's in the build context.
COPY build_config_api.sh /serving/
RUN chmod +x build_config_api.sh && ./build_config_api.sh

# #############################################################################
# # STAGE 2: Final Runtime Image
# #
# # This stage creates a minimal, clean final image with FUSE support for HDFS.
# #############################################################################
ARG HADOOP_VERSION=2.7.1
ARG TENSORFLOW_SERVING_VERSION=2.18.0
FROM tensorflow/serving:${TENSORFLOW_SERVING_VERSION}

# -- Set Core Environment Variables --
ENV DEBIAN_FRONTEND=noninteractive \
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    HADOOP_VERSION=${HADOOP_VERSION} \
    HADOOP_HOME=/opt/hadoop/hadoop-${HADOOP_VERSION} \
    HADOOP_CONF_DIR=/etc/hadoop \
    HDFS_MOUNT_POINT=/hdfs

# -- Add Hadoop binaries to PATH and set library paths --
ENV PATH=${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${PATH} \
    LD_LIBRARY_PATH=${JAVA_HOME}/jre/lib/amd64/server:${HADOOP_HOME}/lib/native:${LD_LIBRARY_PATH}

# -- Install Minimal Runtime Dependencies including FUSE --
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-8-jre-headless \
    curl \
    vim \
    python3.10 \
    python3-pip \
    fuse \
    libhdfs0-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# -- Set Python 3.10 as default --
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# -- Install Python Packages --
RUN pip install --no-cache-dir \
    pyarrow \
    filelock \
    schedule \
    pyyaml \
    dacite \
    protobuf==4.25.3 \
    grpcio==1.64.1 \
    wheel

# -- Download and Install Hadoop --
RUN curl -sL https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | tar -xz -C /opt/ && \
    ln -s /opt/hadoop-${HADOOP_VERSION} /opt/hadoop

# -- Copy and install the Python wheel from the builder stage --
COPY --from=builder /serving/dist/tensorflow_serving_config-*.whl /tmp/
RUN pip install --no-cache-dir /tmp/tensorflow_serving_config-*.whl && \
    rm /tmp/tensorflow_serving_config-*.whl

# -- Configure Environment --
RUN mkdir -p ${HADOOP_CONF_DIR} ${HDFS_MOUNT_POINT}
EXPOSE 8501 8500
ENV MODEL_NAME=default_model \
    MODEL_BASE_PATH=${HDFS_MOUNT_POINT}/models

# -- Copy and set up the entrypoint --
COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

# -- Container Start Command --
ENTRYPOINT ["/usr/bin/entrypoint.sh"]