#!/bin/bash

# =================================================================
#  Start SSH Server for VS Code Remote Development
# =================================================================
# 启动 ssh 服务
service ssh start
echo "SSH Server started."
echo "Connect with VS Code using user 'root' and password 'vscode'."


# =================================================================
#  Start JupyterLab
# =================================================================
echo "Starting JupyterLab..."
echo "JupyterLab access token will be printed below."
echo "------------------------------------------------"

# 启动 JupyterLab
# 这将是前台进程，保持容器持续运行
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root