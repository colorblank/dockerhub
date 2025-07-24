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

# 继续执行 TensorFlow Serving 的原始入口点
exec /usr/bin/tf_serving_entrypoint.sh "$@"
