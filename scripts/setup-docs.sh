#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"
SWAGGER_DIR="$DOCS_DIR/swagger-ui"
SPECS_DIR="$DOCS_DIR/specs"
SWAGGER_VERSION="5.18.2"

echo "=== 设置 Swagger API 文档 ==="

# 创建目录
mkdir -p "$SWAGGER_DIR" "$SPECS_DIR"

# 下载 Swagger UI 静态文件
echo "下载 Swagger UI v${SWAGGER_VERSION}..."
curl -sL "https://unpkg.com/swagger-ui-dist@${SWAGGER_VERSION}/swagger-ui-bundle.js" -o "$SWAGGER_DIR/swagger-ui-bundle.js"
curl -sL "https://unpkg.com/swagger-ui-dist@${SWAGGER_VERSION}/swagger-ui-standalone-preset.js" -o "$SWAGGER_DIR/swagger-ui-standalone-preset.js"
curl -sL "https://unpkg.com/swagger-ui-dist@${SWAGGER_VERSION}/swagger-ui.css" -o "$SWAGGER_DIR/swagger-ui.css"

echo "Swagger UI 下载完成"

# 检查 index.html 是否存在
if [ ! -f "$SWAGGER_DIR/index.html" ]; then
    echo "警告: $SWAGGER_DIR/index.html 不存在，请确保已创建自定义 index.html"
fi

# 检查 spec 文件
for spec in matrix-client-server.yaml bridge-provisioning.yaml conduwuit-admin.yaml; do
    if [ -f "$SPECS_DIR/$spec" ]; then
        echo "✓ $spec"
    else
        echo "⚠ $SPECS_DIR/$spec 不存在"
    fi
done

echo ""
echo "=== 设置完成 ==="
echo "请确保 Nginx 配置已更新，然后重启 Nginx:"
echo "  sudo nginx -s reload"
echo ""
echo "访问 API 文档: http://localhost:8008/docs/"
