# 只需要轻量级的 protobuf 库
from google.protobuf import text_format

# 从您刚刚生成的、带有正确路径的文件中导入
from tensorflow_serving.config import model_server_config_pb2
import os

# --- Export (Write) a sample models.config file ---
print("--- 正在生成示例配置文件 'models.config' ---")
sample_config = model_server_config_pb2.ModelServerConfig()

# Add a sample model configuration
model1 = sample_config.model_config_list.config.add()
model1.name = "example_model_a"
model1.base_path = "/var/lib/tensorflow_serving/models/example_model_a"
model1.model_platform = "tensorflow"
model1.model_version_policy.specific.versions.append(1)
model1.model_version_policy.specific.versions.append(2)

model2 = sample_config.model_config_list.config.add()
model2.name = "example_model_b"
model2.base_path = "/var/lib/tensorflow_serving/models/example_model_b"
model2.model_platform = "tensorflow"

config_file_path = "models.config"
try:
    with open(config_file_path, "w") as f:
        f.write(text_format.MessageToString(sample_config))
    print(f"✅ 示例配置文件 '{config_file_path}' 生成成功！")
except IOError as e:
    print(f"❌ 错误: 无法写入文件 '{config_file_path}'。错误详情: {e}")
    exit(1)  # Exit if we can't write the file, as subsequent steps will fail

print("\n--- 读取、构建和导出测试 ---")

# 1. 创建一个空的 ModelServerConfig 对象
#    这是我们将要填充数据的目标容器。
model_server_config = model_server_config_pb2.ModelServerConfig()

# 2. 指定你的配置文件路径 (已在上面定义)
# config_file_path = 'models.config'

# 3. 读取并解析文件
try:
    with open(config_file_path, "r") as f:
        # 读取文件内容
        config_content = f.read()

        # 使用 text_format.Parse() 将文本内容解析到 Protobuf 对象中
        text_format.Parse(config_content, model_server_config)

    print("✅ 配置文件 'models.config' 读取并解析成功！")

    # 4. (可选) 访问和使用解析后的数据
    print("\n--- 读取到的模型配置 ---")

    # model_server_config.model_config_list.config 是一个可迭代的列表
    if not model_server_config.model_config_list.config:
        print("配置文件中没有找到任何模型。")
    else:
        for model_config in model_server_config.model_config_list.config:
            print(f"模型名称 (Name): {model_config.name}")
            print(f"模型路径 (Base Path): {model_config.base_path}")
            print(f"模型平台 (Platform): {model_config.model_platform}")

            # 检查是否有特定的版本策略
            if model_config.model_version_policy.HasField("specific"):
                versions = list(model_config.model_version_policy.specific.versions)
                print(f"版本策略 (Versions): {versions}")
            else:
                print("版本策略 (Versions): 默认 (Latest)")

            print("-" * 20)


except FileNotFoundError:
    print(f"❌ 错误: 找不到配置文件 '{config_file_path}'")
except text_format.ParseError as e:
    print("❌ 错误: 解析配置文件失败，请检查文件格式是否正确。")
    print(f"   错误详情: {e}")

# Clean up the generated models.config file
try:
    if os.path.exists(config_file_path):
        os.remove(config_file_path)
        print(f"\n✅ 清理: 示例配置文件 '{config_file_path}' 已删除。")
except OSError as e:
    print(f"❌ 错误: 无法删除文件 '{config_file_path}'。错误详情: {e}")
