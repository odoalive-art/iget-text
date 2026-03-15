# 开发日记模板

适合记录单次开发推进、问题排查和验收结论。

```md
## YYYY-MM-DD

Topic:
- 本次主要处理什么

Goal:
- 这次想解决的问题
- 期望达到的结果

Context:
- 当前背景
- 相关限制
- 为什么现在做这件事

Work Done:
- 实际完成了什么
- 做了哪些实现或调整

Key Decisions:
- 这次作出的关键选择
- 为什么这样做

Files Touched:
- `path/to/file`
- `path/to/another-file`

Validation:
- 运行了什么命令
- 手动验证了什么
- 结果如何

Issues / Surprises:
- 遇到的异常
- 中途发现的新问题

Next Steps:
- 接下来建议继续做什么
- 哪些点还需要复查

Notes:
- 其他想给未来自己的提醒
```

## 快速版

适合只想记最核心信息时使用。

```md
## YYYY-MM-DD

Today:
- 做了什么

Result:
- 当前结果

Next:
- 下一步
```

## 使用建议

- `docs/dev-log.md` 更适合项目级、可交接记录。
- 这个模板更适合你写当天的思路、尝试过程和判断依据。
- 如果某次改动较大，可以先写这里，再把结论浓缩进 `docs/dev-log.md`。
