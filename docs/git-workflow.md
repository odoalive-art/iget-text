# Git Workflow

## Purpose

为 `TextGrabber` 提供一个适合单人多设备或 AI 协作的轻量工作流，目标是：

- 切换设备时容易恢复
- 开发中不丢上下文
- 提交粒度清晰

## Branch Strategy

默认长期分支：

- `main`：稳定主线

任务分支建议：

- `feature/<task-name>`
- `fix/<task-name>`

如果由 Codex 或自动化代理代为创建分支，请遵循当前工作环境要求，使用：

- `codex/<task-name>`

## Daily Start

1. 拉取最新主线
2. 阅读 `AGENTS.md`、`PROJECT_RULES.md`
3. 阅读 `docs/ai-context.md`、`docs/todo.md`
4. 确认今天的目标任务

## Start a New Task

1. 从 `main` 切出任务分支
2. 用短且明确的任务名命名分支
3. 开始前确认需要同步哪些文档

## During Development

1. 保持每次改动范围单一
2. 关键节点执行 `swift build` / `swift test`
3. 如果状态或结构变化，及时更新：
   - `docs/ai-context.md`
   - `docs/architecture.md`
   - `docs/todo.md`

## End of Session

1. 记录当前完成内容
2. 更新待办状态
3. 在 `docs/dev-log.md` 追加会话记录
4. 提交本次变更

## Continue on Another Device

1. 拉取最新代码
2. 阅读 `docs/ai-context.md`
3. 阅读 `docs/dev-log.md` 最近一条记录
4. 查看 `docs/todo.md` 中未完成项

## Merge Back to Main

1. 确认任务分支已完成必要验证
2. 再次检查文档是否与代码一致
3. 合并回 `main`
4. 删除已完成的任务分支

## Conflict Handling

若出现冲突：

1. 优先保留最新的正确实现
2. 重新检查上下文文档是否也需要合并
3. 对于 `docs/todo.md` 和 `docs/dev-log.md`，避免简单覆盖，确认两边内容都被保留

## Collaboration Tips

- 每次会话都尽量留下可接手的上下文
- 不要把隐性决策只留在聊天记录里
- 文档不是为了完美，而是为了减少下一次启动成本
