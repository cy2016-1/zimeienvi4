#!/bin/sh

#是否初始化过离线安装环境
IS_INIT=0

#是否一键安装
IS_AKEY=0

config_path='/tmp/zimeiconf'

THIS_PATH=$(cd `dirname $0`; pwd)

#格式化echo 
format_echo(){
	if [ $2 ];then
		echo "\033[31m${1}\033[0m"
	else
		echo "\033[92m${1}\033[0m"
	fi
}

# 设置菜单大小
calc_wt_size() {
  WT_HEIGHT=16
  WT_WIDTH=50
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}
calc_wt_size

#开始接收输入
start(){
	FUN=$(whiptail --title "请选择安装软件（直接选中回车）" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button 取消 --ok-button 确定 \
		"1" "一键安装设置全部环境" \
		"2" "修改pi和root用户密码" \
		"3" "设置系统时区和语言默认为中文" \
        "4" "安装声卡驱动" \
        "5" "安装自美系统必备模块" \
        "R" "还原离线安装环境" \
        "X" "退出"\
        3>&1 1>&2 2>&3)

	case $FUN in
		1)
	    	format_echo "一键安装全部环境"
	    	akey_setup
	    ;;
		2)
	    	format_echo "开始修改pi和root用户密码"
	    	set_userpass
	    ;;
		3)
	    	format_echo "设置系统语言默认为中文"
	    	set_localtime
	    ;;
	    4)
	    	format_echo "开始安装声卡驱动"
	    	setup_sound
	    ;;
	    5)
	    	format_echo '开始环境必备模块'
	    	setup_other
	    ;;
	    "r"|"R")
	    	format_echo '还原离线安装环境'
	    	reduct_sources
	    ;;
	    "x"|"X")
	    	format_echo '成功退出！' 1
	    ;;
	    *)
	    	format_echo '成功退出！' 2
	    ;;
	esac
}

###
 # @说明: 修改用户密码
###
set_userpass(){
	format_echo "设置 Pi 密码" 1
	sudo passwd pi

	format_echo "设置 Root 密码:" 1
	sudo passwd root

	if [ $IS_AKEY -eq 0 ]; then start; fi
}

# 系统时区设置
set_localtime(){
	format_echo "系统时区设置"
	sudo cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

	format_echo "设置语言默认为中文"
	sudo cp -f ${config_path}/config/locale.gen /etc/locale.gen
	sudo locale-gen
	sudo localectl set-locale LANG=zh_CN.UTF-8

	if [ $IS_AKEY -eq 0 ]; then start; fi
}

#安装初始化
setup_init(){
	if [ $IS_INIT -eq 1 ]
	then 
		format_echo "离线安装环境已经初始化" 1
		sleep 1
		return 0
	fi
		#给包文件夹可读写权限
	sudo chmod -R 777 ${config_path}/apt_get/

	format_echo "生成包索引文件"
	sudo touch ${config_path}/apt_get/Packages.gz
	sleep 1

	cd ${config_path}

	format_echo "创建索引"
	sudo dpkg-scanpackages ${config_path}/apt_get /dev/null | gzip > ${config_path}/apt_get/Packages.gz
	sleep 1

	format_echo "替换源列表"
	sudo mkdir -p /etc/apt_bak/sources.list.d
	if [ ! -f "/etc/apt_bak/sources.list.default" ];then
		sudo mv /etc/apt/sources.list /etc/apt_bak/sources.list.default
	fi
	sudo cp -f ${config_path}/config/sources.list.local /etc/apt/sources.list

	if [ ! -f "/etc/apt_bak/sources.list.d/raspi.list.default" ];then
		sudo mv /etc/apt/sources.list.d/raspi.list /etc/apt_bak/sources.list.d/raspi.list.default
	fi
	sudo cp -f ${config_path}/config/raspi.list.local /etc/apt/sources.list.d/raspi.list
	sleep 1

	format_echo "更新软件索引"
	sudo apt-get update

	format_echo "离线安装环境初始化已完成" 1
	sleep 1

	IS_INIT=1
}

#还原sources源
reduct_sources(){
	format_echo "还原源列表"
	if [ -f "/etc/apt_bak/sources.list.default" ];then
		sudo mv /etc/apt_bak/sources.list.default /etc/apt/sources.list
	fi
	if [ -f "/etc/apt_bak/sources.list.d/raspi.list.default" ];then
		sudo mv /etc/apt_bak/sources.list.d/raspi.list.default /etc/apt/sources.list.d/raspi.list
	fi

	format_echo "更新软件索引"
	sudo apt-get update
	
	format_echo "还原源列表完成" 1
	sleep 1

	if [ $IS_AKEY -eq 0 ]; then start; fi
}

#安装声卡
setup_sound(){
	format_echo "开始安装声卡驱动"

	comm=`arecord -l | grep "wm8960-soundcard"`
	if [ "$comm" != "" ]
	then
		format_echo "声卡驱动已经安装！" 1
		sleep 1
		if [ $IS_AKEY -eq 0 ]; then start; fi
		return 0
	fi

	# 使用本地源安装 
	#setup_init

	sudo apt-get -y install raspberrypi-kernel-headers raspberrypi-kernel
	sudo apt-get -y install dkms git i2c-tools libasound2-plugins

	sudo chmod -R 777 ${config_path}/Github/

	cd ${config_path}/Github/

	sudo ./install.sh

	if [ $IS_AKEY -eq 0 ]; then start; fi
}

# 系统设置
set_system(){
	format_echo "设置开机动画"
	sudo mv /usr/share/plymouth/themes/pix/splash.png /usr/share/plymouth/themes/pix/splash_bak.png
	sleep 1

	sudo cp -f ${config_path}/config/splash.png /usr/share/plymouth/themes/pix/splash.png
	sleep 1

	format_echo "设备任务栏"
	sudo mv /home/pi/.config/lxpanel/LXDE-pi/panels/panel /home/pi/.config/lxpanel/LXDE-pi/panels/panel_bak
	sleep 1

	sudo mkdir -p /home/pi/.config/lxpanel/LXDE-pi/panels
	sleep 1

	sudo cp -f ${config_path}/config/panel /home/pi/.config/lxpanel/LXDE-pi/panels/panel

	format_echo "设置桌面"
	sudo mv /home/pi/.config/pcmanfm/LXDE-pi/desktop-items-0.conf /home/pi/.config/pcmanfm/LXDE-pi/desktop-items-0.conf.bak
	sleep 1

	sudo mkdir -p /home/pi/.config/pcmanfm/LXDE-pi
	sleep 1

	sudo cp -f ${config_path}/config/desktop-items-0.conf /home/pi/.config/pcmanfm/LXDE-pi/desktop-items-0.conf

	format_echo "设置桌面背景"
	sudo rm -f /usr/share/rpd-wallpaper/road.jpg
	sleep 1
	
	sudo cp -f ${config_path}/config/road.jpg /usr/share/rpd-wallpaper/road.jpg

	format_echo "设备顶部LOGO不显示"
	sudo sed -i s/'console=tty1'/'console=tty3'/g /boot/cmdline.txt
	sudo sed -i s/'ignore-serial-consoles'/'ignore-serial-consoles logo.nologo loglevel=3'/g /boot/cmdline.txt
}

#安装其他功能包
setup_other(){
	format_echo "安装视频环境"

	# 系统基本设置
	set_system

	# 使用本地源安装 如果用户没有安装声音，这一步还是需要做
	#setup_init

	format_echo "安装基本库"
	sudo apt-get -y install libjpeg-dev
	sudo apt-get -y install libhdf5-dev
	sudo apt-get -y install libtiff5-dev
	sudo apt-get -y install libpng12-dev
	sudo apt-get -y install libqtgui4 libqt4-test
	sudo apt-get -y install libjasper-dev

	format_echo "安装中文字库"
	sudo apt-get -y install ttf-wqy-zenhei

	format_echo "安装鼠标隐藏功能"
	sudo apt-get -y install unclutter

	format_echo "安装创建热点功能包"
	sudo apt-get -y install hostapd dnsmasq

	format_echo "安装Nmap网络扫描功能包"
	sudo apt-get -y install nmap

	format_echo "安装GPIO功能包"
	sudo apt-get -y install python3-rpi.gpio

	format_echo "安装MPG123功能包"
	sudo apt-get -y install mpg123

	format_echo "安装播放器mplayer功能包"
	sudo apt-get -y install mplayer

	format_echo "安装python3-pyaudio功能包"
	sudo apt-get -y install python3-pyaudio

	format_echo "安装libatlas功能包"
	sudo apt-get -y install libatlas-base-dev

	format_echo "安装ntpdate功能包"
	sudo apt-get -y install ntpdate

	format_echo "PIP安装pycurl包"
	sudo pip3 install ${config_path}/pip/pycurl-7.43.0.3-cp37-cp37m-linux_armv7l.whl

	format_echo "PIP安装psutil包"
	sudo pip3 install ${config_path}/pip/psutil-5.6.2.tar.gz
	
	format_echo "PIP安装websocket_client包"
	sudo pip3 install ${config_path}/pip/websocket_client-0.56.0-py2.py3-none-any.whl

	format_echo "PIP安装webrtcvad包"
	sudo pip3 install ${config_path}/pip/webrtcvad-2.0.10-cp37-cp37m-linux_armv7l.whl

	format_echo "PIP安装imutils包"
	sudo pip3 install ${config_path}/pip/imutils-0.5.3-py3-none-any.whl

	format_echo "PIP安装opencv包"
	sudo pip3 install ${config_path}/pip/opencv_python-3.4.3.18-cp37-cp37m-linux_armv7l.whl
	sudo pip3 install ${config_path}/pip/opencv_contrib_python-3.4.3.18-cp37-cp37m-linux_armv7l.whl

	format_echo "安装其他功能包完成" 1
	sleep 1
	
	if [ $IS_AKEY -eq 0 ]; then start; fi	
}

#一键安装全部环境
akey_setup(){
	IS_AKEY=1
	set_userpass
	set_localtime
	setup_sound
	setup_other
	reduct_sources
	IS_AKEY=0
}

start


