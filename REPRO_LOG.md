# REPRO_LOG

## 2026-04-23 环境初始化记录（阶段：最小闭环准备）

### Step 1: 基础环境探测
执行命令：
```bash
python3 --version
```
结果：
- Python 版本为 `3.10.19`。

### Step 2: 创建虚拟环境并尝试升级安装工具
执行命令：
```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip setuptools wheel
```
安装失败点：
- 当前环境访问 PyPI 受限，出现 `ProxyError: Tunnel connection failed: 403 Forbidden`。
- `wheel` 下载失败，报错 `No matching distribution found for wheel`（由网络不可达触发）。

修复方式：
- 调整策略为“最小改动 + 可重放”：
  1. 不依赖本次会话必须在线升级工具链；
  2. 在 `setup_repro.sh` 中保留标准安装流程，供有网络条件的复现实验机直接执行；
  3. 对 Linux 环境加入 `appnope` 过滤，避免非网络类的安装失败。

### Step 3: 现有运行时依赖可用性快速检查（不下载新包）
执行命令：
```bash
python3 - <<'PY'
import importlib
mods=['torch','diffusers','accelerate','bitarray','reedsolo','reedmuller','png']
for m in mods:
    try:
        importlib.import_module(m)
        print(m, 'OK')
    except Exception as e:
        print(m, 'MISSING', type(e).__name__)
PY
```
结果：
- 上述关键包在当前容器中均可 import。

### Step 4: 依赖文件完整性审查与最小补充
审查对象：`requirements.txt`
发现：
- `torch` 未锁版本（可能导致跨时间漂移）。
- `appnope==0.1.4` 为 macOS 依赖，Linux 安装会失败。

修复动作：
- 新增 `setup_repro.sh`：
  - 先安装 `torch==2.2.2`（最小补充，避免大版本漂移）。
  - Linux 下安装前过滤 `appnope`。
  - 设置 Hugging Face 缓存路径并预拉默认模型。

### Step 5: SageMath 必需性判定
判定结论：
- 最小 encode/decode 闭环：可先不依赖 SageMath。
- 完整论文复现主表：需要 SageMath（`sage/sage_encode.sage` / `sage/sage_decode.sage` 路径）。

### 额外备注：怀疑的论文期版本
- `README.md` 明确测试栈：Ubuntu 22.04、Python 3.10.14、SageMath 10.3。
- `pulsar.py` 注释引用 `diffusers` 旧版本实现链接（v0.17.1），**怀疑是论文期相关版本线索**。
- 当前 `requirements.txt` 锁定 `diffusers==0.27.2`，与注释中的历史版本存在代际差异，后续若出现行为偏差需优先核查。

## 2026-04-23 最小 encode/decode 闭环尝试（单模型单次）

### 目标与参数
- 模型：`google/ddpm-church-256`（优先单模型、默认最易路径）
- 测试消息：`hello_pulsar`
- 执行脚本：`./run_minimal.sh`
- 工件目录：`artifacts/minimal/20260423T043056Z/`

### 已保存工件
- 输入消息：`artifacts/minimal/20260423T043056Z/input_message.txt`
- 输出图像路径（计划）：`artifacts/minimal/20260423T043056Z/stego.png`（本次未生成，见失败说明）
- 解码结果：`artifacts/minimal/20260423T043056Z/status.json` 中 `decoded_message=null`
- 关键日志：
  - `artifacts/minimal/20260423T043056Z/key.log`
  - `artifacts/minimal/20260423T043056Z/error_traceback.log`
  - `artifacts/minimal/20260423T043056Z/status.json`

### 失败排查（按模板）
- 失败阶段：`权重下载`（触发于 encode 初始化阶段，模型加载前）
- 报错堆栈：
  - 见 `artifacts/minimal/20260423T043056Z/error_traceback.log`
  - 关键错误：`ProxyError: Tunnel connection failed: 403 Forbidden`
  - 关键错误：`OSError: Can't load config for 'google/ddpm-church-256'`
- 根因假设：
  1. 当前执行环境无法通过代理访问 `huggingface.co`；
  2. 本地 Hugging Face 缓存中没有该模型（`config.json` 缺失）；
  3. 因模型未加载，后续 encode/image save/decode 均无法进行。
- 已验证了什么：
  1. 使用 `local_files_only=True` 验证本地缓存不存在该模型；
  2. 直接 `from_pretrained` 验证联网下载路径失败，报 403 代理错误；
  3. `run_minimal.sh` 已真实执行，并落盘输入/状态/堆栈等工件。
- 下一步最小修复方案：
  1. 在可联网机器执行一次 `run_minimal.sh` 或 `UNet2DModel.from_pretrained('google/ddpm-church-256')` 预拉权重；
  2. 将 Hugging Face 缓存目录拷贝到本仓库 `.cache/huggingface/`（或设置 `HF_HOME` 指向已有缓存）；
  3. 复跑 `./run_minimal.sh`，预期进入 image save 与 decode 阶段并验证 `hello_pulsar` 一致性。
