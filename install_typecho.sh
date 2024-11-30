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

# 检查系统版本
if ! grep -q "CentOS Stream" /etc/os-release; then
    print_error "此脚本仅支持CentOS Stream 9"
    exit 1
fi

# 检查并安装依赖
print_info "正在更新系统..."
dnf update -y

print_info "正在安装必要组件..."
dnf install -y php php-cli php-fpm php-mysqlnd php-gd php-xml php-mbstring mysql-server epel-release nginx

# 启动服务
print_info "正在启动服务..."
systemctl start php-fpm nginx mysqld
systemctl enable php-fpm nginx mysqld

# 检查服务状态
check_service() {
    if systemctl is-active $1 >/dev/null 2>&1; then
        print_info "$1 服务运行正常"
    else
        print_error "$1 服务启动失败"
        exit 1
    fi
}

check_service php-fpm
check_service nginx
check_service mysqld

# 创建网站目录
WEBSITE_ROOT="/var/www/typecho"
mkdir -p $WEBSITE_ROOT

# 生成随机密码
DB_NAME="typecho_db"
DB_USER="typecho_user"
DB_PASS=$(openssl rand -base64 12)
MYSQL_ROOT_PASS=$(openssl rand -base64 16)

# 创建数据库和用户
print_info "正在配置数据库..."
if [ -f ~/typecho_db_info.txt ]; then
    print_warning "检测到已存在的数据库配置文件，尝试使用其中的root密码..."
    EXISTING_ROOT_PASS=$(grep "MySQL Root密码：" ~/typecho_db_info.txt | awk '{print $3}')
    if [ ! -z "$EXISTING_ROOT_PASS" ]; then
        mysql -u root -p"$EXISTING_ROOT_PASS" <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS '$DB_USER'@'localhost';
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    fi
else
    print_info "首次配置MySQL，设置root密码..."
    mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
fi

# 保存数据库信息
DB_INFO_FILE=~/typecho_db_info.txt
cat > $DB_INFO_FILE <<EOF
数据库信息：
数据库名：$DB_NAME
数据库用户：$DB_USER
数据库密码：$DB_PASS
MySQL Root密码：$MYSQL_ROOT_PASS

修改数据库密码的命令：
mysql -u root -p
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '新密码';
FLUSH PRIVILEGES;

安全提示：请修改密码后删除此文件（~/typecho_db_info.txt）
EOF

# Typecho下载选项
print_info "Typecho下载选项："
echo "1. 从GitHub自动下载"
echo "2. 手动下载并上传"
read -p "请选择下载方式 [1/2]: " download_choice

case $download_choice in
    1)
        print_info "正在从GitHub下载Typecho..."
        if ! curl -L https://github.com/typecho/typecho/releases/latest/download/typecho.zip -o /tmp/typecho.zip; then
            print_error "下载失败，请选择手动下载方式"
            exit 1
        fi
        
        print_info "正在解压文件..."
        if ! unzip /tmp/typecho.zip -d $WEBSITE_ROOT; then
            print_error "解压失败"
            exit 1
        fi
        rm /tmp/typecho.zip
        ;;
    2)
        print_warning "请手动下载Typecho并上传到 $WEBSITE_ROOT 目录"
        print_info "上传完成后，我们将进行检查..."
        read -p "文件已上传完成？按回车键继续检查..."
        
        # 检查必要文件
        required_files=("index.php" "install.php")
        missing_files=0
        
        for file in "${required_files[@]}"; do
            if [ ! -f "$WEBSITE_ROOT/$file" ]; then
                print_error "未找到必要文件：$file"
                missing_files=1
            fi
        done
        
        if [ $missing_files -eq 1 ]; then
            print_error "目录 $WEBSITE_ROOT 中缺少必要的Typecho文件"
            print_warning "请确保上传了完整的Typecho程序包后重试"
            exit 1
        else
            print_info "文件检查通过，继续安装..."
        fi
        ;;
    *)
        print_error "无效的选择"
        exit 1
        ;;
esac

# 配置权限
print_info "正在配置目录权限..."
chown -R nginx:nginx $WEBSITE_ROOT
chmod -R 755 $WEBSITE_ROOT

# 创建并设置uploads目录权限
if [ ! -d "$WEBSITE_ROOT/usr/uploads" ]; then
    print_info "创建uploads目录..."
    mkdir -p $WEBSITE_ROOT/usr/uploads
fi
chmod -R 777 $WEBSITE_ROOT/usr/uploads

# 在配置Nginx之前，添加PHP-FPM错误日志配置
print_info "配置PHP错误日志..."
# 创建日志目录
mkdir -p /var/log/php-fpm
touch /var/log/php-fpm/www-error.log
chown -R nginx:nginx /var/log/php-fpm
chmod 755 /var/log/php-fpm
chmod 644 /var/log/php-fpm/www-error.log

# 配置SELinux（如果启用）
print_info "配置SELinux..."
if command -v sestatus >/dev/null 2>&1; then
    if sestatus | grep -q "SELinux status: *enabled"; then
        setsebool -P httpd_can_network_connect on
        setsebool -P httpd_unified on
        semanage fcontext -a -t httpd_sys_rw_content_t "$WEBSITE_ROOT(/.*)?"
        restorecon -Rv $WEBSITE_ROOT
    fi
fi

# 配置PHP-FPM
print_info "配置PHP-FPM..."
cat > /etc/php-fpm.d/www.conf <<EOF
[www]
user = nginx
group = nginx
listen = /run/php-fpm/www.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
request_terminate_timeout = 300
php_admin_value[error_log] = /var/log/php-fpm/www-error.log
php_admin_flag[log_errors] = on
php_value[session.save_handler] = files
php_value[session.save_path] = /var/lib/php/session
php_value[soap.wsdl_cache_dir] = /var/lib/php/wsdlcache
EOF

# 创建必要的PHP目录
mkdir -p /var/lib/php/session /var/lib/php/wsdlcache
chown -R nginx:nginx /var/lib/php
chmod 700 /var/lib/php/session /var/lib/php/wsdlcache

# 配置PHP
print_info "配置PHP..."
cat > /etc/php.d/99-typecho.ini <<EOF
[PHP]
display_errors = Off
log_errors = On
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
max_execution_time = 300
max_input_time = 300
memory_limit = 128M
post_max_size = 50M
upload_max_filesize = 50M
max_file_uploads = 20
date.timezone = Asia/Shanghai
session.cookie_httponly = 1
expose_php = Off
EOF

# 配置Nginx
print_info "配置Nginx..."
# 首先删除默认配置
rm -f /etc/nginx/conf.d/default.conf

# 备份原始nginx.conf
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# 创建新的nginx.conf
cat > /etc/nginx/nginx.conf <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
}
EOF

# 创建Typecho的配置文件
cat > /etc/nginx/conf.d/typecho.conf <<EOF
server {
    listen 80 default_server;
    server_name _;
    root $WEBSITE_ROOT;
    index index.php index.html;

    client_max_body_size 50m;
    client_body_buffer_size 128k;
    
    # 简化路由规则，避免重定向循环
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    # 静态文件缓存
    location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
        expires 30d;
        access_log off;
    }

    location ~ .*\.(js|css)?$ {
        expires 7d;
        access_log off;
    }

    # 安全设置
    location ~ /\. {
        deny all;
    }
    
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
}
EOF

# 检查并删除nginx.conf中可能存在的默认server块
sed -i '/server {/,/}/d' /etc/nginx/nginx.conf

# 确保include conf.d/*.conf存在
if ! grep -q "include /etc/nginx/conf.d/\*.conf;" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf
fi

# 检查配置文件语法
print_info "检查Nginx配置语法..."
nginx -t || {
    print_error "Nginx配置有误，请检查配置文件"
    exit 1
}

# 重启服务
print_info "重启服务..."
systemctl restart php-fpm || {
    print_error "PHP-FPM重启失败"
    journalctl -u php-fpm --no-pager | tail -n 20
    exit 1
}

systemctl restart nginx || {
    print_error "Nginx重启失败"
    journalctl -u nginx --no-pager | tail -n 20
    exit 1
}

# 最终检查
print_info "执行最终检查..."
# 检查PHP-FPM sock文件
if [ ! -S /run/php-fpm/www.sock ]; then
    print_error "PHP-FPM sock文件不存在"
    exit 1
fi

# 检查目录权限
find $WEBSITE_ROOT -type d -exec chmod 755 {} \;
find $WEBSITE_ROOT -type f -exec chmod 644 {} \;
chmod -R 777 $WEBSITE_ROOT/usr/uploads
chown -R nginx:nginx $WEBSITE_ROOT

echo "
================ 安装完成 ================

1. 数据库信息已保存到：$DB_INFO_FILE

2. 下一步：
   请访问 http://服务器IP地址/install.php 完成Typecho配置
   
   配置建议：
   - 数据库适配器：选择"MySQL原生函数适配器"
   - 数据库地址：localhost
   - 数据库名：$DB_NAME
   - 数据库用户名：$DB_USER
   - 数据库密码：$DB_PASS
   - 数据库前缀：建议保持默认
   - 高级选项：不启用数据库SSL证书验证

3. 安全建议：
   - 请及时修改数据库密码
   - 修改后删除数据库信息文件
   - Typecho配置完成后，请执行以下命令收回uploads目录权限：

     chmod 755 $WEBSITE_ROOT/usr/uploads
     chown -R nginx:nginx $WEBSITE_ROOT/usr/uploads

4. 故障排查：
   如遇到问题，请查看以下日志：
   - PHP错误日志：tail -f /var/log/php-fpm/www-error.log
   - Nginx错误日志：tail -f /var/log/nginx/error.log
   - PHP-FPM状态：systemctl status php-fpm
   - Nginx状态：systemctl status nginx

=========================================
" 