# Typecho 自动部署脚本 v1.0.0

作者：ligang
个人站点：https://www.ligangblog.com
版本：v1.0.0
版权所有 © 2024 ligang

这是一套用于CentOS Stream 9系统的Typecho博客系统自动部署脚本。包含安装脚本和卸载脚本，可以快速部署或清理Typecho环境。

## 系统要求

- CentOS Stream 9
- Root权限
- 干净的系统环境（建议在全新安装的系统上使用）

## 包含文件

- install_typecho.sh: Typecho安装脚本
- uninstall_typecho.sh: Typecho卸载脚本
- README.txt: 说明文档

## 安装Typecho

下载所有脚本文件到服务器后：

添加执行权限：
chmod +x install_typecho.sh uninstall_typecho.sh

执行安装：
./install_typecho.sh

安装过程中需要：
- 选择Typecho下载方式（自动下载或手动上传）
- 记录生成的数据库信息
- 按提示完成后续配置

## 卸载Typecho

执行卸载：
./uninstall_typecho.sh

卸载过程会：
- 完全清理所有Typecho文件
- 清理数据库
- 重置MySQL
- 删除配置文件

## 重要提示

安装完成后请及时：
- 修改数据库密码
- 删除数据库信息文件（~/typecho_db_info.txt）
- 收回uploads目录的777权限

配置数据库时建议：
- 选择"MySQL原生函数适配器"
- 不启用SSL证书验证
- 使用脚本生成的数据库信息

常见问题排查：
- PHP错误日志：/var/log/php-fpm/www-error.log
- Nginx错误日志：/var/log/nginx/error.log
- 服务状态检查：systemctl status php-fpm
                systemctl status nginx
                systemctl status mysqld

## 目录说明

安装后的主要文件位置：
- 网站目录：/var/www/typecho
- Nginx配置：/etc/nginx/conf.d/typecho.conf
- PHP-FPM配置：/etc/php-fpm.d/www.conf
- PHP配置：/etc/php.d/99-typecho.ini
- 数据库信息：~/typecho_db_info.txt

## 功能特点

安装脚本：
- 自动配置LNMP环境
- 自动创建数据库
- 自动配置PHP和Nginx
- 自动设置目录权限
- 提供两种安装方式
- 配置错误日志
- 详细的安装提示

卸载脚本：
- 完全清理网站文件
- 重置数据库环境
- 清理配置文件
- 删除日志文件

## 注意事项

- 仅支持CentOS Stream 9系统
- 需要root权限运行
- 建议在全新系统上使用
- 安装前确保端口80未被占用
- 请及时保存数据库信息
- 定期查看错误日志
- 建议定期备份数据

## 免责声明

本脚本仅用于学习和测试环境。在生产环境使用前，请仔细测试并根据实际需求修改配置。作者不对使用本脚本导致的任何问题负责。