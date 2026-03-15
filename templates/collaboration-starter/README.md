# Collaboration Starter

这是一套可直接复用到新项目的协作文档初始化包。

## Included Files

```text
collaboration-starter
├── AGENTS.md
├── PROJECT_RULES.md
├── AI_COMMANDS.md
└── docs
    ├── ai-context.md
    ├── architecture.md
    ├── dev-log.md
    ├── git-workflow.md
    ├── regression-cases.md
    └── todo.md
```

## How To Use

1. 将本目录复制到新项目根目录。
2. 用实际项目内容替换所有 `{{PLACEHOLDER}}` 占位符。
3. 优先完成以下字段：
   - `{{PROJECT_NAME}}`
   - `{{PROJECT_TYPE}}`
   - `{{PRIMARY_GOAL}}`
   - `{{TECH_STACK}}`
   - `{{KEY_MODULES}}`
   - `{{MAIN_WORKFLOWS}}`
4. 首次启动协作时，先补齐 `docs/ai-context.md`、`docs/architecture.md` 和 `docs/todo.md`。

## Suggested Adoption Order

推荐按以下顺序完成初始化：

1. `PROJECT_RULES.md`
2. `docs/ai-context.md`
3. `docs/architecture.md`
4. `docs/todo.md`
5. `AI_COMMANDS.md`

## Notes

- 这套模板强调“可交接、可续做”，不是追求写成完整文档站。
- 如果项目很小，可以缩短内容，但建议保留文件角色和阅读顺序。
- 如果项目已经有自己的开发规范，可以把这套模板作为最小协作层叠加上去。
