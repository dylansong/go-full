#!/usr/bin/env bash
set -euo pipefail

########################################
# 参数解析
########################################

APP_NAME="fullstack-app"
GO_MODULE="github.com/yourname/fullstack-app"

WITH_REACT=1
WITH_VUE=0
WITH_MOBILE=0

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -n, --name <app-name>        项目目录名（默认：fullstack-app）
  -m, --module <go-module>     Go module 路径（默认：github.com/yourname/fullstack-app）

  前端选项（可组合使用）：
      --with-react             生成 React + Vite + TS 项目 (apps/web-react)（默认开启）
      --with-vue               生成 Vue + Vite + TS 项目 (apps/web-vue)
      --no-react               不生成 React 项目
      --with-mobile            生成 Capacitor mobile 壳 (apps/mobile)

      --api-only               只生成 Go API（等同于 --no-react --no-vue --no-mobile）

  -h, --help                   显示本帮助

示例：
  只要 api + React（默认）：
    $0 -n my-app -m github.com/dylansong/my-app

  只要 api + Vue（不要 React）：
    $0 -n my-app -m github.com/dylansong/my-app --no-react --with-vue

  api + React + Vue：
    $0 -n my-app -m github.com/dylansong/my-app --with-vue

  api + React + Vue + mobile：
    $0 --name my-app --module github.com/dylansong/my-app --with-vue --with-mobile

  只要 api：
    $0 --name my-api-only --module github.com/dylansong/my-api-only --api-only
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      APP_NAME="$2"
      shift 2
      ;;
    -m|--module)
      GO_MODULE="$2"
      shift 2
      ;;
    --with-react)
      WITH_REACT=1
      shift
      ;;
    --no-react)
      WITH_REACT=0
      shift
      ;;
    --with-vue)
      WITH_VUE=1
      shift
      ;;
    --no-vue)
      WITH_VUE=0
      shift
      ;;
    --with-mobile)
      WITH_MOBILE=1
      shift
      ;;
    --no-mobile)
      WITH_MOBILE=0
      shift
      ;;
    --api-only)
      WITH_REACT=0
      WITH_VUE=0
      WITH_MOBILE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

########################################
# 简单环境检查
########################################
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' not found, please install it first."
    exit 1
  fi
}

need_cmd git
need_cmd go
need_cmd pnpm

########################################
# 创建项目目录
########################################
echo "Creating project: $APP_NAME"
mkdir -p "$APP_NAME"
cd "$APP_NAME"

echo "Initializing git repo..."
git init >/dev/null

########################################
# 根 package.json（pnpm workspace + turbo）
########################################
cat > package.json <<EOF
{
  "name": "$APP_NAME",
  "private": true,
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "lint": "turbo lint",
    "gen:api:ts": "openapi-typescript api/spec/openapi.yaml -o packages/api-client/src/openapi-types.ts"
  },
  "devDependencies": {
    "openapi-typescript": "^6.7.0",
    "turbo": "^2"
  },
  "packageManager": "pnpm@9.15.0"
}
EOF

# pnpm-workspace.yaml
cat > pnpm-workspace.yaml <<'EOF'
packages:
  - "apps/*"
  - "packages/*"
EOF

# turbo.json
cat > turbo.json <<'EOF'
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"]
    }
  }
}
EOF

mkdir -p apps packages/api-client/src
mkdir -p api/{cmd/server,internal/{config,http,openapi,service,repo},db/{schema,query,generated},spec}

########################################
# 1. 初始化 Go API 模块 + air + sqlc + Dockerfile
########################################
echo "Initializing Go module in api/..."
cd api
go mod init "$GO_MODULE/api" >/dev/null

# go 依赖
go get github.com/go-chi/chi/v5 >/dev/null

# .air.toml
cat > .air.toml <<'EOF'
root = "."
tmp_dir = "tmp"

[build]
cmd = "go build -o ./tmp/app ./cmd/server"
bin = "tmp/app"
full_bin = "./tmp/app"
include_ext = ["go"]
exclude_dir = ["tmp", "vendor"]
delay = 1000

[log]
time = true

[serve]
cmd = "./tmp/app"
EOF

# sqlc.yaml
cat > sqlc.yaml <<'EOF'
version: "2"
sql:
  - schema: "db/schema"
    queries: "db/query"
    engine: "postgresql"
    gen:
      go:
        package: "db"
        out: "db/generated"
        sql_package: "pgx/v5"
        emit_json_tags: true
        emit_prepared_queries: true
        emit_interface: false
        emit_exact_table_names: false
EOF

# 示例 schema
cat > db/schema/001_users.sql <<'EOF'
CREATE TABLE IF NOT EXISTS users (
    id          BIGSERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
EOF

# 示例 query
cat > db/query/users.sql <<'EOF'
-- name: CreateUser :one
INSERT INTO users (email, name)
VALUES ($1, $2)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users
WHERE id = $1;

-- name: ListUsers :many
SELECT * FROM users
ORDER BY id DESC
LIMIT $1 OFFSET $2;
EOF

# OpenAPI
cat > spec/openapi.yaml <<'EOF'
openapi: 3.0.3
info:
  title: Fullstack API
  version: 0.1.0
paths:
  /health:
    get:
      operationId: healthCheck
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: object
                properties:
                  status:
                    type: string
                    enum: [ok]
  /users:
    get:
      operationId: listUsers
      parameters:
        - in: query
          name: limit
          schema:
            type: integer
            default: 20
      responses:
        '200':
          description: list users
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserListResponse'
components:
  schemas:
    User:
      type: object
      required: [id, email, name]
      properties:
        id:
          type: integer
        email:
          type: string
          format: email
        name:
          type: string
    UserListResponse:
      type: object
      required: [items]
      properties:
        items:
          type: array
          items:
            $ref: '#/components/schemas/User'
EOF

# oapi-codegen 配置
cat > spec/oapi-codegen.yaml <<'EOF'
package: openapi
output: internal/openapi/openapi.gen.go
generate:
  - chi-server
  - types
EOF

# Dockerfile
cat > Dockerfile <<'EOF'
# Build stage
FROM golang:1.23 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o server ./cmd/server

# Runtime stage
FROM gcr.io/distroless/base-debian12

WORKDIR /app
COPY --from=builder /app/server /app/server

ENV PORT=8080
EXPOSE 8080

CMD ["/app/server"]
EOF

# config.go + main.go（引用 GO_MODULE）
cat > internal/config/config.go <<EOF
package config

import "os"

type Config struct {
	Port        string
	DatabaseURL string
}

func Load() Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	return Config{
		Port:        port,
		DatabaseURL: os.Getenv("DATABASE_URL"),
	}
}
EOF

cat > cmd/server/main.go <<EOF
package main

import (
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"

	cfgpkg "$GO_MODULE/api/internal/config"
	openapi "$GO_MODULE/api/internal/openapi"
)

type Server struct{}

func (s *Server) HealthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(\`{"status":"ok"}\`))
}

func (s *Server) ListUsers(w http.ResponseWriter, r *http.Request, params openapi.ListUsersParams) {
	// TODO: 接入 sqlc + service，这里只做 demo
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(\`{"items":[]}\`))
}

func main() {
	cfg := cfgpkg.Load()

	r := chi.NewRouter()
	s := &Server{}
	openapi.RegisterHandlers(r, s)

	log.Printf("Listening on :%s", cfg.Port)
	log.Fatal(http.ListenAndServe(":"+cfg.Port, r))
}
EOF

cd ..

########################################
# 2. shared TS api-client 包
########################################
cat > packages/api-client/package.json <<'EOF'
{
  "name": "@fullstack/api-client",
  "version": "0.0.1",
  "private": true,
  "main": "src/client.ts",
  "types": "src/client.ts"
}
EOF

cat > packages/api-client/src/client.ts <<'EOF'
import type { paths } from "./openapi-types"

export interface ApiClientOptions {
  baseUrl: string
}

export class ApiClient {
  constructor(private opts: ApiClientOptions) {}

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    const res = await fetch(`${this.opts.baseUrl}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...(init?.headers || {})
      }
    })
    if (!res.ok) {
      throw new Error(`API error ${res.status}`)
    }
    return res.json() as Promise<T>
  }

  async getHealth() {
    type HealthResp =
      paths["/health"]["get"]["responses"]["200"]["content"]["application/json"]
    return this.request<HealthResp>("/health")
  }

  async listUsers(limit?: number) {
    type Resp =
      paths["/users"]["get"]["responses"]["200"]["content"]["application/json"]

    const query = limit ? \`?limit=\${limit}\` : ""
    return this.request<Resp>(\`/users\${query}\`)
  }
}
EOF

########################################
# 3. apps: React / Vue / mobile（按开关生成）
########################################
cd apps

if [[ "$WITH_REACT" -eq 1 ]]; then
  echo "Bootstrapping React app (apps/web-react)..."
  pnpm create vite@latest web-react --template react-ts >/dev/null
fi

if [[ "$WITH_VUE" -eq 1 ]]; then
  echo "Bootstrapping Vue app (apps/web-vue)..."
  pnpm create vite@latest web-vue --template vue-ts >/dev/null
fi

if [[ "$WITH_MOBILE" -eq 1 ]]; then
  echo "Bootstrapping Capacitor shell (apps/mobile)..."
  mkdir -p mobile
  cd mobile
  pnpm init >/dev/null
  pnpm add @capacitor/core @capacitor/cli >/dev/null

  cat > capacitor.config.ts <<'EOF'
import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.example.fullstack',
  appName: 'FullstackApp',
  webDir: '../web-react/dist',
  bundledWebRuntime: false
}

export default config
EOF

  cd ..
fi

cd ..

########################################
# 4. 顶层 Makefile（根据是否存在目录做容错）
########################################
cat > Makefile <<'EOF'
PROJECT_NAME ?= fullstack-app

API_DIR := api
REACT_APP_DIR := apps/web-react
VUE_APP_DIR := apps/web-vue
MOBILE_DIR := apps/mobile
API_CLIENT_PKG := packages/api-client

.PHONY: help
help:
	@echo "Available commands:"
	@echo ""
	@echo "  Turbo (monorepo):"
	@echo "  make dev             - 启动所有前端开发服务器 (turbo dev)"
	@echo "  make build           - 构建所有前端项目 (turbo build)"
	@echo ""
	@echo "  Code Generation:"
	@echo "  make gen-api         - 从 OpenAPI 生成 Go + TS 类型"
	@echo "  make gen-api-go      - 从 OpenAPI 生成 Go chi server 接口和类型"
	@echo "  make gen-api-ts      - 从 OpenAPI 生成 shared TS 类型"
	@echo "  make sqlc            - 运行 sqlc generate"
	@echo ""
	@echo "  Development:"
	@echo "  make dev-api         - 启动 Go API 服务 (air 优先)"
	@echo "  make dev-react       - 启动 React 前端 (如果存在)"
	@echo "  make dev-vue         - 启动 Vue 前端 (如果存在)"
	@echo ""
	@echo "  Build:"
	@echo "  make build-react     - 构建 React 前端 (如果存在)"
	@echo "  make build-vue       - 构建 Vue 前端 (如果存在)"
	@echo ""
	@echo "  Mobile:"
	@echo "  make mobile-sync     - 将 React build 结果拷贝到 Capacitor (如果存在)"
	@echo ""
	@echo "  Docker:"
	@echo "  make api-build       - 构建 API Docker 镜像"
	@echo "  make api-run-local   - 本地用 Docker 运行 API"

# Turbo commands
.PHONY: dev
dev:
	pnpm dev

.PHONY: build
build:
	pnpm build

# OpenAPI
.PHONY: gen-api-go
gen-api-go:
	cd $(API_DIR) && oapi-codegen -config spec/oapi-codegen.yaml spec/openapi.yaml

.PHONY: gen-api-ts
gen-api-ts:
	pnpm run gen:api:ts

.PHONY: gen-api
gen-api: gen-api-go gen-api-ts
	@echo "✅ OpenAPI Go + TS 已生成"

# sqlc
.PHONY: sqlc
sqlc:
	cd $(API_DIR) && sqlc generate

# API dev：优先用 air，没有 air 就用 go run
.PHONY: dev-api
dev-api:
	cd $(API_DIR) && (command -v air >/dev/null 2>&1 && air || go run ./cmd/server)

# 前端 dev
.PHONY: dev-react
dev-react:
	@if [ -d "$(REACT_APP_DIR)" ]; then \
	  cd $(REACT_APP_DIR) && pnpm install && pnpm run dev --host; \
	else \
	  echo "React app not found at $(REACT_APP_DIR)"; \
	fi

.PHONY: dev-vue
dev-vue:
	@if [ -d "$(VUE_APP_DIR)" ]; then \
	  cd $(VUE_APP_DIR) && pnpm install && pnpm run dev --host; \
	else \
	  echo "Vue app not found at $(VUE_APP_DIR)"; \
	fi

# 构建
.PHONY: build-react
build-react:
	@if [ -d "$(REACT_APP_DIR)" ]; then \
	  cd $(REACT_APP_DIR) && pnpm install && pnpm run build; \
	else \
	  echo "React app not found at $(REACT_APP_DIR)"; \
	fi

.PHONY: build-vue
build-vue:
	@if [ -d "$(VUE_APP_DIR)" ]; then \
	  cd $(VUE_APP_DIR) && pnpm install && pnpm run build; \
	else \
	  echo "Vue app not found at $(VUE_APP_DIR)"; \
	fi

# Mobile + Capacitor
.PHONY: mobile-sync
mobile-sync: build-react
	@if [ -d "$(MOBILE_DIR)" ]; then \
	  cd $(MOBILE_DIR) && npx cap copy; \
	else \
	  echo "Mobile app not found at $(MOBILE_DIR)"; \
	fi

.PHONY: mobile-open-ios
mobile-open-ios:
	@if [ -d "$(MOBILE_DIR)" ]; then \
	  cd $(MOBILE_DIR) && npx cap open ios; \
	else \
	  echo "Mobile app not found at $(MOBILE_DIR)"; \
	fi

.PHONY: mobile-open-android
mobile-open-android:
	@if [ -d "$(MOBILE_DIR)" ]; then \
	  cd $(MOBILE_DIR) && npx cap open android; \
	else \
	  echo "Mobile app not found at $(MOBILE_DIR)"; \
	fi

# Docker 构建与本地运行
.PHONY: api-build
api-build:
	cd $(API_DIR) && docker build -t $(PROJECT_NAME)-api:latest .

.PHONY: api-run-local
api-run-local:
	docker run --rm -p 8080:8080 --env PORT=8080 $(PROJECT_NAME)-api:latest
EOF

########################################
# 打印下一步提示
########################################
echo
echo "✅ Project $APP_NAME created."
echo
echo "下一步（工具需要手动安装一次）："
echo "  Go 工具："
echo "    go install github.com/cosmtrek/air@latest"
echo "    go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest"
echo "    go install github.com/deepmap/oapi-codegen/cmd/oapi-codegen@latest"
echo
echo "  Node 依赖（根目录）："
echo "    pnpm install"
echo
echo "  生成 OpenAPI 与 TS 类型："
echo "    make gen-api"
echo
echo "  生成 sqlc 代码："
echo "    make sqlc"
echo
echo "  开发时："
echo "    make dev-api"
if [[ "$WITH_REACT" -eq 1 ]]; then
  echo "    make dev-react"
fi
if [[ "$WITH_VUE" -eq 1 ]]; then
  echo "    make dev-vue"
fi
echo
echo "  Docker 本地测试："
echo "    make api-build"
echo "    make api-run-local"
