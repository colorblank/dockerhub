# config.py
import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional

# Note: You might need to install dacite: pip install dacite
import yaml
from dacite import from_dict


@dataclass
class ModelEntry:
    """Represents a single model entry in the HDFS model configuration."""

    name: str
    base_path: str
    model_platform: str = "tensorflow"  # Default to tensorflow
    version_labels: Optional[Dict[str, int]] = field(default_factory=dict)
    version_policy: Optional[Dict[str, str]] = field(default_factory=dict)

@dataclass
class ModelConfigList:
    """Represents the list of models in the HDFS model configuration."""

    model_config: List[ModelEntry] = field(default_factory=list)


@dataclass
class HDFSNameNode:
    """Represents a single HDFS NameNode."""

    nn_id: str
    address: str


@dataclass
class HDFSConfig:
    """Represents the HDFS connection configuration."""

    name_services: str
    user: str
    namenodes: List[HDFSNameNode]


@dataclass
class SyncConfig:
    """Represents the overall application configuration."""

    hdfs: HDFSConfig
    # This path can be overridden by the HDFS_MODEL_CONFIG_PATH environment variable.
    # 该路径可以被 HDFS_MODEL_CONFIG_PATH 环境变量覆盖。
    hdfs_model_config_path: Optional[str] = None
    local_model_root: str
    sync_interval_minutes: int
    enable_sync_loop: bool = True  # Flag to enable/disable the continuous loop


def load_config(path: str = "config/config.yml") -> SyncConfig:
    """
    Loads configuration from a YAML file and allows environment variable overrides.
    The environment (e.g., 'dev', 'prod') is determined by the APP_ENV environment variable.
    """
    with open(path, "r") as f:
        raw_config = yaml.safe_load(f)

    # Determine the environment from an environment variable, defaulting to 'dev'.
    # 通过环境变量决定环境，默认为 'dev'。
    env = os.getenv("APP_ENV", "dev")

    # Get the configuration for the specified environment.
    env_config = raw_config.get(env)
    if not env_config:
        raise ValueError(f"Configuration for environment '{env}' not found in {path}")

    config_obj = from_dict(data_class=SyncConfig, data=env_config)

    # Allow hdfs_model_config_path to be overridden by an environment variable.
    env_override = os.getenv("HDFS_MODEL_CONFIG_PATH")
    if env_override:
        config_obj.hdfs_model_config_path = env_override

    # Ensure the path is set from either the file or the environment variable.
    if not config_obj.hdfs_model_config_path:
        raise ValueError(
            f"hdfs_model_config_path must be set in config.yml or via the HDFS_MODEL_CONFIG_PATH environment variable for environment '{env}'."
        )

    return config_obj
