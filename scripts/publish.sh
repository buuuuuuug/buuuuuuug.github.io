#!/bin/bash

# 技术博客发布流程脚本
# 用于自动化博客文章的生成、测试、提交和部署流程

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_ROOT="/Users/chaneychan/CodeProjects/buuuuuuug.github.io"
GITHUB_REPO="https://github.com/buuuuuuug/buuuuuuug.github.io"
BLOG_URL="https://buuuuuuug.github.io"

# 日志函数
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
    
    local missing_deps=()
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        missing_deps+=("nodejs")
    fi
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        missing_deps+=("npm")
    fi
    
    # 检查git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    # 检查curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少依赖项: ${missing_deps[*]}"
        log_info "请安装缺失的依赖项后重新运行"
        exit 1
    fi
    
    log_success "所有依赖项检查通过"
}

# 验证项目结构
validate_project() {
    log_info "验证项目结构..."
    
    cd "$PROJECT_ROOT"
    
    # 检查必要的目录和文件
    local required_items=(
        "package.json"
        "astro.config.ts"
        "src/content/blog"
        "scripts/blog-generator.js"
    )
    
    for item in "${required_items[@]}"; do
        if [ ! -e "$item" ]; then
            log_error "项目结构不完整，缺少: $item"
            exit 1
        fi
    done
    
    # 验证博客生成器
    node scripts/blog-generator.js validate
    
    log_success "项目结构验证通过"
}

# 生成文章
generate_articles() {
    log_info "生成博客文章..."
    
    cd "$PROJECT_ROOT"
    
    # 检查是否有生成参数
    local count=${1:-3}
    local topic=${2:-""}
    
    if [ -n "$topic" ]; then
        log_info "生成特定主题文章: $topic"
        node scripts/blog-generator.js generate "$topic" tutorial --featured
    else
        log_info "批量生成 $count 篇文章"
        node scripts/blog-generator.js batch "$count"
    fi
    
    log_success "文章生成完成"
}

# 显示文章统计
show_article_stats() {
    log_info "当前文章统计:"
    node scripts/blog-generator.js stats
}

# 本地测试
local_test() {
    log_info "运行本地测试..."
    
    cd "$PROJECT_ROOT"
    
    # 安装依赖
    if [ ! -d "node_modules" ]; then
        log_info "安装项目依赖..."
        npm install
    fi
    
    # 运行lint检查
    if npm run lint &> /dev/null; then
        log_info "运行代码检查..."
        npm run lint
    else
        log_warning "未配置lint脚本，跳过代码检查"
    fi
    
    # 构建测试
    log_info "构建项目..."
    npm run build
    
    log_success "本地测试通过"
}

# 提交更改
commit_changes() {
    log_info "提交更改到Git..."
    
    cd "$PROJECT_ROOT"
    
    # 检查是否有更改
    if [ -z "$(git status --porcelain)" ]; then
        log_warning "没有需要提交的更改"
        return 0
    fi
    
    # 添加所有更改
    git add .
    
    # 生成提交信息
    local commit_msg="📝 $(date '+%Y-%m-%d') 更新博客文章"
    
    # 获取文章统计
    local stats=$(node scripts/blog-generator.js stats | grep -E "(总文章数|java:|rust:|ai:|database:|devops:)" | tr '\n' ' ')
    commit_msg="$commit_msg - $stats"
    
    # 提交更改
    git commit -m "$commit_msg"
    
    log_success "更改已提交"
}

# 推送到GitHub
push_to_github() {
    log_info "推送到GitHub..."
    
    cd "$PROJECT_ROOT"
    
    # 检查远程仓库
    local remote_url=$(git config --get remote.origin.url)
    if [[ "$remote_url" != *"buuuuuuug.github.io"* ]]; then
        log_error "远程仓库配置不正确: $remote_url"
        exit 1
    fi
    
    # 推送更改
    git push origin main
    
    log_success "已推送到GitHub"
}

# 验证网页访问
verify_web_access() {
    log_info "验证网页访问..."
    
    local max_retries=30
    local retry_interval=10
    local retry_count=0
    
    log_info "等待部署完成..."
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$BLOG_URL" | grep -q "200"; then
            log_success "网站访问正常: $BLOG_URL"
            
            # 获取并显示网站状态
            local response_time=$(curl -s -o /dev/null -w "%{time_total}" "$BLOG_URL")
            log_info "响应时间: ${response_time}s"
            
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        log_info "等待部署完成... (${retry_count}/${max_retries})"
        sleep $retry_interval
    done
    
    log_error "网站访问验证失败，请手动检查: $BLOG_URL"
    return 1
}

# 显示部署状态
show_deploy_status() {
    log_info "部署状态信息:"
    log_info "GitHub仓库: $GITHUB_REPO"
    log_info "博客地址: $BLOG_URL"
    log_info "GitHub Actions: $GITHUB_REPO/actions"
    
    # 显示最近的提交
    log_info "最近的提交:"
    git log --oneline -5
}

# 完整的发布流程
full_publish() {
    log_info "🚀 开始完整的博客发布流程..."
    
    local article_count=${1:-3}
    local specific_topic=${2:-""}
    
    # 步骤1: 检查依赖
    check_dependencies
    
    # 步骤2: 验证项目
    validate_project
    
    # 步骤3: 显示当前统计
    show_article_stats
    
    # 步骤4: 生成文章
    generate_articles "$article_count" "$specific_topic"
    
    # 步骤5: 本地测试
    local_test
    
    # 步骤6: 提交更改
    commit_changes
    
    # 步骤7: 推送到GitHub
    push_to_github
    
    # 步骤8: 验证网页访问
    verify_web_access
    
    # 步骤9: 显示状态
    show_deploy_status
    
    log_success "🎉 博客发布流程完成！"
}

# 快速发布（跳过生成）
quick_publish() {
    log_info "⚡ 开始快速发布流程..."
    
    # 步骤1: 检查依赖
    check_dependencies
    
    # 步骤2: 验证项目
    validate_project
    
    # 步骤3: 本地测试
    local_test
    
    # 步骤4: 提交更改
    commit_changes
    
    # 步骤5: 推送到GitHub
    push_to_github
    
    # 步骤6: 验证网页访问
    verify_web_access
    
    # 步骤7: 显示状态
    show_deploy_status
    
    log_success "🎉 快速发布流程完成！"
}

# 显示帮助信息
show_help() {
    echo "📝 技术博客发布流程脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 [command] [options]"
    echo ""
    echo "命令:"
    echo "  full [count] [topic]    - 完整发布流程（生成文章+发布）"
    echo "  quick                   - 快速发布流程（仅发布现有内容）"
    echo "  generate [count] [topic] - 仅生成文章"
    echo "  test                    - 仅运行本地测试"
    echo "  publish                 - 仅提交和推送"
    echo "  verify                  - 仅验证网站访问"
    echo "  stats                   - 显示文章统计"
    echo "  help                    - 显示帮助信息"
    echo ""
    echo "参数:"
    echo "  count: 生成文章数量 (默认: 3)"
    echo "  topic: 特定主题 (java|rust|ai|database|devops)"
    echo ""
    echo "示例:"
    echo "  $0 full 5 java          - 生成5篇Java文章并发布"
    echo "  $0 quick                - 快速发布现有内容"
    echo "  $0 generate 3 rust      - 生成3篇Rust文章"
    echo "  $0 test                 - 运行本地测试"
    echo ""
    echo "项目信息:"
    echo "  项目路径: $PROJECT_ROOT"
    echo "  GitHub仓库: $GITHUB_REPO"
    echo "  博客地址: $BLOG_URL"
}

# 主函数
main() {
    case "${1:-help}" in
        full)
            full_publish "$2" "$3"
            ;;
        quick)
            quick_publish
            ;;
        generate)
            check_dependencies
            validate_project
            generate_articles "$2" "$3"
            show_article_stats
            ;;
        test)
            check_dependencies
            validate_project
            local_test
            ;;
        publish)
            check_dependencies
            validate_project
            commit_changes
            push_to_github
            ;;
        verify)
            verify_web_access
            ;;
        stats)
            check_dependencies
            validate_project
            show_article_stats
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"