# Tritium 维护知识库

这里保存仍对开发、排障和发布有用的当前事实。`AGENT_HANDOFF.md` 只保留短入口，
专题细节在这里维护，避免交接文档无限增长。

## 推荐阅读顺序

1. [当前状态](status/current.md)
2. [待办与真机边界](status/pending.md)
3. [测试约定](operations/testing.md)
4. 当前任务对应的专题页

## 知识地图

- 产品：[产品原则](product/principles.md)、[隐私与安全](product/privacy.md)
- 架构：[概览](architecture/overview.md)、[网络与登录](architecture/networking.md)、
  [存储与缓存](architecture/storage-and-cache.md)、[路由与状态](architecture/routing-state.md)
- 设计：[Android 设计语言](design/android.md)
- 操作：[测试](operations/testing.md)、[发布与签名](operations/release-build.md)、
  [故障排查](operations/troubleshooting.md)
- 状态：[当前状态](status/current.md)、[待办](status/pending.md)、
  [验证记录](status/verification.md)、[真机验收](status/device-acceptance.md)
- 历史：[决策日志](history/decisions.md)、[发布记录](history/releases.md)

## 维护规则

- 当前行为变化时，同一提交更新相关专题页和 `status/current.md`。
- 新的未完成事项写入 `status/pending.md`；完成后移除并在验证记录留下证据。
- 影响产品边界、数据安全、兼容性或发布流程的选择写入 `history/decisions.md`。
- 发布只通过 annotated tag 触发，并由 `scripts/release.sh` 写入发布记录。
- 故障排查只记录安全的检查点和结论，不粘贴 Cookie、请求签名或完整登录 URL。
- 专题明显变大时再拆分，不创建没有实际内容的占位文档。
