# Git Workflow

## Purpose

为 `{{PROJECT_NAME}}` 提供一个适合单人、多设备或 AI 协作的轻量工作流。

## Branch Strategy

- `main`：稳定主线
- `feature/<task-name>`：功能开发
- `fix/<task-name>`：问题修复
- `codex/<task-name>`：由 Codex 创建的任务分支

## Daily Start

1. 拉取最新代码
2. 阅读 `AGENTS.md`、`PROJECT_RULES.md`
3. 阅读 `docs/ai-context.md`、`docs/todo.md`
4. 确认本次任务

## During Development

1. 保持每次改动范围单一
2. 关键节点执行构建和测试
3. 如果结构或状态变化，更新文档

## End of Session

1. 更新上下文文档
2. 在 `docs/dev-log.md` 记录变更
3. 提交当前任务进度
