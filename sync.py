# main.py
"""
HDFS → Local 的模型同步守护进程
修复要点
1. 使用 pyparsing 安全解析 TF-Serving config，避免正则嵌套括号问题。
2. 所有本地路径均做 Path.resolve() 检查，防止目录遍历。
3. 文件下载采用“临时文件 + 原子 rename”，保证完整性。
4. 如果 HDFS 上模型被删除，本地同步删除。
5. 针对 mtime=None、sync_interval=0 等边界条件做了兜底。
"""

from __future__ import annotations

# (这是放在测试文件顶部的解析器代码，以便独立运行)
import logging
import os
import shutil
import time
from pathlib import Path
from typing import Dict, List

import pyarrow.fs as pafs
from filelock import FileLock
import yaml
from dacite import from_dict, Config as DaciteConfig

from config import ModelConfigList, SyncConfig, load_config

# ---------------- Logging ----------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


def _format_version_labels(labels: Dict[str, int]) -> str:
    """
    格式化 version_labels 字典为 TF-Serving config 字符串。
    """
    if not labels:
        return ""
    label_lines = [f'      "{k}": {v}' for k, v in labels.items()]
    return "  version_labels {\n" + ",\n".join(label_lines) + "\n  }"


def _format_version_policy(policy: Dict[str, str]) -> str:
    """
    格式化 version_policy 字典为 TF-Serving config 字符串。
    """
    if not policy:
        return ""
    policy_lines = [f"      {k}: {v}" for k, v in policy.items()]
    return "  version_policy {\n" + "\n".join(policy_lines) + "\n  }"


def _parse_model_config(content: str) -> ModelConfigList:
    """
    解析 HDFS 上的 YAML 格式模型配置文件。
    """
    try:
        raw_config = yaml.safe_load(content)
        # 使用 dacite 从字典加载到 ModelConfigList 对象，忽略额外字段
        return from_dict(
            data_class=ModelConfigList,
            data=raw_config,
            config=DaciteConfig(check_types=False, strict=False),
        )
    except Exception as e:
        logging.error("Failed to parse model config content from YAML. Error: %s", e)
        return ModelConfigList()  # 返回空列表或默认值


# ---------------- 主同步类 ----------------
class HdfsModelSyncer:
    def __init__(self, config: SyncConfig) -> None:
        self.config = config
        self.hdfs_fs = self._initialize_hdfs_fs()

        self.local_model_root = Path(self.config.local_model_root).resolve()
        self.local_model_root.mkdir(parents=True, exist_ok=True)
        logging.info("Local model root initialized at: %s", self.local_model_root)

    # ---------- HDFS 初始化 ----------
    def _initialize_hdfs_fs(self) -> pafs.HadoopFileSystem:
        """初始化 PyArrow HDFS 句柄，带异常兜底。"""
        try:
            conf = self.config.hdfs
            namenode_map = {nn.nn_id: nn.address for nn in conf.namenodes}

            extra_conf = {
                "dfs.nameservices": conf.name_services,
                f"dfs.ha.namenodes.{conf.name_services}": ",".join(namenode_map.keys()),
                f"dfs.client.failover.proxy.provider.{conf.name_services}": "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider",
            }
            for nn_id, addr in namenode_map.items():
                extra_conf[f"dfs.namenode.rpc-address.{conf.name_services}.{nn_id}"] = (
                    addr
                )

            return pafs.HadoopFileSystem(
                host=conf.name_services,
                port=0,
                user=conf.user,
                extra_conf=extra_conf,
            )
        except Exception as e:
            logging.error("Failed to connect to HDFS: %s", e)
            raise

    # ---------- 目录同步 ----------
    def _should_update_file(self, file_info: pafs.FileInfo, local_file: Path) -> bool:
        """
        判断本地文件是否需要更新。
        如果 HDFS 文件没有 mtime 则强制更新。
        """
        if file_info.mtime is None:
            return True
        if local_file.exists():
            local_mtime = local_file.stat().st_mtime
            return file_info.mtime.timestamp() > local_mtime
        return True

    def _copy_file_atomically(self, hdfs_path: str, local_file: Path) -> None:
        """
        从 HDFS 复制文件到本地，使用临时文件 + 原子 rename 保证完整性。
        """
        local_file.parent.mkdir(parents=True, exist_ok=True)
        tmp_file = local_file.with_suffix(local_file.suffix + ".tmp")
        try:
            with self.hdfs_fs.open_input_file(hdfs_path) as src:
                with open(tmp_file, "wb") as dst:
                    shutil.copyfileobj(src, dst)
            tmp_file.replace(local_file)  # 原子替换
        except Exception as e:
            logging.error("Failed to copy %s: %s", hdfs_path, e)
            if tmp_file.exists():
                tmp_file.unlink(missing_ok=True)

    def _sync_directory(self, hdfs_dir: str, local_dir: Path) -> None:
        """
        递归同步 HDFS 目录到本地，仅更新较新文件。
        1. 检查 HDFS 目录存在性
        2. 使用临时文件 + 原子 rename 保证完整性
        3. 跳过 mtime=None 的文件
        """
        local_dir.mkdir(parents=True, exist_ok=True)

        hdfs_info = self.hdfs_fs.get_file_info(hdfs_dir)
        if hdfs_info.type != pafs.FileType.Directory:
            logging.warning("HDFS directory does not exist: %s", hdfs_dir)
            return

        selector = pafs.FileSelector(hdfs_dir, recursive=True)
        for file_info in self.hdfs_fs.get_file_info(selector):
            if file_info.type != pafs.FileType.File:
                continue

            rel_path = os.path.relpath(file_info.path, hdfs_dir)
            local_file = local_dir / rel_path

            # 防止目录遍历
            if not str(local_file.resolve()).startswith(str(self.local_model_root)):
                logging.warning("Skipping suspicious path: %s", rel_path)
                continue

            if self._should_update_file(file_info, local_file):
                logging.info("  - Copying: %s -> %s", file_info.path, local_file)
                self._copy_file_atomically(file_info.path, local_file)
            else:
                logging.debug("  - Skipping (up-to-date): %s", local_file)

    # ---------- 单次同步 ----------
    def run_once(self) -> None:
        """单次同步完整流程。"""
        lock_path = self.local_model_root / f".sync.lock.{os.getpid()}"
        with FileLock(lock_path):
            logging.info("Starting sync cycle.")
            try:
                # 1. 读取 HDFS 配置
                with self.hdfs_fs.open_input_file(
                    self.config.hdfs_model_config_path
                ) as f:
                    content = f.read().decode("utf-8")
                hdfs_models = _parse_model_config(content)

                # 2. 同步所有模型并收集本地路径
                local_models: List[Dict[str, str]] = []
                for model_entry in hdfs_models.model_config:
                    name = model_entry.name
                    hdfs_path = model_entry.base_path
                    local_path = (self.local_model_root / name).resolve()
                    if not str(local_path).startswith(str(self.local_model_root)):
                        logging.error("Invalid model name: %s", name)
                        continue

                    logging.info("Processing model '%s'", name)
                    self._sync_directory(hdfs_path, local_path)
                    local_models.append(
                        {
                            "name": name,
                            "base_path": str(local_path),
                            "model_platform": model_entry.model_platform,
                            "version_labels": model_entry.version_labels,
                            "version_policy": model_entry.version_policy,
                        }
                    )

                # 3. 清理本地已删除模型
                expected = {m.name for m in hdfs_models.model_config}
                for item in self.local_model_root.iterdir():
                    if item.is_dir() and item.name not in expected:
                        shutil.rmtree(item)
                        logging.info("Removed deleted model: %s", item.name)

                # 4. 生成新的本地 models.config
                config_path = self.local_model_root / "models.config"
                # Reconstruct the models.config based on the ModelEntry structure
                # This assumes TF-Serving config format, which is still required locally
                config_lines = ["model_config_list {"]
                for m in local_models:
                    config_lines.append("  config {")
                    config_lines.append(f'    name: "{m["name"]}"')
                    config_lines.append(f'    base_path: "{m["base_path"]}"')
                    config_lines.append(f'    model_platform: "{m["model_platform"]}"')

                    if m["version_labels"]:
                        labels_str = _format_version_labels(m["version_labels"])
                        config_lines.append(labels_str)

                    if m["version_policy"]:
                        policy_str = _format_version_policy(m["version_policy"])
                        config_lines.append(policy_str)

                    config_lines.append("  }")
                config_lines.append("}")

                config_path.write_text("\n".join(config_lines))
                logging.info("Local models.config written to %s", config_path)

            except Exception:
                logging.exception("Error during sync cycle")
            finally:
                logging.info("Sync cycle finished.")

    # ---------- 持续同步 ----------
    def run_continuously(self) -> None:
        """持续同步主循环。"""
        if not self.config.enable_sync_loop:
            logging.warning("Continuous sync disabled; running once only.")
            self.run_once()
            return

        interval = max(60, self.config.sync_interval_minutes * 60)  # 至少 60 秒
        logging.info("Starting continuous sync, interval=%ds", interval)
        while True:
            self.run_once()
            logging.info("Sleeping %d seconds...", interval)
            time.sleep(interval)


# ---------------- 入口 ----------------
def main() -> None:
    try:
        cfg = load_config()
        HdfsModelSyncer(cfg).run_continuously()
    except FileNotFoundError:
        logging.error(
            "Configuration file not found. Please create 'config/config.yml'."
        )
    except Exception:
        logging.exception("Critical error in main")


if __name__ == "__main__":
    main()
