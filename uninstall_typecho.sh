#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 输出函数
print_info() {
    echo -e "${GREEN}[信息] $1${NC}"
}

print_error() {
    echo -e "${RED}[错误] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[警告] $1${NC}"
}

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用root权限运行此脚本"
    exit 1
fi

# 确认卸载
print_warning "此操作将完全删除Typecho及其所有数据！"
print_warning "包括网站文件、数据库、Nginx配置等"
read -p "确定要继续吗？(y/n): " confirm
if [ "$confirm" != "y" ]; then
    print_info "取消卸载"
    exit 0
fi

# 停止MySQL服务
print_info "停止MySQL服务..."
systemctl stop mysqld

# 完全清理MySQL数据和配置
print_info "清理MySQL数据和配置..."
rm -rf /var/lib/mysql/*
rm -rf /var/log/mysql
rm -f /etc/my.cnf
rm -f /etc/my.cnf.d/*

# 重新初始化MySQL目录
print_info "重置MySQL..."
mkdir -p /var/lib/mysql
chown -R mysql:mysql /var/lib/mysql
chmod 750 /var/lib/mysql

# 删除网站文件
print_info "正在删除网站文件..."
rm -rf /var/www/typecho

# 删除Nginx配置
print_info "正在删除Nginx配置..."
rm -f /etc/nginx/conf.d/typecho.conf
systemctl restart nginx

# 清理PHP-FPM相关文件
print_info "清理PHP-FPM相关文件..."
rm -rf /var/log/php-fpm
rm -rf /var/lib/php/session/*
rm -rf /var/lib/php/wsdlcache/*

# 清理可能存在的数据库信息文件
if [ -f ~/typecho_db_info.txt ]; then
    print_info "正在删除数据库信息文件..."
    rm -f ~/typecho_db_info.txt
fi

print_info "卸载完成！以下内容已被删除："
echo "- MySQL数据和配置"
echo "- 网站文件 (/var/www/typecho)"
echo "- Nginx配置文件 (/etc/nginx/conf.d/typecho.conf)"
echo "- PHP-FPM日志和缓存"
echo "- 数据库信息文件 (~/typecho_db_info.txt)"

print_warning "如果要完全删除LAMP/LNMP环境，请运行："
echo "dnf remove -y php php-cli php-fpm php-mysqlnd php-gd php-xml php-mbstring mysql-server nginx"
echo "rm -rf /var/lib/mysql" 