# LittleLife

[English](README.md) | [简体中文](README.zh-CN.md)

LittleLife 是一个开源、可自托管的家庭成长时间线与长期媒体档案系统。故事使用
Markdown/YAML 保存，原始照片、视频和音频以普通文件保存。因此，即使网站、容器或
CMS 不再可用，档案仍然可以直接读取和迁移。

代码公开并允许任何人使用。每个部署实例的家庭资料、账号凭据和备份密钥都保存在用户
自己控制的存储中，不应提交到本仓库。

## 为什么选择 LittleLife

- **开放档案：** 主数据不依赖数据库。
- **保留原始媒体：** 上传的源文件保持原样，并使用 SHA-256 清单校验。
- **网站可替换：** Grav 只是普通文件之上的浏览与编辑层。
- **源数据与衍生数据分离：** 预览、生成页面和缓存都可以重新构建。
- **部署可迁移：** 已在 Linux ARM64 和 amd64 上验证 Docker Compose 部署。
- **备份可恢复：** Restic + rclone 脚本支持一个必选仓库和一个可选的独立第二仓库，
  并提供检查与全新目录恢复流程。
- **运维保守：** 包含挂载前置检查、任务锁、最小权限管理员、人工确认清理和可回滚部署。

## 已包含的功能

- 登录后创建和编辑时间线记录
- 上传原始照片、视频和音频，并安全处理同名文件
- 按年份、月份、标签和里程碑筛选
- 家庭资料页和时间线页面
- 审计/历史记录与 SHA-256 完整性检查
- 开放格式 ZIP 导出
- 每 6 小时备份、每周仓库检查、每月数据包与媒体校验
- 固定 Grav/插件版本以及离线插件包工作流

## 开始使用

请阅读[公开快速开始指南](docs/17-public-quickstart.md)，在带 Docker 的 Linux 主机上
运行虚构演示数据。部署目录必须位于真实挂载的数据文件系统中；前置检查会主动拒绝
未挂载或不安全的目标路径。

如需了解设计和数据规范，请继续阅读：

- [实施设计](docs/01-implementation-design.md)
- [目录映射](docs/03-directory-mapping.md)
- [备份与恢复方案](docs/04-backup-recovery-plan.md)
- [管理员使用说明](docs/11-admin-user-guide.md)
- [离线恢复包说明](docs/14-offline-recovery-pack.md)

## 参考部署状态

参考部署已通过原生 ARM64 应用、最小权限、相互独立的 Google Drive 与百度网盘备份、
仓库检查及全新目录恢复验收。公网入口是可选项，纯局域网部署不依赖公网入口。记录证据
与已接受的例外见 [Google Drive 验收记录](docs/16-google-drive-backup-acceptance.md) 和
[百度仓库 B 验收记录](docs/18-baidu-backup-acceptance.md)。

## 仓库目录

```text
app/             Grav 主题和极薄集成代码
config/          非敏感配置模板
data-schema/     机器可读的档案规范
examples/        仅包含虚构测试档案
scripts/         验证、完整性、备份和恢复工具
deploy/          纳入版本控制的部署模板
docs/            设计、风险、运行手册和审计记录
tests/           自动化测试
```

请勿提交真实家庭媒体或记录、OAuth Token、管理员凭据、Restic 密码、`rclone.conf`、
私钥或目标网络信息。可选 Google Drive 集成及其有限数据使用范围见
[隐私政策](docs/15-privacy-policy.md)。

## 许可证

LittleLife 使用 [MIT License](LICENSE)。
