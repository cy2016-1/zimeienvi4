#!/bin/sh

config_path='/var/zimeiconf'

sudo rm -rf $config_path
# 创建目录
sudo mkdir -p $config_path

# 资料包地址
git_url='https://gitee.com/kxdev/zimeienvi3.git'

sudo git clone --recursive $git_url $config_path

cd $config_path

sudo mv /root/.bashrc /root/.bashrc_bak
sudo cp -f ${config_path}/config/.bashrc /root/.bashrc

sudo chmod +x setup.sh

sudo ./setup.sh
