# STEP 1: Use a base image with Java 8 on a SUPPORTED OS (Ubuntu 22.04)
FROM eclipse-temurin:8-jdk-jammy

# STEP 2: Define Hadoop version and download address
ARG HADOOP_VERSION=2.7.1
ARG HADOOP_URL=https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz

# STEP 3: Set environment variables
ENV JAVA_HOME=/opt/java/openjdk
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/etc/hadoop/conf
ENV PATH=$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

# STEP 4: Install system dependencies and Python 3.10
# This is now much simpler because Python 3.10 is native to Ubuntu 22.04
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    tar \
    python3 \
    python3-pip \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# STEP 5: Download and install Hadoop
RUN wget ${HADOOP_URL} -O /tmp/hadoop.tar.gz && \
    mkdir -p ${HADOOP_HOME} && \
    tar -xvf /tmp/hadoop.tar.gz -C ${HADOOP_HOME} --strip-components 1 && \
    rm /tmp/hadoop.tar.gz

# STEP 6: Create configuration mount point
RUN mkdir -p ${HADOOP_CONF_DIR}

# STEP 7: Set working directory
WORKDIR /app

# STEP 8: Set default command
CMD ["bash"]