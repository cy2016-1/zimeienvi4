#!/bin/sh

#是否初始化过离线安装环境
IS_INIT=0

#是否一键安装
IS_AKEY=0

config_path='/tmp/zimeiconf'

CONFIG=/boot/config.txt

THIS_PATH=$(cd `dirname $0`; pwd)

#格式化echo 
format_echo(){
	if [ $2 ];then
		echo "\033[31m${1}\033[0m"
	else
		echo "\033[92m${1}\033[0m"
	fi
}

set_config_var() {
  lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
    line=key.."="..value
    made_change=true
  end
  print(line)
end

if not made_change then
  print(key.."="..value)
end
EOF
sudo mv "$3.bak" "$3"
}

#获取指定配置文件中对应的值
get_config_var() {
  lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
local found=false
for line in file:lines() do
  local val = line:match("^%s*"..key.."=(.*)$")
  if (val ~= nil) then
    print(val)
    found=true
    break
  end
end
if not found then
   print(0)
end
EOF
}


#删除一些不要的软件
del_garbage(){
	sudo rm -f /etc/xdg/autostart/piwiz.desktop
}
del_garbage

# 设置菜单大小
calc_wt_size() {
  WT_HEIGHT=16
  WT_WIDTH=50
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}
calc_wt_size

#获取VNC状态
#返回1 -- 未启用 0 -- 已启用
get_vnc() {
  if systemctl status vncserver-x11-serviced.service | grep -q inactive; then
  	echo 1
  else
  	echo 0
  fi
}

#获取SSH状态
#返回1 -- 未启用 0 -- 已启用
get_ssh() {
  if service ssh status | grep -q inactive; then
    echo 1
  else
    echo 0
  fi
}

#开始接收输入
start(){
	FUN=$(whiptail --title "请选择安装软件（直接选中回车）" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button 取消 --ok-button 确定 \
		"A" "一键安装设置全部环境" \
		"1" "修改pi和root用户密码为: Keyicx" \
		"2" "系统基本设置" \
		"3" "安装默认摄像头驱动" \
        "4" "安装声卡驱动" \
        "5" "安装自美系统必备模块" \
        "6" "安装MQTT服务器模块" \
        "R" "还原离线安装环境" \
        "X" "退出" \
        3>&1 1>&2 2>&3)

	case $FUN in
		"a"|"A")
	    	format_echo "一键安装全部环境"
	    	akey_setup
	    ;;
		1)
	    	format_echo "开始修改pi和root用户密码为: Keyicx"
	    	set_userpass
	    ;;
		2)
	    	format_echo "系统基本设置"
	    	set_localtime
	    ;;
	    3)
	    	format_echo "开始安装摄像头驱动"
	    	setup_camera
	    ;;
	    4)
	    	format_echo "开始安装声卡驱动"
	    	setup_sound
	    ;;
	    5)
	    	format_echo '开始环境必备模块'
	    	setup_other
	    ;;
	    6)
	    	format_echo '开始安装MQTT服务器'
	    	setup_mosquitto
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
	format_echo "修改Pi用户密码为: Keyicx"
	sudo passwd pi <<EOF
Keyicx
Keyicx
EOF

	format_echo "修改Root用户密码: Keyicx"
	sudo passwd root <<EOF
Keyicx
Keyicx
EOF

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

	format_echo "关闭屏幕保护"
	if [ ! -f "/etc/profile.d/offScreensaver.sh" ];then
	sudo echo -e 'xset dpms 0 0 0\nxset s off' > /etc/profile.d/offScreensaver.sh
	fi

	format_echo "设备顶部LOGO不显示"
	sudo sed -i s/'console=tty1'/'console=tty3'/g /boot/cmdline.txt
	sudo sed -i s/'ignore-serial-consoles'/'ignore-serial-consoles logo.nologo loglevel=3'/g /boot/cmdline.txt

	format_echo "启用WiFi"
	sudo rfkill unblock wifi
	sudo rfkill unblock all

	if [ $(get_vnc) -eq 1 ]; then
		format_echo "开启VNC"
		#没启用，开始安装
		if [ ! -d /usr/share/doc/realvnc-vnc-server ]; then
	    	sudo apt-get install -y realvnc-vnc-server
		fi
		sudo systemctl enable vncserver-x11-serviced.service
		sudo systemctl start vncserver-x11-serviced.service
	fi

	#开启root用户SSH登录权限
	if [ $(cat /etc/ssh/sshd_config | grep -c "PermitRootLogin yes") -eq 0 ];then
		format_echo "打开root登录，设置端口：21232"
		sudo sed -i -E 's/^\#?Port.+/Port 21232/g' /etc/ssh/sshd_config
		sudo sed -i -E 's/^\#?PermitRootLogin.+/PermitRootLogin yes/g' /etc/ssh/sshd_config
	fi
	if [ $(get_ssh) -eq 1 ]; then
		format_echo "启用ssh服务"
		sudo passwd --unlock root
		sudo ssh-keygen -A
		sudo systemctl enable ssh
		sudo systemctl start ssh
	fi
}

# 系统时区设置
set_localtime(){
	format_echo "系统时区设置"
	sudo cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

	format_echo "设置语言默认为中文"
	sudo cp -f ${config_path}/config/locale.gen /etc/locale.gen
	sudo locale-gen
	sudo localectl set-locale LANG=zh_CN.UTF-8

	# 系统基本设置
	set_system

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
	if [ -f "${config_path}/config/sources.list.tsinghua" ];then
		sudo mv ${config_path}/config/sources.list.tsinghua /etc/apt/sources.list
	fi
	if [ -f "${config_path}/config/raspi.list.tsinghua" ];then
		sudo mv ${config_path}/config/raspi.list.tsinghua /etc/apt/sources.list.d/raspi.list
	fi

	format_echo "更新软件索引"
	sudo apt-get update

	sudo apt -y --fix-broken install
	
	format_echo "还原源列表完成" 1
	sleep 1

	if [ $IS_AKEY -eq 0 ]; then start; fi
}

get_camera() {
  CAM=$(get_config_var start_x $CONFIG)
  if [ $CAM -eq 1 ]; then
    echo 0
  else
    echo 1
  fi
}

#安装摄像头
setup_camera() {
  if [ ! -e /boot/start_x.elf ]; then
  	whiptail --msgbox "您的系统版本太旧了(没有start_x.elf)。请更新系统" 20 60 2
    return 1
  fi
  sed $CONFIG -i -e "s/^startx/#startx/"
  sed $CONFIG -i -e "s/^fixup_file/#fixup_file/"

  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_camera) -eq 0 ]; then
    DEFAULT=
    CURRENT=1
  fi

  RET=1
  if [ $IS_AKEY -eq 0 ]; then
    if (whiptail --yes-button "启用" --no-button "禁用" --yesno "您是否启用摄像头?" 20 60) then
    	RET=1
    else
    	RET=0
    fi
  fi

  if [ $RET -eq $CURRENT ]; then
    STATUS="启用"
    return 1
  fi
  
  if [ $RET -eq 1 ]; then
    set_config_var start_x 1 $CONFIG
    CUR_GPU_MEM=$(get_config_var gpu_mem $CONFIG)
    if [ -z "$CUR_GPU_MEM" ] || [ "$CUR_GPU_MEM" -lt 128 ]; then
      set_config_var gpu_mem 128 $CONFIG
    fi
    STATUS="启用"
  elif [ $RET -eq 0 ]; then
    set_config_var start_x 0 $CONFIG
    sed $CONFIG -i -e "s/^start_file/#start_file/"
    STATUS="禁用"
  else
    return $RET
  fi
  
  if [ $IS_AKEY -eq 0 ]; then
    whiptail --msgbox "摄像头已 $STATUS" 20 60 1
  fi
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
	setup_init

	format_echo "安装声卡依赖"
	sudo dpkg -i ${config_path}/sound/raspberrypi-kernel-headers_*.deb	
	sudo dpkg -i ${config_path}/sound/raspberrypi-kernel_*.deb
	sudo dpkg -i ${config_path}/sound/dkms_*.deb
	sudo dpkg -i ${config_path}/sound/libasound2-plugins_*.deb

	sudo chmod -R 777 ${config_path}/wm8960/

	cd ${config_path}/wm8960/

	sudo ./install.sh

	if [ $IS_AKEY -eq 0 ]; then start; fi
}

setup_mosquitto(){
	format_echo "开始安装mqtt服务器"

	format_echo "安装依赖"
	cd ${config_path}
	sudo dpkg -i ${config_path}/apt_get/libssl*.deb
	sudo dpkg -i ${config_path}/apt_get/libc-ares*.deb
	sudo dpkg -i ${config_path}/apt_get/uuid*.deb
	sudo tar zxfv ${config_path}/mqtt/mosquitto-1.6.9.tar.gz
	cd ${config_path}/mosquitto-1.6.9
	sudo make
	sudo make install
	sudo ln -s /usr/local/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so.1
	sudo ldconfig
	sudo cp -f ${config_path}/config/mosquitto.conf /etc/mosquitto/mosquitto.conf
	cd ${config_path}

	if [ $IS_AKEY -eq 0 ]; then start; fi
}

#安装其他功能包
setup_other(){
	# 使用本地源安装 如果用户没有安装声音，这一步还是需要做
	setup_init

	format_echo "安装基本库"
	sudo dpkg -i ${config_path}/apt_get/*.deb

	format_echo "PIP3安装.whl类型库"
	sudo pip3 install ${config_path}/pip/*.whl

	format_echo "PIP3安装.gz类型包"
	sudo pip3 install ${config_path}/pip/*.gz
	
	sleep 1
	
	if [ $IS_AKEY -eq 0 ]; then start; fi	
}

#一键安装全部环境
akey_setup(){
	IS_AKEY=1
	set_userpass
	set_localtime
	setup_camera
	setup_sound
	setup_other
	setup_mosquitto
	reduct_sources
	IS_AKEY=0
}

start


