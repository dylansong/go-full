
````md
# Fullstack Init Script

一键初始化一个包含 **Go API + 多前端（React/Vue）+ Capacitor + Shared TS Client** 的全栈 Monorepo 脚手架。

适用场景：

- Go + PostgreSQL + sqlc 的 API 服务
- React / Vue 前端（Vite + TypeScript）
- 通过 Capacitor 打包为移动端 App
- 用 OpenAPI 作为 API 规范，自动生成前后端类型 & TS 客户端
- 使用 **Turborepo** 管理 monorepo，支持并行构建和缓存

---

## Features / 特性概览

运行脚本后，会生成一个结构大致如下的项目：

```bash
my-app/
├─ api/                       # Go API
│  ├─ cmd/server/             # main.go
│  ├─ internal/
│  │  ├─ config/              # 配置加载
│  │  ├─ http/                # (预留) 业务 handler / router
│  │  ├─ openapi/             # oapi-codegen 生成的代码
│  │  ├─ service/             # (预留) 业务逻辑
│  │  └─ repo/                # (预留) 调用 sqlc 的仓库层
│  ├─ db/
│  │  ├─ schema/              # SQL schema 示例 (users 表)
│  │  ├─ query/               # sqlc query 示例
│  │  ├─ generated/           # sqlc 生成代码
│  │  └─ migrations/          # Atlas 生成的迁移文件
│  ├─ spec/
│  │  ├─ openapi.yaml         # OpenAPI 规范 (含 /health, /users 示例)
│  │  └─ oapi-codegen.yaml    # oapi-codegen 配置
│  ├─ .air.toml               # air 热重载配置
│  ├─ sqlc.yaml               # sqlc 配置
│  ├─ atlas.hcl               # Atlas 数据库迁移配置
│  ├─ .env.example            # 环境变量模板
│  └─ Dockerfile              # 多阶段构建镜像，可直接给 Dokku / K8s 用
│
├─ apps/
│  ├─ web-react/              # (可选) React + Vite + TS
│  ├─ web-vue/                # (可选) Vue + Vite + TS
│  └─ mobile/                 # (可选) Capacitor 壳，打包 web-react 的 dist
│
├─ packages/
│  └─ api-client/
│     ├─ src/
│     │  ├─ openapi-types.ts  # openapi-typescript 自动生成 (TS 类型)
│     │  └─ client.ts         # 封装 ApiClient，可在 React/Vue 复用
│     └─ package.json
│
├─ package.json               # 根配置 (turbo + openapi-typescript)
├─ pnpm-workspace.yaml        # pnpm workspace 配置
├─ turbo.json                 # Turborepo 配置
├─ Makefile                   # 常用 dev/build/gen 命令
└─ README.md
````

> 前端项目（React/Vue）和 mobile 是否生成，可以通过脚本参数控制。

---

## Requirements / 环境要求

本脚手架只假设你已经安装了这些基础工具：

**必需：**

* `git`
* `go`
* `node` + `pnpm`

**推荐（脚手架会用到，但你也可以后面自己安装）：**

* `air`（Go 热重载）
* `sqlc`（从 SQL 生成 Go 代码）
* `oapi-codegen`（从 OpenAPI 生成 Go 接口 & 类型）
* `atlas`（数据库迁移工具）
* `docker`（如果你要本地跑 Docker / 部署到 Dokku）
* `npx`（用于运行 Capacitor CLI 等工具）

---

## Usage / 使用方式

### 1. 在线一键初始化（推荐）

将本仓库设置为 **public** 后，可以直接通过 `curl` 执行脚本：

```bash
# 语法格式
curl -fsSL <脚本URL> | bash -s -- [参数...]
```

> **说明**：`bash -s` 从标准输入读取脚本，`--` 之后的内容作为脚本参数传递。

```bash
# 示例：生成 api + React（默认）
curl -fsSL https://raw.githubusercontent.com/dylansong/go-full/main/init.sh \
  | bash -s -- -n my-app -m github.com/yourname/my-app

# 示例：只要 Vue，不要 React
curl -fsSL https://raw.githubusercontent.com/dylansong/go-full/main/init.sh \
  | bash -s -- -n my-app -m github.com/yourname/my-app --no-react --with-vue

# 示例：React + Vue + Mobile 全要
curl -fsSL https://raw.githubusercontent.com/dylansong/go-full/main/init.sh \
  | bash -s -- -n my-app -m github.com/yourname/my-app --with-vue --with-mobile

# 示例：只要 API
curl -fsSL https://raw.githubusercontent.com/dylansong/go-full/main/init.sh \
  | bash -s -- -n my-app -m github.com/yourname/my-app --api-only
```

### 2. 先下载脚本再执行（更安全，可先打开看脚本内容）

```bash
curl -fsSL https://raw.githubusercontent.com/dylansong/go-full/main/init.sh -o init.sh
chmod +x init.sh

# 示例：生成 api + React + Vue + mobile
./init.sh \
  --name my-app \
  --module github.com/yourname/my-app \
  --with-vue \
  --with-mobile
```

---

## Script Options / 参数说明

脚本支持通过参数控制生成的内容：

```text
-n, --name <app-name>        项目目录名（默认：fullstack-app）
-m, --module <go-module>     Go module 路径（默认：github.com/yourname/fullstack-app）

前端选项（可组合使用）：
    --with-react             生成 React + Vite + TS 项目 (apps/web-react)（默认开启）
    --with-vue               生成 Vue + Vite + TS 项目 (apps/web-vue)
    --no-react               不生成 React 项目
    --no-vue                 不生成 Vue 项目
    --with-mobile            生成 Capacitor mobile 壳 (apps/mobile)
    --no-mobile              不生成 mobile 项目

    --api-only               只生成 Go API（等同于 --no-react --no-vue --no-mobile）

-h, --help                   显示帮助
```

### 常见用法示例

**1）默认：API + React**

```bash
./init.sh -n my-app -m github.com/yourname/my-app
```

**2）只要 API + Vue（不要 React）**

```bash
./init.sh -n my-app -m github.com/yourname/my-app --no-react --with-vue
```

**3）API + React + Vue**

```bash
./init.sh -n my-app -m github.com/yourname/my-app --with-vue
```

**4）API + React + Vue + Mobile（Capacitor）**

```bash
./init.sh \
  --name my-app \
  --module github.com/yourname/my-app \
  --with-vue \
  --with-mobile
```

**5）只要 API（不生成前端项目）**

```bash
./init.sh --name my-api-only --module github.com/yourname/my-api-only --api-only
```

---

## After Init / 初始化完成后常用命令

在脚手架生成完毕后：

```bash
cd my-app
```

### 1. 安装依赖

根目录安装 dev 依赖（openapi-typescript）：

```bash
pnpm install
```

Go 侧推荐安装工具（只需安装一次，本地全局可用）：

```bash
go install github.com/air-verse/air@latest
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
go install github.com/deepmap/oapi-codegen/cmd/oapi-codegen@latest
```

Atlas 数据库迁移工具：

```bash
# macOS
brew install ariga/tap/atlas

# 或通用方式
curl -sSf https://atlasgo.sh | sh
```

### 1.5 配置环境变量

```bash
# 从模板创建 .env 文件
make setup-env

# 编辑 api/.env 设置数据库连接
vim api/.env
```

`.env` 文件示例：

```bash
PORT=8080
DATABASE_URL=postgres://postgres:password@localhost:5432/mydb?sslmode=disable
```

### 2. 使用 Makefile

本脚手架已经生成了一份通用 `Makefile`，包含常用命令：

```bash
# 查看所有命令
make help
```

核心命令：

```bash
# Turbo (monorepo) - 并行启动/构建所有前端
make dev            # 启动所有前端开发服务器 (turbo dev)
make build          # 构建所有前端项目 (turbo build)

# 从 OpenAPI 生成 Go 类型 + chi server 接口 + TS 类型
make gen-api        # 等价于 gen-api-go + gen-api-ts

# 只生成 Go 端（oapi-codegen）
make gen-api-go

# 只生成 TS 端类型（openapi-typescript -> packages/api-client）
make gen-api-ts

# 从 db/schema + db/query 生成 sqlc 代码
make sqlc

# 数据库迁移 (Atlas)
make db-diff          # 生成迁移文件
make db-apply         # 应用迁移到数据库
make db-status        # 查看迁移状态

# 启动 API（优先用 air，没有 air 则 go run）
make dev-api

# 启动 React 前端 (apps/web-react)
make dev-react

# 启动 Vue 前端 (apps/web-vue) —— 前提是你启用了 --with-vue
make dev-vue

# 构建 React 前端（产物放在 apps/web-react/dist）
make build-react

# 构建 Vue 前端
make build-vue

# 如果生成了 mobile：同步 React 构建结果到 Capacitor
make mobile-sync

# 构建 API 的 Docker 镜像
make api-build

# 使用 Docker 在本地跑 API（端口 8080）
make api-run-local
```

---

## Database Management / 数据库管理

本项目使用 **Atlas** 进行数据库迁移管理，采用声明式（Declarative）方式。

### 架构概览

```
db/schema/*.sql (你编辑这里 - 唯一的结构定义源)
       │
       ▼
   atlas migrate diff ──────► db/migrations/ (自动生成)
       │                            │
       ▼                            ▼
     sqlc generate              atlas migrate apply
       │                            │
       ▼                            ▼
  db/generated/*.go              数据库
  (Go 类型和查询)              (实际表结构)
```

### 目录职责

| 目录 | 作用 | 谁写 |
|------|------|------|
| `db/schema/` | 定义表结构（DDL） | **你手动编写** |
| `db/query/` | 定义 SQL 查询 | **你手动编写** |
| `db/migrations/` | 版本化迁移文件 | Atlas 自动生成 |
| `db/generated/` | Go 代码 | sqlc 自动生成 |

> **重要**：`db/schema/*.sql` 是数据库结构的 **唯一定义源（Single Source of Truth）**。你只需声明"最终要什么结构"，Atlas 自动计算"如何从当前状态到达目标状态"。

### 典型工作流程

#### 1. 新建表

```bash
# 创建新的 schema 文件
cat > api/db/schema/002_posts.sql << 'EOF'
CREATE TABLE IF NOT EXISTS posts (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    title       TEXT NOT NULL,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
EOF
```

#### 2. 生成迁移文件

```bash
make db-diff
# 提示输入迁移名称，例如：add_posts_table
```

Atlas 会自动：
- 对比 `db/schema/` 与当前数据库结构
- 生成迁移文件到 `db/migrations/`

#### 3. 应用迁移

```bash
make db-apply
```

#### 4. 重新生成 Go 代码

```bash
make sqlc
```

### 常用命令

```bash
# 生成迁移文件（比较 schema 与数据库差异）
make db-diff

# 应用待执行的迁移
make db-apply

# 查看迁移状态
make db-status

# 更新迁移文件哈希（修改迁移文件后执行）
make db-hash

# 验证迁移文件
make db-validate
```

### 添加新的查询

在 `db/query/` 目录下添加 SQL 查询：

```sql
-- db/query/posts.sql

-- name: CreatePost :one
INSERT INTO posts (user_id, title, content)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetPostByID :one
SELECT * FROM posts
WHERE id = $1;

-- name: ListPostsByUser :many
SELECT * FROM posts
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;
```

然后运行：

```bash
make sqlc
```

sqlc 会在 `db/generated/` 目录生成类型安全的 Go 代码。

---

## How Type Sharing Works / 前后端类型如何共享？

* `api/spec/openapi.yaml`
  是 **API 规范的单一来源（Single Source of Truth）**。
* Go 端通过 `oapi-codegen` 生成：

  * chi server 接口
  * 请求/响应 DTO 类型
* 前端（React/Vue）通过 `openapi-typescript` 生成：

  * `packages/api-client/src/openapi-types.ts`（TS 类型）
  * 再配合 `client.ts` 中的 `ApiClient` 封装，React/Vue 只需要：

```ts
import { ApiClient } from "@fullstack/api-client"

const client = new ApiClient({ baseUrl: import.meta.env.VITE_API_BASE_URL })
const data = await client.getHealth()
```

这样：

* 所有前端项目（React、Vue、未来的其他前端）都可以共用 **同一份 TS 客户端**
* API 一旦在 OpenAPI 中变更，执行 `make gen-api` 即可前后端类型同步

---

## Notes / 注意事项

* 本脚手架生成的是一个「基础骨架」，很多地方（如 service/repo 的具体实现、数据库连接、鉴权等）需要你根据业务自行扩展。
* `openapi.yaml` 里自带了 `/health` 和 `/users` 示例接口，方便你验证整条链路（Go + TS client）的行为。
* `apps/mobile` 默认使用 `apps/web-react/dist` 作为 Capacitor 的前端资源目录，如果你希望改成使用 Vue，只需修改 `capacitor.config.ts` 中的 `webDir` 即可。

---

## License

建议放一个开源协议，例如：

* MIT
* 或 Apache 2.0

```text
MIT License
...
```

---

## TODO / 未来可能扩展

* [x] 支持可选生成 Atlas 数据库迁移配置
* [x] 支持选择是否开启 Vue / React（通过 `--with-react`/`--no-react`/`--with-vue`/`--no-vue` 参数）
* [x] 支持环境变量配置（.env.example + Makefile 自动加载）
* [ ] 支持一键生成 Dokku 部署脚本 / GitHub Actions CI 模板

