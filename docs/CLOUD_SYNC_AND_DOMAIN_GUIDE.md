# TermFlow 保姆级配置指南：从免费领取域名到打通多端实时云同步

TermFlow 采用 **离线优先（本地 SQLite）+ 私人云端（Supabase）** 架构：
- **纯本地使用**：无需注册任何账号，下载安装即可在 Windows 与 Android 上离线秒开使用。
- **多端实时同步**：只需免费创建一个属于你自己的 Supabase 数据库（数据 100% 归你自己掌控），即可实现电脑与手机双向增量同步与秒级推送。

本指南分为两部分：
1. **【基础必读】零成本 5 分钟开通 Supabase 官方地址并完成双端同步**（自带免费 `*.supabase.co` 专属地址，适合绝大多数用户）
2. **【进阶可选】免费领取个人域名 + Cloudflare 反向代理加速**（拥有形如 `https://sync.你的域名.me` 的专属域名，提升国内网络直连稳定性）

---

## 第一部分：5 分钟免费开通 Supabase 云同步（基础必读）

### 1.1 创建免费 Supabase 项目（获取官方二级域名）
1. 打开 [https://supabase.com](https://supabase.com)，点击 **Start your project**，推荐使用 **GitHub 账号一键登录**。
2. 点击 **New project** 新建项目：
   - **Name**：填写 `termflow`
   - **Database Password**：设置一个强密码（仅后台管理备用，日常无需输入）
   - **Region（区域）**：建议选择距离较近的 **Northeast Asia (Tokyo)** 或 **Southeast Asia (Singapore)**
3. 点击 **Create new project**，等待约 1 分钟初始化完成。此时系统已自动为你分配好专属云端地址 `https://<你的项目ID>.supabase.co`。

### 1.2 一键初始化数据表与权限策略
1. 在 Supabase 左侧菜单点击 **SQL Editor** → 点击 **New query**。
2. 打开本仓库中的 [`supabase/schema.sql`](../supabase/schema.sql) 文件，**全选并复制全部 SQL 代码**，粘贴到网页右侧编辑框中。
3. 点击右下角绿色 **Run** 按钮，底部提示 `Success. No rows returned` 即表示 5 张业务表、LWW 冲突保护触发器、RLS 行级隔离策略及 Realtime 实时广播全部就绪。

> **常见报错速修（`code: 42501 permission denied`）**：
> 若使用的是较早期版本 SQL 建表，同步时提示 `permission denied for table semesters (code: 42501)`，只需在 **SQL Editor** 中补跑以下授权语句即可立即恢复：
> ```sql
> GRANT USAGE ON SCHEMA public TO anon, authenticated;
> GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
>   public.semesters, public.goals, public.tasks, public.tags, public.task_tags
> TO authenticated;
> ALTER DEFAULT PRIVILEGES IN SCHEMA public
>   GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
> ```

### 1.3（推荐省心项）关闭注册邮箱验证
如果你只给自己或熟人使用，不想每次注册还要去邮箱翻验证链接：
1. 在 Supabase 左侧菜单点击 **Authentication** → **Sign In / Providers**（或 **Providers**）。
2. 点击展开 **Email**，将 **Confirm email** 开关关闭，点击 **Save** 保存。

### 1.4 找到你的 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`
在新版 Supabase 面板中，**最快的方法只需两步**：
1. 点击项目页面**顶部横栏**（项目名称右侧）的 **`Connect`** 按钮。
2. 在弹窗保持默认的 **`Framework`** 页签，查看右下角 `2 Add files` → **`.env.local`** 代码框：
   - 第一行 `=` 号后面的 `https://xxxxxxxxxxxx.supabase.co` 即为 **`SUPABASE_URL`**；
   - 第二行 `=` 号后面的 `sb_publishable_...`（或在 `Project Settings → API Keys` 中看到的 `eyJ...` 格式 `anon public` key）即为 **`SUPABASE_ANON_KEY`**。

> ⚠️ **安全注意**：只复制 `=` 号后面的值本身（不要连同变量名和 `=` 一起复制），且**切勿**填入 `secret` / `service_role` 私钥。

### 1.5 在 Windows 与 Android 两端完成连接与登录
1. 打开 **Windows 端** `termflow.exe`，点击左上角头像（或左下角 **「外观与云同步设置」**）。
2. 点击 **「配置 Supabase 多设备实时同步」**，粘贴 `SUPABASE_URL` 与 `SUPABASE_ANON_KEY`，点击 **「保存并连接」**。
3. 点击上方 **「登录 / 注册云同步账号」** → 切换 **「注册新账号」**，输入邮箱与至少 6 位密码完成首次注册并自动同步（离线阶段已创建的计划会自动归属到该账号并上传）。
4. 打开 **Android 手机端** TermFlow，点击右上角头像，填入**完全相同的 `SUPABASE_URL` 与 `SUPABASE_ANON_KEY`** 保存连接后，直接登录同一个邮箱账号即可！

---

## 第二部分：免费领取个人域名并配置自定义加速域名（进阶可选）

默认分配的 `https://xxxx.supabase.co` 在部分国内网络环境下直连可能较慢。虽然 Supabase 官方自带的 Custom Domain 功能需要付费 Pro 套餐（$25/月），但我们可以用 **免费域名 + 免费 Cloudflare Workers** 零成本实现专属域名加速（例如 `https://sync.yourdomain.me`），同时完整支持 REST 数据同步与 WebSocket 实时推送！

### 2.1 如何免费（或超低价）领取一个属于自己的域名？

推荐以下 3 个正规可靠渠道：

#### 渠道 A：GitHub 学生开发者包（高校在校生首选，完全免费）
1. 准备学校邮箱（`.edu.cn`）或学信网在线验证报告/学生证，访问 [GitHub Education](https://education.github.com/pack) 申请认证。
2. 认证通过后，在权益列表中可免费领取：
   - **Namecheap**：免费 1 年 **`.me`** 顶级域名（如 `termflow-yourname.me`）
   - **Name.com** 或 **.TECH**：免费 1 年精选后缀域名

#### 渠道 B：DigitalPlat FreeDomain（所有人可用，免费二级域名）
1. 访问公益免费域名平台 [DigitalPlat FreeDomain](https://domain.digitalplat.org/) 注册账号。
2. 免费申请一个 `.dpdns.org` / `.us.kg` 等后缀域名，并在后台将其 Nameservers（NS 服务器）指向 Cloudflare。

#### 渠道 C：超低成本纯数字 `.xyz` 域名（首年与续费均约 ¥7 元/年）
- 若希望长期稳定持有且不想每年折腾续期认证，可在 **Cloudflare Registrar**、**Spaceship** 或 **Porkbun** 搜索 **6~9 位纯数字 `.xyz` 域名**（如 `202688.xyz`），官方定价常年仅约 `$0.80~$0.99/年`（不到一杯奶茶钱），且原生集成 Cloudflare。

---

### 2.2 将域名接入免费 Cloudflare DNS
*(若直接在 Cloudflare 注册则已自动完成，可跳过本节)*
1. 注册并登录 [Cloudflare 控制台](https://dash.cloudflare.com/)，点击 **Add a domain（添加站点）**，输入你刚领到的域名。
2. 选择底部的 **Free（$0 免费计划）** 并继续。
3. Cloudflare 会给出两行形如 `xxx.ns.cloudflare.com` 的名称服务器（Nameservers）。
4. 回到你领域名的网站（如 Namecheap / DigitalPlat）后台，找到 **Custom DNS / Nameservers**，替换为 Cloudflare 给出的两行地址并保存（通常 5~30 分钟生效）。

---

### 2.3 部署免费 Cloudflare Worker 反向代理（完整支持 Realtime WebSocket）

1. 在 Cloudflare 左侧菜单点击 **Workers & Pages（计算 / Workers）** → **Create（创建）** → **Create Worker**。
2. 名字填 `termflow-supabase-proxy`，点击 **Deploy（部署）**，随后点击右上角 **Edit code（编辑代码）**。
3. 清空默认代码，粘贴以下完整代理脚本（**请将第 4 行的 `你的项目ID.supabase.co` 替换为你自己的 Supabase 域名**）：

```javascript
// TermFlow Supabase 专属域名反向代理脚本（完整支持 Auth + PostgREST + Realtime WebSocket）
const SUPABASE_HOST = '你的项目ID.supabase.co'; // <-- 替换为你的项目地址，不要带 https://

export default {
  async fetch(request) {
    const url = new URL(request.url);
    url.hostname = SUPABASE_HOST;
    url.protocol = 'https:';

    // 处理浏览器预检请求 (CORS)
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': request.headers.get('Access-Control-Request-Headers') || '*',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    const headers = new Headers(request.headers);
    headers.set('Host', SUPABASE_HOST);

    // 原生透传 WebSocket 握手（保障 TermFlow 多端秒级 Realtime 实时同步）
    const upgradeHeader = request.headers.get('Upgrade');
    if (upgradeHeader && upgradeHeader.toLowerCase() === 'websocket') {
      return fetch(url.toString(), {
        method: request.method,
        headers,
      });
    }

    const proxyReq = new Request(url.toString(), {
      method: request.method,
      headers,
      body: ['GET', 'HEAD'].includes(request.method) ? null : request.body,
      redirect: 'follow',
    });

    const response = await fetch(proxyReq);
    const resHeaders = new Headers(response.headers);
    resHeaders.set('Access-Control-Allow-Origin', '*');
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: resHeaders,
    });
  },
};
```

4. 点击右上角 **Deploy（部署）** 保存。

---

### 2.4 绑定你的专属子域名并填入 TermFlow
1. 回到该 Worker 的详情页，点击顶部 **Settings（设置）** → **Domains & Routes（域和路由）** → 点击 **Add（添加）** → 选择 **Custom Domain（自定义域）**。
2. 输入你想使用的子域名，例如：`sync.你的域名.me`（Cloudflare 会自动为你签发免费 HTTPS SSL 证书并配置解析，无需手动填 IP！）。
3. 等待约 1 分钟证书状态变为 **Active（有效）** 后，打开手机和电脑上的 **TermFlow → 设置页 → 配置 Supabase 服务**：
   - 将 `SUPABASE_URL` 改为你的专属域名：`https://sync.你的域名.me`
   - `SUPABASE_ANON_KEY` 保持不变
   - 点击 **「保存并连接」**，即可享受基于专属域名的丝滑多端同步！

---

## 第三部分：常见问题排查（FAQ）

| 现象或报错信息 | 原因说明 | 解决办法 |
| :--- | :--- | :--- |
| `permission denied for table semesters (42501)` | 数据库表未对 `authenticated` 角色开放读写权限 | 在 Supabase SQL Editor 执行本文 **1.2 节** 的 `GRANT` 授权语句 |
| `relation "public.semesters" does not exist` | 尚未执行建表脚本 | 在 Supabase SQL Editor 粘贴运行 [`supabase/schema.sql`](../supabase/schema.sql) |
| 注册后提示 `Email not confirmed` | Supabase 默认开启了邮箱验证 | 去邮箱点击确认链接，或在 **Authentication → Providers → Email** 关闭 `Confirm email` |
| 新设备登录后历史数据不全 | 本地同步游标异常 | 在 TermFlow 设置页最下方点击 **「重置同步游标并全量拉取」** |
| 离线使用了一周后再注册登录，旧数据会丢吗？ | 不会丢失 | 首次登录时 TermFlow 会自动将本地未绑定账号的记录认领至当前账号并推送到云端 |
