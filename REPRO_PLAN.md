# REPRO_PLAN

## 当前阶段：最小 encode/decode 闭环

- [x] 补充一条可执行最小链路脚本：`run_minimal.sh`
- [x] 固定单模型单次参数（`google/ddpm-church-256` + `hello_pulsar`）
- [x] 实际执行一次闭环命令并产出工件（当前因权重下载失败中断于 encode 前）
- [x] 将失败栈、根因假设、验证项、最小修复路径写入 `REPRO_LOG.md`
- [ ] 下一步：在可访问 Hugging Face 或已具备本地缓存的环境复跑 `./run_minimal.sh`，完成 stego 保存与 decode 比对
