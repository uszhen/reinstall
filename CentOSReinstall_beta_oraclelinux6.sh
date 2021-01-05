#!/bin/bash

# Default Password: Pwd@CentOS , Change it after installation !

#IMGURL='https://github.com/ylx2016/reinstall/releases/download/CentOS-7.9.2009-x86_64-docker/CentOS-7.9.2009-x86_64-docker.tar.xz'
IMGURL='https://github.com/oracle/container-images/raw/dist-amd64/6.10/oraclelinux-6-amd64-rootfs.tar.xz'
BUSYBOX='https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-x86_64'
ROOTDIR='/os'

DOWNLOAD_IMG(){
    if command -v wget >/dev/null 2>&1 ;then
        mkdir $ROOTDIR
        wget -O "$ROOTDIR/os.tar.xz" $IMGURL
        wget -O "$ROOTDIR/busybox" $BUSYBOX
        chmod +x "$ROOTDIR/busybox"
    else
        echo "ERROR: wget not found !"
        exit
    fi
}

DELALL(){
    cp /etc/fstab $ROOTDIR
    if command -v chattr >/dev/null 2>&1; then
        find / -type f \( ! -path '/dev/*' -and ! -path '/proc/*' -and ! -path '/sys/*' -and ! -path "$ROOTDIR/*" \) \
            -exec chattr -i {} + 2>/dev/null || true
    fi
    find / \( ! -path '/dev/*' -and ! -path '/proc/*' -and ! -path '/sys/*' -and ! -path "$ROOTDIR/*" \) -delete 2>/dev/null || true
}

EXTRACT_IMG(){
    xzcat="$ROOTDIR/busybox xzcat"
    tar="$ROOTDIR/busybox tar"
    $xzcat "$ROOTDIR/os.tar.xz" | $tar -x -C /
    mv -f $ROOTDIR/fstab /etc
}

INIT_OS(){
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    rm -f /root/anaconda-ks.cfg
    export LC_ALL=en_US.UTF-8
    yum makecache fast
    #yum groupinstall core -y --exclude="aic94xx-firmware* alsa-* btrfs-progs* iprutils ivtv* iwl*firmware libertas* NetworkManager* plymouth* irqbalance postfix tuned polkit*"
    #yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
    #yum install -y grub2 dhclient openssh-server passwd wget kernel nano htop
	yum install -y oraclelinux-release-el6
	yum install -y oracle-epel-release-el6
    yum install -y grub grub2 dhclient openssh-server passwd wget nano kernel htop
    #yum install -y https://github.com/ylx2016/kernel/releases/download/cloud/kernel-5.10.3_cloud-1.x86_64.rpm
    #yum install -y https://github.com/ylx2016/kernel/releases/download/cloud/kernel-headers-5.10.3_cloud-1.x86_64.rpm
    
    sed -i '/^#PermitRootLogin\s/s/.*/&\nPermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
    sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 30/' /etc/ssh/sshd_config
    sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
    systemctl enable sshd
    echo "blog.ylx.me" | passwd --stdin root
	
	rpm -e grub
	yum install -y make bison gettext binutils flex gcc ncurses libusb SDL freetype device-mapper-libs
	wget ftp://ftp.gnu.org/gnu/grub/grub-2.00.tar.gz
	tar -xzf grub-2.00.tar.gz
	cd grub-2.00
	./configure --sbindir=/sbin --prefix=/usr
	make install

    cd /
    device=$(fdisk -l | grep -o /dev/*da | head -1)
    grub-install $device
    echo -e "GRUB_TIMEOUT=5\nGRUB_CMDLINE_LINUX=\"net.ifnames=0\"" > /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null

    touch /etc/sysconfig/network
    cat >/etc/sysconfig/network-scripts/ifcfg-eth0 <<EOFILE
    DEVICE=eth0
    BOOTPROTO=dhcp
    ONBOOT=yes
EOFILE

    cat >>/etc/security/limits.conf<<EOFILE

    * soft nofile 65535
    * hard nofile 65535
    * soft nproc 65535
    * hard nproc 65535
EOFILE
    sed -i 's/4096/65535/' /etc/security/limits.d/20-nproc.conf
}

DOWNLOAD_IMG
DELALL
EXTRACT_IMG
INIT_OS

rm -rf $ROOTDIR
yum clean all
sync
reboot -f