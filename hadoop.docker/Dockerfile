# Gunakan base image Ubuntu 20.04
FROM ubuntu:20.04

# Set variabel environment agar tidak ada prompt interaktif saat instalasi
ENV DEBIAN_FRONTEND=noninteractive

# Install dependensi dan perangkat lunak umum, termasuk server SSH
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Dependensi untuk Python & Hadoop
    software-properties-common \
    wget \
    openjdk-8-jdk \
    # Klien dan Server SSH
    ssh \
    openssh-server \
    # Perangkat lunak umum Ubuntu
    curl \
    git \
    nano \
    vim \
    net-tools \
    dnsutils \
    iputils-ping \
    unzip \
    procps \
    htop \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Konfigurasi SSH Server
RUN mkdir /var/run/sshd && \
    # Izinkan login root dengan kata sandi. Peringatan Keamanan: Tidak disarankan untuk produksi.
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    # Atur kata sandi untuk root. Ubah "root" dengan kata sandi Anda sendiri.
    echo 'root:root' | chpasswd

# Install Python 3.10 dari PPA deadsnakes
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends python3.10 python3.10-distutils && \
    rm -rf /var/lib/apt/lists/*

# Atur Python 3.10 sebagai Python default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# Install pip untuk Python 3.10
RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py

# Tetapkan versi Hadoop dan path download
ENV HADOOP_VERSION=2.7.1
ENV HADOOP_URL=https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz

# Download dan ekstrak Hadoop
RUN wget ${HADOOP_URL} -O /tmp/hadoop.tar.gz && \
    tar -xvf /tmp/hadoop.tar.gz -C /opt/ && \
    rm /tmp/hadoop.tar.gz && \
    mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop

# Atur variabel environment untuk Hadoop dan Java
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
ENV PATH=$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

# Konfigurasi Hadoop
# Atur JAVA_HOME di hadoop-env.sh
RUN sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=${JAVA_HOME}|" ${HADOOP_CONF_DIR}/hadoop-env.sh

# Ekspos port SSH
EXPOSE 22

# Atur direktori kerja
WORKDIR /

# Jalankan layanan SSH dan buka shell bash
CMD service ssh start && bash