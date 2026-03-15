# AI Collaboration Instructions

本仓库支持与 AI 编程代理协作开发。

## 必读顺序

在开始修改前，请按以下顺序阅读：

1. `PROJECT_RULES.md`
2. `docs/ai-context.md`
3. `docs/architecture.md`
4. `docs/todo.md`
5. `AI_COMMANDS.md`

## 命令调用规则

当用户使用 `执行【命令名称】` 这类格式时：

1. 在 `AI_COMMANDS.md` 中匹配同名命令。
2. 按命令模板中的步骤顺序执行。
3. 若未找到命令，明确告知不可用，并列出可用命令。

## 默认协作流程

1. 先理解当前项目上下文。
2. 从 `docs/todo.md` 选择任务，或接收用户明确指定的任务。
3. 明确实现边界和验证方式。
4. 完成最小可验证改动。
5. 在必要时同步更新文档。

## 文档维护规则

当项目状态发生变化时，优先检查并更新：

- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/todo.md`
- `docs/dev-log.md`

## 目标

让新会话、新设备和 AI 代理都能快速恢复上下文，并持续推进 `{{PROJECT_NAME}}`。
