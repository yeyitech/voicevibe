# Contributing

## Scope

VoiceVibe 聚焦桌面语音输入，不做手机端第三方输入法。

开始贡献前，建议先看:

- `README.md`
- `docs/quickstart.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`

优先欢迎的贡献方向:

- 桌面输入体验优化
- provider 接入与稳定性改进
- 词条库能力
- macOS 权限 / 输入回填稳定性
- 文档、快速开始、发布流程

不建议把仓库拉回到:

- iOS 键盘扩展
- Swift 原生双端方向
- SaaS 账号体系

## Development

```bash
npm install
npm run dev
```

构建检查:

```bash
npm run typecheck
npm run build
```

## Pull Requests

提交 PR 时请尽量说明:

1. 你改的是哪个用户场景
2. 是否影响现有 provider 行为
3. 是否改动了权限、录音、插入逻辑
4. 是否做过本地构建或手动验证

仓库已经提供了 PR 模板，请按模板补齐:

- 变更摘要
- 用户影响
- 验证方式
- 风险说明

## Provider changes

如果你增加新的 provider，请同时补齐:

- 设置页字段
- provider 说明文档
- 词条库合并策略
- README 和 Quick Start

## Release

打 `v*` tag 会触发 GitHub Actions 构建 macOS release 包。

## Security

如果你发现的是漏洞或敏感问题，不要开公开 issue。

请按 `SECURITY.md` 里的流程私下报告。
