# LittleLife 管理后台使用说明

## 登录

在家庭局域网中打开：

`http://ROUTER_LAN_IP:8080/admin2`

其中 `ROUTER_LAN_IP` 是路由器当前的局域网地址；真实地址只保存在部署环境中。

用户名为 `littlelife`。初始密码只保存在 S20M 的
`/mnt/mmcblk0p6/littlelife/secrets/admin-password.txt`，权限为 `0600`；它不在 Git、
镜像或发布包中。首次正式使用后应在 Admin2 的用户设置中更换强密码，并把新密码加入
两份分开保管的离线恢复包。

登录后，从左侧选择 **LittleLife 档案**。不要用通用的 **Pages** 页面编辑成长档案；
Pages 中显示的是可删除、可重建的展示副本。默认管理员账号仅具有 LittleLife 档案
读写权限，无权通过通用 API 修改 Pages、插件或系统配置。

如果从旧部署升级，可在路由器上执行 `deploy/restrict-admin-permissions.sh` 收紧已有
账号；脚本会先把原账号文件保存到 `rollback/`。

## 新建记录

最快的方法是在网站首页或顶部导航选择 **＋ 添加记录**。未登录时会先显示登录页，
登录后直接进入 LittleLife 档案表单；网站的首页和时间线仍可免登录浏览。

1. 点击文件区域选择照片、视频或音频；电脑也可以直接拖放。一次最多 20 个文件，
   每个文件上限 512 MiB。
2. 检查缩略图和自动带入的文件拍摄/修改时间。标题、正文和标签均可不填；空标题会
   自动按日期生成。
3. 选择“保存记录并上传”。

需要精细整理时，可再填写类型、标签和 Markdown 正文，或从左侧选择旧记录编辑。

保存成功后：

- 正文进入 `data/entries/YYYY/<id>.md`；
- 原始媒体进入 `data/media-originals/YYYY/YYYY-MM-DD/`；
- 媒体 SHA-256 清单被更新；
- `derived/grav-pages` 被重新生成；
- 操作进入 `data/manifests/audit.jsonl`。

原始媒体只追加且不会被同名覆盖。界面故意不提供删除原始媒体的按钮。

## 浏览与筛选

打开 `/timeline` 后，可按年份、月份、标签文字和“只看里程碑”组合筛选。页面会显示
当前命中条数；点击“清除筛选”恢复全部记录。筛选只影响浏览，不会修改档案文件。

## 编辑、校验和导出

- 从左侧选择记录即可编辑正文、标题、类型和标签。事件日期及稳定 ID 在创建后固定。
- 每次编辑前，旧 Markdown 会保存到 `data/manifests/history/<id>/`。
- “完整性检查”验证全部记录引用和媒体 SHA-256。
- “重建网站”只重建展示副本，不改原始媒体。
- “导出开放格式 ZIP”生成并下载只含普通 Markdown/YAML、原始媒体和清单的 ZIP。

## 失败时怎么办

如果保存失败，不要重复删除或移动原始文件。先记下错误提示，再检查：

- `/mnt/mmcblk0p6` 是否仍为 ext4 挂载；
- `littlelife-grav` 是否健康；
- `data/` 和 `derived/` 是否由 UID/GID 1000 可写；
- `runtime/grav-config/www/logs/grav.log` 与容器日志。

修改前快照和审计日志可用于人工核对；恢复默认写到 `backup/restores/` 新目录，禁止直接
覆盖当前档案。
