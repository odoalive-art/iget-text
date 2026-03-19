# Collaboration Template

## Purpose

该文件整理自其他项目中的协作规范，用来抽取一套跨项目可复用的“原始模板”。

它描述的是结构，不绑定具体业务。

## Template File Set

一套最小可用的协作文档通常包含：

### 1. Root Files

- `AGENTS.md`  
  定义 AI 代理的阅读顺序、工作流和文档同步规则。

- `PROJECT_RULES.md`  
  定义项目目标、技术边界、实现原则、验证要求和 Git 约定。

- `AI_COMMANDS.md`  
  定义 `执行【命令名称】` 这类可复用命令模板。

### 2. docs Files

- `docs/ai-context.md`  
  当前项目上下文、目标、状态、下一步和关键文件。

- `docs/architecture.md`  
  目录结构、模块职责、数据流和依赖关系。

- `docs/todo.md`  
  分优先级维护待办事项与已完成事项。

- `docs/dev-log.md`  
  记录每次会话的关键变更，方便交接。

- `docs/git-workflow.md`  
  规范分支、切换设备、收尾与合并流程。

- `docs/regression-cases.md`  
  提供人工回归检查模板。

## Template Relationships

推荐阅读链路：

1. `PROJECT_RULES.md`
2. `docs/ai-context.md`
3. `docs/architecture.md`
4. `docs/todo.md`
5. `AI_COMMANDS.md`

`AGENTS.md` 负责定义这条阅读顺序，并约束 AI 代理先读什么、再做什么。

## Standard Sections

### `AGENTS.md`

建议包含：

- 必读顺序
- 命令调用规则
- 默认协作流程
- 文档维护规则

### `PROJECT_RULES.md`

建议包含：

- 项目定位
- 技术边界
- 实现原则
- 代码修改规则
- 验证规则
- 文档规则
- Git 规则

### `AI_COMMANDS.md`

建议包含：

- Purpose
- Invocation Format
- Execution Rules
- Command Template Format
- Command Library
- Maintenance

### `docs/ai-context.md`

建议包含：

- Project Overview
- Project Goal
- Current Status
- Current Features
- Development Focus
- Next Session
- Key Files

### `docs/architecture.md`

建议包含：

- Directory Structure
- Modules
- Data Flow
- External Dependencies

### `docs/todo.md`

建议包含：

- High Priority
- Medium Priority
- Low Priority
- Completed

### `docs/dev-log.md`

建议包含：

- Entry Template
- Entries

### `docs/regression-cases.md`

建议包含：

- Goal
- Scope
- 执行方式
- Cases
- Record Template

## Reuse Rules

把模板复用到新项目时，建议遵循：

1. 保留结构，不照搬项目内容。
2. 优先替换项目目标、模块名称、关键文件和待办。
3. 若项目很小，可以减少文档长度，但尽量保留文件角色。
4. 文档要服务交接与续做，而不是追求完整百科化。

## Applied To Current Project

当前 `TextGrabber` 仓库已经按这套模板完成落地，并做了项目化替换：

- 将业务目标替换为 macOS 菜单栏 OCR 工具
- 将架构说明替换为 `TextGrabberKit + TextGrabberApp`
- 将待办替换为快捷键、OCR、结果面板和分发相关任务
- 将回归用例替换为截图、权限、识别结果与设置流程
