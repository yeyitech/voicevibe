# Releasing

## Tag release

GitHub Actions 会在推送 `v*` tag 时自动构建发布包。

例如:

```bash
git tag v0.1.0
git push origin v0.1.0
```

工作流会:

1. 在 `macos-14` 构建 `arm64`
2. 在 `macos-13` 构建 `x64`
3. 产出 `.dmg` 和 `.zip`
4. 自动挂到对应 GitHub Release

## Local packaging

```bash
npm install
npm run dist:mac:arm64
npm run dist:mac:x64
```

构建产物默认输出到:

```bash
release/
```

## Notes

- 当前工作流默认不做代码签名和 notarization
- `CSC_IDENTITY_AUTO_DISCOVERY=false` 已在 CI 中关闭
- 如果后续需要正式签名，可在 workflow 中补充 Apple 证书和 notarization 凭据
