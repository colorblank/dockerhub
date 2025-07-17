# STEP 1: Use the official TensorFlow Serving image as the base
# Using a specific version tag based on Ubuntu 22.04 (Jammy) is recommended
FROM tensorflow/serving:2.18.0

# STEP 2: Define Hadoop version and download address
ARG HADOOP_VERSION=2.7.1
ARG HADOOP_URL=https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz

# STEP 3: Set environment variables
# Note the updated JAVA_HOME path for OpenJDK installed via apt
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/etc/hadoop/conf
ENV PATH=$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

# STEP 4: Install system dependencies like Java 8 and Python
# The TF Serving image is minimal, so we need to add Java, tar, etc.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-8-jdk \
    wget \
    tar \
    vim \
    python3 \
    python3-pip \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# NEW STEP: Install Python dependencies using pip
RUN pip install --no-cache-dir \
    pyarrow \
    filelock \
    schedule \
    pyyaml

# STEP 5: Download and install Hadoop
RUN wget ${HADOOP_URL} -O /tmp/hadoop.tar.gz && \
    mkdir -p ${HADOOP_HOME} && \
    tar -xvf /tmp/hadoop.tar.gz -C ${HADOOP_HOME} --strip-components 1 && \
    rm /tmp/hadoop.tar.gz

# STEP 6: Create configuration mount point
RUN mkdir -p ${HADOOP_CONF_DIR}

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# STEP 7: Set working directory
WORKDIR /app

# STEP 8: Set default entrypoint and command
# This will override the original 'tensorflow_model_server' entrypoint
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["bash"]