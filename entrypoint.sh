#!/bin/bash

# 开启错误时退出
set -e

echo "Entrypoint: 正在配置 Hadoop 环境..."

# 检查 HADOOP_HOME 是否已设置
if [ -z "$HADOOP_HOME" ]; then
  echo "错误: HADOOP_HOME 环境变量未设置。"
  exit 1
fi


export CLASSPATH=$(hadoop classpath --glob)
# (可选) 打印 CLASSPATH 用于调试，但在线上环境可能会刷屏，可以注释掉
echo "CLASSPATH: $CLASSPATH"

echo "Entrypoint: Hadoop 环境配置完成。"
echo "------------------------------------"

echo "Entrypoint: 启动 HDFS 模型同步守护进程..."
# 以后台方式运行 sync.py，并将标准输出和标准错误重定向到日志文件，同时输出到控制台
nohup python3 /app/sync.py > /var/log/hdfs_syncer.log 2>&1 &
echo "Entrypoint: HDFS 模型同步守护进程已在后台启动。"

# 确保日志文件可读写，以便后续查看
chmod 644 /var/log/hdfs_syncer.log

# 继续执行 TensorFlow Serving 的原始入口点
exec /usr/bin/tf_serving_entrypoint.sh "$@"
