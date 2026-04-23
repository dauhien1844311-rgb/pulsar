# Pulsar 复现环境说明

本文件目标：把环境整理到“可以尝试一次最小 encode/decode 闭环”的程度，不启动完整 benchmark。

## 1) 最小可用安装方案（优先复用现有依赖）

仓库现有依赖文件：`requirements.txt`。

推荐直接执行：

```bash
bash setup_repro.sh
```

`setup_repro.sh` 的策略：
- 默认创建虚拟环境：`.venv-repro`
- 先安装 `torch==2.2.2`（最小补充，避免 `requirements.txt` 中 `torch` 未锁版本导致漂移）
- 再安装 `requirements.txt`（Linux 下自动过滤 `appnope==0.1.4`，该包是 macOS 专用）
- 预拉取默认模型 `google/ddpm-church-256`

## 2) 依赖完整性与最小补充

### 已发现的不完整点
- `requirements.txt` 中 `torch` 未锁版本。
- `requirements.txt` 中 `appnope==0.1.4` 在 Linux 不可用。

### 采取的最小补充策略
- 不改仓库算法代码，不大规模改依赖文件。
- 在安装脚本中补充 `torch==2.2.2`。
- 在 Linux 环境安装时临时过滤 `appnope`，不改动原文件语义。

## 3) SageMath：最小闭环 vs 完整论文复现

### 最小 encode/decode 闭环（当前阶段）
- **不强制依赖 SageMath**（可先走 `Pulsar.generate()/reveal()` 的最小链路，不进入 region+Sage 编解码）。

### 完整论文复现（主表指标）
- **需要 SageMath**，用于 `SageCode` 相关路径（`sage/sage_encode.sage` 与 `sage/sage_decode.sage`）。

### SageMath 安装方式（推荐与 README 对齐）
```bash
mamba create -n sage sage python=3.10
mamba activate sage
pip install -r requirements.txt
```

### SageMath 调用方式（仓库内）
- 编码/解码脚本由 Python 侧通过 `sage` 命令调用：
  - `sage/sage_encode.sage`
  - `sage/sage_decode.sage`

## 4) 模型权重下载、缓存路径、首次运行准备

### 默认模型来源
- Hugging Face model hub（例如 `google/ddpm-church-256`）。

### 推荐缓存路径（可重复、可迁移）
`setup_repro.sh` 默认设置：

- `HF_HOME=.cache/huggingface`
- `HUGGINGFACE_HUB_CACHE=.cache/huggingface/hub`
- `TRANSFORMERS_CACHE=.cache/huggingface/transformers`

### 首次运行前准备
1. 确认能访问 Hugging Face（或准备离线镜像/已缓存权重）。
2. 执行 `bash setup_repro.sh` 预拉模型。
3. 若网络受限：
   - 手动将模型缓存目录放到上述路径；
   - 或在联网机器预拉后拷贝 `.cache/huggingface/`。

## 5) 本阶段边界

- 不启动 `benchmark.py` 的 100-run 或全量 benchmark。
- 仅将环境推进到“可尝试一次最小 encode/decode”。
