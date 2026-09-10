# 3X-UI + Tailscale Docker Compose 部署与运维指南

本文档用于在 Linux VPS 上通过 Docker Compose 部署 3X-UI 和 Tailscale。

部署采用 Tailscale Sidecar 网络模式：3X-UI 与 Tailscale 共享网络命名空间，3X-UI 管理面板不映射到公网，只允许已经加入同一
Tailnet 的设备访问；Xray 入站端口按需映射到公网。

> 本方案面向 Linux VPS（推荐 Ubuntu/Debian）。由于使用 `/dev/net/tun` 和内核网络模式，不适用于 macOS Docker Desktop。

## 一、部署结构

- `tailscale`：将容器加入 Tailnet，并提供专用的 Tailscale IP。
- `3xui`：运行 3X-UI 面板和 Xray-core，与 `tailscale` 共享网络。
- `2053/TCP`：3X-UI 管理端口，仅通过 Tailscale 访问，不映射到公网。
- `443/TCP`、`443/UDP`：示例 Xray 公网入站端口，可通过 `.env` 修改。
- `2096/TCP`：示例订阅服务端口，默认不公开。

主要访问链路：

```text
管理设备 → Tailscale → 3X-UI 管理面板
代理客户端 → VPS 公网端口 → Xray-core → 目标网站
```

## 二、前置条件

部署前需要：

1. 一台支持 TUN 的 Linux VPS。
2. 已安装 Docker Engine 和 Docker Compose Plugin。
3. 一个 Tailscale 账户。
4. VPS 防火墙或云安全组管理权限。

检查 Docker：

```bash
docker --version
docker compose version
```

检查 TUN：

```bash
ls -l /dev/net/tun
```

如果设备不存在，可以尝试：

```bash
sudo modprobe tun
```

如果仍不存在，需要确认 VPS 虚拟化平台是否允许使用 TUN。

## 三、目录结构

建议将相关文件放在独立目录中：

- `docker-compose.yml`：容器编排配置。
- `.env`：真实环境变量和 Tailscale Auth Key，不提交 Git。
- `.env.example`：环境变量示例，可提交 Git。
- `data/tailscale/`：Tailscale 节点身份和状态。
- `data/3x-ui/db/`：3X-UI SQLite 数据库。
- `data/3x-ui/cert/`：证书文件。
- `data/3x-ui/acme/`：ACME 证书签发和续期状态。
- `backups/`：本地备份文件，不提交 Git。

创建目录：

```bash
mkdir -p ~/3xui-tailscale/data/tailscale
mkdir -p ~/3xui-tailscale/data/3x-ui/{db,cert,acme}
mkdir -p ~/3xui-tailscale/backups
cd ~/3xui-tailscale
```

## 四、Docker Compose 配置

创建 `docker-compose.yml`：

```yaml
services:
  tailscale:
    image: tailscale/tailscale:latest
    container_name: tailscale-3xui
    hostname: "${TS_HOSTNAME:-3x-ui-vps}"
    environment:
      TS_AUTHKEY: "${TS_AUTHKEY:?TS_AUTHKEY must be set in .env}"
      TS_HOSTNAME: "${TS_HOSTNAME:-3x-ui-vps}"
      TS_STATE_DIR: /var/lib/tailscale
      TS_AUTH_ONCE: "true"
      TS_USERSPACE: "false"
      TS_ACCEPT_DNS: "true"
    volumes:
      - ./data/tailscale:/var/lib/tailscale
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - NET_RAW
    ports:
      # 只向公网发布 Xray 入站端口
      - "${XRAY_TCP_PORT:-443}:${XRAY_TCP_PORT:-443}/tcp"
      - "${XRAY_UDP_PORT:-443}:${XRAY_UDP_PORT:-443}/udp"

      # 需要公开订阅服务时再取消注释
      # - "${XUI_SUB_PORT:-2096}:${XUI_SUB_PORT:-2096}/tcp"
    restart: unless-stopped

  3xui:
    image: ghcr.io/mhsanaei/3x-ui:latest
    container_name: 3xui
    network_mode: "service:tailscale"
    depends_on:
      - tailscale
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      XUI_ENABLE_FAIL2BAN: "true"
      XUI_PORT: "${XUI_PANEL_PORT:-2053}"
      XUI_INIT_WEB_BASE_PATH: "${XUI_WEB_BASE_PATH:-/xui-admin}"
      XUI_LOG_LEVEL: "info"
    volumes:
      - ./data/3x-ui/db:/etc/x-ui
      - ./data/3x-ui/cert:/root/cert
      - ./data/3x-ui/acme:/root/.acme.sh
    cap_add:
      - NET_ADMIN
      - NET_RAW
    tty: true
    restart: unless-stopped
```

注意：

- `ports` 必须配置在 `tailscale` 服务下，因为 `3xui` 共享其网络空间。
- 不要给 `3xui` 再添加 `ports`，否则 Compose 会因共享网络模式而报错。
- 目前只有配置在 `ports` 中的 Xray 入站端口才能从公网访问。
- 3X-UI 面板端口 `2053` 没有映射到宿主机公网。

## 五、配置 `.env`

### 5.1 创建 Tailscale Auth Key

打开 Tailscale 管理后台：

- Auth Keys：<https://login.tailscale.com/admin/settings/keys>
- Machines：<https://login.tailscale.com/admin/machines>

建议创建一次性、非 Ephemeral 的 Auth Key。容器认证完成后，身份会保存在 `data/tailscale/` 中。

### 5.2 创建环境变量

创建 `.env`：

```dotenv
TS_AUTHKEY=tskey-auth-REPLACE_ME
TS_HOSTNAME=3x-ui-vps

XUI_PANEL_PORT=2053
XUI_WEB_BASE_PATH=/replace-with-a-long-random-path

XRAY_TCP_PORT=443
XRAY_UDP_PORT=443

# 只有公开订阅服务时才需要
# XUI_SUB_PORT=2096
```

设置权限：

```bash
chmod 600 .env
```

变量说明：

| 变量                  | 用途                             | 默认值          |
|---------------------|--------------------------------|--------------|
| `TS_AUTHKEY`        | Tailscale 容器首次加入 Tailnet 使用的密钥 | 必填           |
| `TS_HOSTNAME`       | Tailscale Machines 页面显示的设备名    | `3x-ui-vps`  |
| `XUI_PANEL_PORT`    | 3X-UI 管理面板端口                   | `2053`       |
| `XUI_WEB_BASE_PATH` | 面板访问路径，仅首次创建数据库时生效             | `/xui-admin` |
| `XRAY_TCP_PORT`     | 映射到公网的 Xray TCP 端口             | `443`        |
| `XRAY_UDP_PORT`     | 映射到公网的 Xray UDP 端口             | `443`        |
| `XUI_SUB_PORT`      | 可选的公开订阅服务端口                    | `2096`       |

不要在 `.env` 中使用示例密钥，也不要将真实密钥提交到 Git。

## 六、Git 忽略配置

推荐 `.gitignore`：

```gitignore
# 密钥和本地环境变量
.env
.env.*
!.env.example

# 数据库、证书、Tailscale 节点身份
data/

# 本地备份
backups/
*.tar.gz
```

可提交一个不包含真实密钥的 `.env.example`：

```dotenv
TS_AUTHKEY=tskey-auth-REPLACE_ME
TS_HOSTNAME=3x-ui-vps
XUI_PANEL_PORT=2053
XUI_WEB_BASE_PATH=/replace-with-a-long-random-path
XRAY_TCP_PORT=443
XRAY_UDP_PORT=443
# XUI_SUB_PORT=2096
```

如果 `.env` 已经被 Git 跟踪：

```bash
git rm --cached .env
git add .gitignore
git commit -m "chore: ignore local environment and runtime data"
```

如果真实 Auth Key 曾经推送到远程仓库，必须在 Tailscale 后台撤销并重新生成，加入 `.gitignore` 不能清除 Git 历史中的密钥。

## 七、启动和验证

先进行无输出的配置校验，避免把展开后的密钥打印到终端：

```bash
docker compose config --quiet
```

拉取并启动容器：

```bash
docker compose pull
docker compose up -d
```

检查状态：

```bash
docker compose ps
```

检查 Tailscale 日志和连接状态：

```bash
docker compose logs --tail=100 tailscale
docker compose exec tailscale tailscale status
docker compose exec tailscale tailscale ip -4
```

检查 3X-UI 日志：

```bash
docker compose logs --tail=100 3xui
```

查看 3X-UI 当前设置：

```bash
docker compose exec 3xui /app/x-ui setting -show
```

该命令可能显示登录信息，避免把输出粘贴到公共渠道。

## 八、访问 3X-UI 面板

首先确保当前电脑已经安装 Tailscale，并加入同一个 Tailnet。

获取服务器 Tailscale IPv4：

```bash
docker compose exec tailscale tailscale ip -4
```

假设输出为 `100.80.10.20`，`.env` 中路径为 `/replace-with-a-long-random-path`，访问：

```text
http://100.80.10.20:2053/replace-with-a-long-random-path/
```

如果 Tailnet 开启了 MagicDNS，也可以尝试：

```text
http://3x-ui-vps:2053/replace-with-a-long-random-path/
```

首次登录后立即完成：

1. 修改默认管理员用户名和密码。
2. 开启 TOTP 双因素认证。
3. 确认管理路径不是默认值。
4. 不要在云安全组中开放 `2053`。
5. 在 Tailscale ACL/Grants 中限制哪些用户或设备可以访问该节点。

`XUI_INIT_WEB_BASE_PATH` 只在首次创建数据库时生效。已有数据库需要在 3X-UI 面板设置中修改访问路径。

## 九、配置 Xray 入站端口

默认 Compose 映射：

```text
443/TCP → 共享网络空间的 443/TCP
443/UDP → 共享网络空间的 443/UDP
```

因此，在 3X-UI 中创建入站时，监听端口也应设置为 `443`。

常见对应关系：

| 协议/传输                   | 常用网络 | 需要开放      |
|-------------------------|------|-----------|
| VLESS + TCP + REALITY   | TCP  | `443/TCP` |
| VLESS/VMess + WebSocket | TCP  | 对应 TCP 端口 |
| Trojan                  | TCP  | 对应 TCP 端口 |
| Hysteria2               | UDP  | 对应 UDP 端口 |
| WireGuard               | UDP  | 对应 UDP 端口 |

如果公网 `443` 已被 Nginx、Caddy 或其他服务占用，修改 `.env`：

```dotenv
XRAY_TCP_PORT=8443
XRAY_UDP_PORT=8443
```

同时将 3X-UI 入站监听端口改为 `8443`，然后重新应用配置：

```bash
docker compose up -d
```

检查宿主机端口占用：

```bash
sudo ss -lntup
```

### 多个入站端口

如需多个公网端口，在 `tailscale.ports` 下增加：

```yaml
ports:
  - "443:443/tcp"
  - "8443:8443/tcp"
  - "8443:8443/udp"
  - "10000-10010:10000-10010/tcp"
```

修改后执行：

```bash
docker compose up -d
```

## 十、防火墙和云安全组

推荐策略：

| 端口         | 来源                  | 是否开放       |
|------------|---------------------|------------|
| `2053/TCP` | 公网                  | 不开放        |
| `443/TCP`  | 代理客户端               | 根据入站协议开放   |
| `443/UDP`  | 代理客户端               | 仅 UDP 协议需要 |
| `2096/TCP` | 订阅客户端               | 默认不开放      |
| SSH 端口     | 固定管理 IP 或 Tailscale | 严格限制       |

如果只准备通过 Tailscale 管理服务器，不要为了访问面板开放 `2053`。

## 十一、订阅服务管理

如果所有客户端都在同一 Tailnet，可以不公开订阅端口，直接通过 Tailscale IP 访问订阅服务。

如果必须向公网提供订阅：

1. 在 3X-UI 中开启 Subscription Service。
2. 配置 HTTPS 证书。
3. 使用不可预测的订阅路径和客户端 Sub ID。
4. 取消 Compose 中 `2096` 的注释。
5. 在云安全组中开放对应 TCP 端口。
6. 执行 `docker compose up -d`。

不要把 3X-UI 管理面板和订阅服务混用同一个公开入口。

## 十二、常用管理命令

### 查看容器

```bash
docker compose ps
```

### 查看日志

```bash
docker compose logs -f 3xui
docker compose logs -f tailscale
docker compose logs --since=30m 3xui
```

### 重启服务

```bash
docker compose restart 3xui
docker compose restart tailscale
```

如果重建了 Tailscale 容器后共享网络异常，同时重建两个服务：

```bash
docker compose up -d --force-recreate tailscale 3xui
```

### 停止和启动

```bash
docker compose stop
docker compose start
```

### 查看 Tailscale 信息

```bash
docker compose exec tailscale tailscale status
docker compose exec tailscale tailscale ip -4
docker compose exec tailscale tailscale netcheck
```

### 测试 Tailnet 节点

```bash
docker compose exec tailscale tailscale ping <目标设备名或Tailscale-IP>
```

## 十三、更新

更新前先备份 3X-UI 数据库。

```bash
docker compose pull
docker compose up -d
docker compose ps
docker compose logs --since=10m 3xui
docker compose logs --since=10m tailscale
```

Docker 部署不要使用容器内部的 3X-UI 更新功能，应通过拉取镜像并重新创建容器完成更新。

当前配置使用 `latest` 标签，适合个人环境快速更新。如果需要更强的可重复性，应在验证后把镜像标签固定到具体版本，例如：

```yaml
image: ghcr.io/mhsanaei/3x-ui:<已验证版本>
image: tailscale/tailscale:<已验证版本>
```

## 十四、备份与恢复

### 14.1 备份 3X-UI

为确保 SQLite 数据一致，建议短暂停止 3X-UI：

```bash
docker compose stop 3xui
tar -czf "backups/3xui-data-$(date +%Y%m%d-%H%M%S).tar.gz" data/3x-ui
docker compose start 3xui
```

备份文件包含数据库、证书和 ACME 状态，应按敏感文件保存。

### 14.2 备份 Tailscale 状态

`data/tailscale/` 包含节点身份。一般可以通过重新认证恢复，但如需保留同一节点身份，可以单独备份：

```bash
docker compose stop 3xui
docker compose stop tailscale
tar -czf "backups/tailscale-state-$(date +%Y%m%d-%H%M%S).tar.gz" data/tailscale
docker compose start tailscale
docker compose start 3xui
```

Tailscale 状态备份属于敏感数据，不要上传到公共仓库或未加密的公共存储。

### 14.3 恢复前检查

恢复之前：

1. 先备份当前数据目录。
2. 确认备份文件来源可信且完整。
3. 停止容器。
4. 将备份解压到项目根目录。
5. 检查文件权限后重新启动。

不要直接覆盖唯一的数据副本；建议先将当前目录改名保留，再执行恢复。

## 十五、停止与卸载

停止并删除容器和 Compose 网络资源：

```bash
docker compose down
```

上述命令不会删除绑定挂载的 `data/` 数据。

若要彻底卸载：

1. 先执行备份。
2. 在 Tailscale Machines 页面移除对应设备。
3. 执行 `docker compose down`。
4. 确认备份可用后，再手动删除项目数据目录。

## 十六、故障排查

### `TS_AUTHKEY must be set in .env`

原因：当前目录不存在 `.env`，或者没有配置 `TS_AUTHKEY`。

检查：

```bash
pwd
ls -la .env docker-compose.yml
```

### Tailscale 容器无法启动，提示 `/dev/net/tun` 不存在

检查：

```bash
ls -l /dev/net/tun
sudo modprobe tun
docker compose logs tailscale
```

如果宿主机不允许 TUN，需要联系 VPS 提供商或更换支持 TUN 的实例。

### Tailscale Machines 中看不到服务器

```bash
docker compose logs --tail=200 tailscale
docker compose exec tailscale tailscale status
```

重点检查：

- Auth Key 是否过期或已撤销。
- Auth Key 是否包含不可见字符。
- VPS 是否能访问 Tailscale 控制服务。
- `data/tailscale/` 是否可写。

### 能看到 Tailscale 节点，但无法访问面板

```bash
docker compose ps
docker compose logs --tail=200 3xui
docker compose exec 3xui /app/x-ui setting -show
docker compose exec tailscale tailscale ip -4
```

确认：

- 使用的是 Tailscale IP，而不是公网 IP。
- 面板端口与 `XUI_PANEL_PORT` 一致。
- URL 包含正确的 `XUI_WEB_BASE_PATH`。
- 当前设备已经加入同一个 Tailnet。
- Tailscale ACL/Grants 没有拒绝访问。

### 修改 `XUI_WEB_BASE_PATH` 后没有生效

`XUI_INIT_WEB_BASE_PATH` 只在首次创建数据库时生效。已有数据时，请登录 3X-UI 面板修改，或者使用 3X-UI
官方管理命令调整；不要为了修改路径删除数据库。

### Xray 节点从公网无法连接

依次检查：

1. 3X-UI 入站是否已经启动。
2. 入站监听端口是否与 Compose 容器端口一致。
3. 该端口是否配置在 `tailscale.ports` 中。
4. TCP/UDP 类型是否正确。
5. 云安全组和宿主机防火墙是否放行。
6. 域名解析、TLS/REALITY 参数是否正确。
7. 公网端口是否被其他服务占用。

### 更新后 3X-UI 网络异常

由于 3X-UI 依赖 Tailscale 的网络命名空间，可以同时重建：

```bash
docker compose up -d --force-recreate tailscale 3xui
```

数据保存在绑定挂载目录中，重建容器不会删除数据库。

## 十七、安全检查清单

- [ ] `.env`、`data/`、`backups/` 已加入 `.gitignore`。
- [ ] Tailscale Auth Key 没有提交到 Git。
- [ ] 3X-UI 管理端口 `2053` 未向公网开放。
- [ ] 已修改管理员默认账号和密码。
- [ ] 已启用 TOTP 双因素认证。
- [ ] 管理路径使用较长的随机值。
- [ ] Tailscale ACL/Grants 仅允许管理设备访问。
- [ ] 云安全组只开放实际需要的 Xray 端口。
- [ ] 公开订阅服务使用 HTTPS 和不可预测的 Sub ID。
- [ ] 定期备份 `data/3x-ui/` 并验证恢复流程。
- [ ] 更新前检查版本说明并执行备份。

## 十八、官方资料

- 3X-UI：<https://github.com/MHSanaei/3x-ui>
- 3X-UI 安装文档：<https://github.com/MHSanaei/3x-ui/wiki/Installation>
- Tailscale Docker：<https://tailscale.com/docs/features/containers/docker>
- Tailscale Docker 参数：<https://tailscale.com/docs/features/containers/docker/docker-params>
- Tailscale Auth Keys：<https://tailscale.com/docs/features/access-control/auth-keys>
- Docker Compose：<https://docs.docker.com/compose/>

## 十九、快速命令摘要

```bash
# 校验
docker compose config --quiet

# 启动
docker compose pull
docker compose up -d

# 状态
docker compose ps
docker compose exec tailscale tailscale status
docker compose exec tailscale tailscale ip -4

# 日志
docker compose logs -f 3xui
docker compose logs -f tailscale

# 重启
docker compose restart 3xui
docker compose restart tailscale

# 更新
docker compose pull
docker compose up -d

# 停止但保留容器
docker compose stop

# 删除容器但保留 data 目录
docker compose down
```
