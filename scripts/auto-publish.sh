#!/bin/bash

# 技术博客自动发布脚本
# 包含文章生成、Git提交、推送和网页验证

set -e

# 配置
PROJECT_ROOT="/Users/chaneychan/CodeProjects/buuuuuuug.github.io"
GITHUB_REPO="buuuuuuug/buuuuuuug.github.io"
BLOG_URL="https://buuuuuuug.github.io"
MAX_RETRIES=3
RETRY_DELAY=30

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖项..."
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js 未安装"
        exit 1
    fi
    
    # 检查Git
    if ! command -v git &> /dev/null; then
        log_error "Git 未安装"
        exit 1
    fi
    
    # 检查GitHub CLI
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI 未安装，将使用git命令"
    fi
    
    # 检查curl
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装"
        exit 1
    fi
    
    log_success "依赖项检查通过"
}

# 验证项目结构
validate_project() {
    log_info "验证项目结构..."
    
    if [ ! -d "$PROJECT_ROOT" ]; then
        log_error "项目目录不存在: $PROJECT_ROOT"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    
    # 验证关键目录
    local required_dirs=(
        "src/content/blog"
        "scripts"
        ".github/workflows"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "缺少必要目录: $dir"
            exit 1
        fi
    done
    
    # 验证关键文件
    if [ ! -f "scripts/blog-generator.js" ]; then
        log_error "缺少博客生成脚本"
        exit 1
    fi
    
    log_success "项目结构验证通过"
}

# 生成文章
generate_articles() {
    log_info "开始生成技术博客文章..."
    
    cd "$PROJECT_ROOT"
    
    # 生成多篇文章
    local articles_count=3
    log_info "计划生成 $articles_count 篇文章"
    
    # 生成不同主题的文章
    local topics=("java" "rust" "ai")
    local types=("tutorial" "practice" "comparison")
    
    for i in $(seq 0 $((articles_count - 1))); do
        local topic=${topics[$i]}
        local type=${types[$i]}
        local featured=$([ $i -eq 0 ] && echo "--featured" || echo "")
        
        log_info "生成文章: $topic - $type"
        
        if node scripts/blog-generator.js generate "$topic" "$type" $featured; then
            log_success "文章生成成功: $topic - $type"
        else
            log_error "文章生成失败: $topic - $type"
            return 1
        fi
    done
    
    log_success "所有文章生成完成"
}

# 检查Git状态
check_git_status() {
    log_info "检查Git状态..."
    
    cd "$PROJECT_ROOT"
    
    # 检查是否有未提交的更改
    if [ -n "$(git status --porcelain)" ]; then
        log_info "发现未提交的更改"
        
        # 显示更改的文件
        git status --porcelain | while read -r line; do
            log_info "更改: $line"
        done
        
        return 0
    else
        log_warning "没有新的更改需要提交"
        return 1
    fi
}

# 提交更改
commit_changes() {
    log_info "提交更改到Git..."
    
    cd "$PROJECT_ROOT"
    
    # 添加所有更改
    git add .
    
    # 生成提交信息
    local commit_msg="🤖 自动更新: 添加技术博客文章 $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 提交更改
    if git commit -m "$commit_msg"; then
        log_success "Git提交成功"
        return 0
    else
        log_error "Git提交失败"
        return 1
    fi
}

# 推送到GitHub
push_to_github() {
    log_info "推送到GitHub..."
    
    cd "$PROJECT_ROOT"
    
    # 获取当前分支
    local branch=$(git rev-parse --abbrev-ref HEAD)
    log_info "当前分支: $branch"
    
    # 推送更改
    if git push origin "$branch"; then
        log_success "推送到GitHub成功"
        return 0
    else
        log_error "推送到GitHub失败"
        return 1
    fi
}

# 检查GitHub Actions状态
check_github_actions() {
    log_info "检查GitHub Actions状态..."
    
    # 使用GitHub CLI检查最近的workflow运行状态
    if command -v gh &> /dev/null; then
        log_info "使用GitHub CLI检查workflow状态..."
        
        # 等待几秒钟让workflow启动
        sleep 10
        
        # 获取最近的workflow运行
        local latest_run=$(gh run list --repo="$GITHUB_REPO" --limit=1 --json databaseId,status,conclusion | jq -r '.[0]')
        
        if [ -n "$latest_run" ] && [ "$latest_run" != "null" ]; then
            local run_id=$(echo "$latest_run" | jq -r '.databaseId')
            local status=$(echo "$latest_run" | jq -r '.status')
            local conclusion=$(echo "$latest_run" | jq -r '.conclusion')
            
            log_info "最新workflow运行状态:"
            log_info "  ID: $run_id"
            log_info "  状态: $status"
            log_info "  结论: $conclusion"
            
            if [ "$status" = "completed" ] && [ "$conclusion" = "success" ]; then
                log_success "GitHub Actions运行成功"
                return 0
            elif [ "$status" = "completed" ] && [ "$conclusion" = "failure" ]; then
                log_error "GitHub Actions运行失败"
                return 1
            else
                log_info "GitHub Actions仍在运行中，等待完成..."
                return 2
            fi
        else
            log_warning "无法获取GitHub Actions状态"
            return 2
        fi
    else
        log_warning "GitHub CLI不可用，跳过workflow状态检查"
        return 2
    fi
}

# 验证网页访问
verify_website() {
    log_info "验证网页访问..."
    
    local retry_count=0
    local max_retries=$MAX_RETRIES
    
    while [ $retry_count -lt $max_retries ]; do
        log_info "尝试访问网页 (尝试 $((retry_count + 1))/$max_retries)..."
        
        # 使用curl检查网页状态
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$BLOG_URL")
        
        if [ "$response_code" = "200" ]; then
            log_success "网页访问正常 (HTTP 200)"
            
            # 获取网页标题验证内容
            local page_title=$(curl -s "$BLOG_URL" | grep -o '<title>[^<]*</title>' | sed 's/<title>\(.*\)<\/title>/\1/' | head -1)
            if [ -n "$page_title" ]; then
                log_info "网页标题: $page_title"
            fi
            
            return 0
        else
            log_warning "网页访问异常 (HTTP $response_code)"
            
            if [ $retry_count -lt $((max_retries - 1)) ]; then
                log_info "等待 ${RETRY_DELAY}秒后重试..."
                sleep $RETRY_DELAY
            fi
        fi
        
        retry_count=$((retry_count + 1))
    done
    
    log_error "网页验证失败，已达到最大重试次数"
    return 1
}

# 生成报告
generate_report() {
    log_info "生成发布报告..."
    
    local report_file="/tmp/blog-publish-report-$(date '+%Y%m%d-%H%M%S').txt"
    
    cat > "$report_file" << EOF
技术博客自动发布报告
========================

发布时间: $(date '+%Y-%m-%d %H:%M:%S')
项目路径: $PROJECT_ROOT
GitHub仓库: $GITHUB_REPO
博客地址: $BLOG_URL

执行步骤:
1. ✅ 依赖检查
2. ✅ 项目验证
3. ✅ 文章生成
4. ✅ Git提交
5. ✅ GitHub推送
6. ✅ 网页验证

生成文章:
EOF

    # 列出新生成的文章
    cd "$PROJECT_ROOT"
    git show --name-only --pretty=format: HEAD | grep "src/content/blog/" | while read -r file; do
        echo "  - $file" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "状态: 成功" >> "$report_file"
    echo "报告文件: $report_file" >> "$report_file"
    
    log_success "报告已生成: $report_file"
    cat "$report_file"
}

# 主函数
main() {
    log_info "开始技术博客自动发布流程..."
    
    local start_time=$(date +%s)
    
    # 执行各个步骤
    check_dependencies
    validate_project
    generate_articles
    
    # 检查是否需要提交
    if check_git_status; then
        commit_changes
        push_to_github
        
        # 检查GitHub Actions
        local actions_status
        if check_github_actions; then
            actions_status="✅ 成功"
        else
            actions_status="⚠️  跳过或失败"
        fi
        
        # 等待部署完成后再验证网页
        log_info "等待部署完成..."
        sleep 60
        
        if verify_website; then
            log_success "🎉 技术博客发布成功！"
            generate_report
        else
            log_error "❌ 网页验证失败，但发布流程已完成"
            exit 1
        fi
    else
        log_info "没有新的更改，流程结束"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_info "总耗时: ${duration}秒"
    log_success "流程完成！"
}

# 错误处理
trap 'log_error "脚本执行中断"; exit 1' INT TERM

# 运行主函数
main "$@"