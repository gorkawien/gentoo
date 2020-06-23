#!/bin/sh
#################################
# Gentoo Installer v1.0		#
# By Kaddeh			#
#################################

# Get Existing Drives
existing_drives=$(fdisk -l | grep /dev | grep -i disk | cut -c11-13)

# Set default drive
default_drive=$(fdisk -l | grep --max-count=1 /dev | cut -c11-13)

echo $default_drive

echo -e "What drive do you want to partition? [$existing_drives]: \c"
read drive

echo -e "What Architecture do you want to use (Default is x86)? [x86, i686]: \c"
read system_architecture

echo -e "Do you have have a local gentoo rsync? (Default is No) [Yes/No] \c "
read local_rsync

if [ "$local_rsync" == "yes" ]
then
	echo -e "What is the IP of the rsync server? \c"
	read rsync_ip
elif [ "$local_rsync" == "Yes" ]
then
	echo -e "What is the IP of the rsync server? \c"
	read rsync_ip
elif [ "$local_rsync" == "no" ]
then
	rsync_ip="rsync.namerica.gentoo.org"
elif [ "$local_rsync" == "No" ]
then
	rsync_ip="rsync.namerica.gentoo.org"
elif [ "$local_rsync" == "" ]
then
	rsync_ip="rsync.namerica.gentoo.org"
else
	echo "Something isn't working QQ"
fi

# Prompt for X install
echo -e "Do you want to install GUI? (Default is No) [Yes/No] \c "
read install_xorg

if [ "$install_xorg" == "Yes" ]
then
        install_x=1
elif [ "$install_xorg" == "yes" ]
then
        install_x=1
elif [ "$install_xorg" == "y" ]
then
        install_x=1
elif [ "$install_xorg" == "Y" ]
then
        install_x=1
else
        install_x=0
fi

#echo -e "Post-Install username: [none] \c "
#read new_user

# Make Drive Selection
if [ "$drive" == "" ]
then
	selected_drive=$default_drive
else
	# Verify Drive Exists
	does_exist=$(fdisk -l | grep --max-count=1 -ci $drive)

	if [ "$does_exist" == "1" ]
	then
		selected_drive=$drive
	else
		echo -e "The selected drive" $drive "does not exist.  Using" $default_drive "instead."
		selected_drive=$default_drive
	fi
fi

num_partitions=$(fdisk -l | grep ^/dev | grep -ic $selected_drive)

echo "There are" $num_partitions "partitions on" $selected_drive

partitions=1

# Clear existing partition file
rm -rf partition_table
touch partition_table

while [ "$partitions" -le "$num_partitions" ]
do
	# Find partition numbers
	edit_partitions=$(fdisk -l | grep ^/dev/$selected_drive | cut -c9)
	
	# Parse out extra partitons
	if [ "$partitions" == "1" ]
	then
		work_partition=$(echo -e $edit_partitions | cut -c$partitions)
		# Write to partition_table file
		echo -e "d\n$work_partition" >> partition_table
	else
		if [ "$partitions_cut" == "" ]
		then
			# If First Partition after partition 1, cut off $partitions + 1
			partitions_cut=$(($partitions+1))
		else
			partitions_cut=$(($partitions_cut+1))
		fi
		work_partition=$(echo -e $edit_partitions | cut -c$partitions_cut)
		# Write to partition_table file
		echo -e "d\n$work_partition" >> partition_table
		((partitions_cut += 1))
	fi
	((partitions += 1))
	
done

# build the rest of the table
# Get Total System Memory
total_mem=$(cat /proc/meminfo | grep -i memtotal | cut -c16- | sed s/\ // | sed s/kB//)
swap_space=$(expr $(expr $total_mem + $total_mem) / 1024)

# Write first partition to file
echo -e "n\np\n1\n\n+100M\n" >> partition_table

# Write Swap Space (double system memory)
echo -e "n\np\n2\n\n+"$swap_space"M\n">> partition_table

# Write / partition to file
echo -e "n\np\n3\n\n\n" >> partition_table

# Write partition setting to file and drive write
echo -e "a\n1\nt\n2\n82\nw\n" >> partition_table

# Set drive number variables
boot_drive=$(echo $selected_drive"1")
swap_drive=$(echo $selected_drive"2")
root_drive=$(echo $selected_drive"3")

# KEEP THIS COMMENTED OUT BELLOW HERE
fdisk /dev/$selected_drive < partition_table

# Format Drives
mkfs.ext4 /dev/$boot_drive && mkfs.ext4 /dev/$root_drive
# Make Swap Space
mkswap /dev/$swap_drive

# mount drive
mount /dev/$root_drive /mnt/gentoo

# Make boot folder
mkdir /mnt/gentoo/boot

# Mount boot partition
mount /dev/$boot_drive /mnt/gentoo/boot

# Start swap space
swapon /dev/$swap_drive

# Check architecture type
# Adding quick support for x86_64
if [ "$system_archetecture" == "x86_64" ]
then
	selected_arch="x86_64"
	selected_keyword="x86_64"
else
	selected_keyword="x86"
fi
if [ "$system_architecture" == "i486" ]
then
	selected_arch="i486"
elif [ "$system_architecture" == "i686" ]
then
	selected_arch="i686"
elif [ "$system_architecture" == "" ] 
then
	echo "No architecture selected, defaulting to i486"
	selected_arch="i686"
else
	echo -e "You selected an incorrect architecture, using x86"
	selected_arch="i686"
fi

# Download base files
cd /mnt/gentoo
wget http://mirror.datapipe.net/gentoo/releases/x86/autobuilds/20091117/stage3-$selected_arch-20091117.tar.bz2
stage3_file=$(ls *.bz2)
tar xjpf $stage3_file

make_conf_cflag="-O2 -march=$selected_arch -pipe -fomit-frame-pointer"
make_conf_cxxflag="\${CFLAGS)"
make_conf_keyword="$selected_keyword"
make_conf_features="sandbox nostrip fixpackages parallel-fetch"
make_conf_overlay="/usr/local/portage"

if [ "$install_x" -eq 1 ]
then
	make_conf_use="X a52 aac aalib alsa bidi cdr cleartype consolekit cuda directfb dvd dvdr emerald esd ffmpeg flac glitz gnome gtk id3tag java5 java6 jpeg kde libsamplerate mmx mp3 mp4 msn musepack opengl png qt3support qt4 samba schroedinger sdl sdl-image shine speex sse sse2 sse3 sse4 svg symlink theora thunar tk truetype twolame win32codecs wma-fixed x264 xcb xinerama xvid"
else
	make_conf_use="a52 aac aalib alsa bidi cdr cleartype consolekit cuda directfb dvd dvdr esd ffmpeg flac id3tag java5 java6 jpeg libsamplerate mmx mp3 mp4 msn musepack png samba schroedinger sdl sdl-image shine speex svg symlink theora thunar tk truetype twolame win32codecs wma-fixed x264 xcb xvid"
fi

# Set core build optimization
proc_num=$(($(grep -c processor /proc/cpuinfo) + 1))
make_conf_makeopts="-j$proc_num"

# Get CHOST value
if [ "$selected_arch" == "i486" ]
then
	make_conf_chost="i486-pc-linux-gnu"
elif [ "$selected_arch" == "i686" ]
then
	make_conf_chost="i686-pc-linux-gnu"
elif [ "$selected_arch" == "x86_64" ]
then
	make_conf_arch="x86_64-pc-linux-gnu"
else
	echo "something broke"
fi

echo "CFLAGS=\"$make_conf_cflag\"" > make_conf
echo "CXXFLAGS=\"$make_conf_cxxflag\"" >> make_conf
echo "ACCEPT_KEYWORDS=\"$make_conf_keyword\"" >> make_conf
echo "FEATURES=\"$make_conf_features\"" >> make_conf
echo "MAKEOPTS=\"$make_conf_makeopts\"" >> make_conf
echo "PORTDIR_OVERLAY=\"$make_conf_overlay\"" >> make_conf
echo "CHOST=\"$make_conf_chost\"" >> make_conf
echo "USE=\"$make_conf_use\"" >> make_conf

echo "SYNC=\"rsync://$rsync_ip/gentoo-portage\"" >> make_conf

cat make_conf > /mnt/gentoo/etc/make.conf
# Copy resolv.conf
cp /etc/resolv.conf /mnt/gentoo/etc/resolv.conf

# mount /dev/ and /proc
mount -o bind /dev/ /mnt/gentoo/dev/
mount -t proc none /mnt/gentoo/proc

# Create PORTDIR_OVERLAY
mkdir -p /mnt/gentoo/$make_conf_overlay

# Check for nVidia card
if [ $(lspci | grep -ic nvidia) -gt 0 ]
then
	echo -e "VIDEO_CARD=\"nv nvidia\"" >> /mnt/gentoo/etc/make.conf
	nv_card="1"
else
	echo "No nvidia card"
fi

# Move to drive root
cd /mnt/gentoo

# Create secondary steps to install
echo -e "emerge --sync\nemerge eix ufed dhcpcd ntp genkernel grub\nemerge gentoo-sources\neix-update\ngenkernel all\n" >> part2.sh

# Add EXT4 support to kernel
# Create EXT4 patch

echo -e "CONFIG_EXT4_FS=y\n# CONFIG_EXT4DEV_COMPAT is not set\nCONFIG_EXT4_FS_XATTR=y\n# CONFIG_EXT4_FS_POSIX_ACL is not set\n# CONFIG_EXT4_FS_SECURITY is not set\n" > /mnt/gentoo/EXT4.patch
#echo -e "CONFIG_EXT4_FS=y\nCONFIG_EXT4_FS_XATTR=y\n" > /mnt/gentoo/EXT4.patch
echo -e "cd /usr/src/linux\ncat /EXT4.patch >> .config\nmake && make modules modules_install install\ncd /boot && rm -f *.old" >> part2.sh

chmod +x part2.sh

# Assuming using first disk for MBR
echo -e "root (hd0,0)\n\nsetup (hd0)\n\nquit\n\n" > grub.setup
echo -e "grub < /grub.setup\n" >> part2.sh

# Update base first
echo -e "emerge -Du world\n" >> part2.sh

# If asked for install_x = 1 then run this
if [ "$install_x" -eq 1 ]
then
	if [ "$nv_card" -ge 1 ]
	then
		echo -e "emerge nvidia-drivers" >> part2.sh
	fi
	# Install XFCE4
	echo -e "USE=\"-sdl\" emerge xfce4-meta" >> part2.sh
else
	echo "Skipping GUI install"
fi

# Setup boot options
echo -e "rc-update add ntp-client default\nrc-update add net.eth0 default\n" >> part2.sh

# Update the system on more time before reboot
echo -e "emerge -DuN world" >> part2.sh

# Create grub file
echo -e "kernel_ver=\$(ls /boot/ | grep -m1 vmlinuz)\necho \"timeout 30\ndefault 0\n\ntitle Gentoo Linux\nroot (hd0,0)\nkernel /\$kernel_ver root=/dev/$root_drive\" > /boot/grub/grub.conf" >> part2.sh

# Create /etc/fstab
echo -e "/dev/$boot_drive	/boot		ext4		noatime		1 2" > /mnt/gentoo/etc/fstab
echo -e "/dev/$root_drive	/		ext4		noatime		0 1" >> /mnt/gentoo/etc/fstab
echo -e "/dev/$swap_drive	none		swap		sw		0 0" >> /mnt/gentoo/etc/fstab
echo -e "/dev/cdrom		/mnt/cdrom	auto		noauto,ro	0 0" >> /mnt/gentoo/etc/fstab
echo -e "shm			/dev/shm	tmpfs		nodev,nosuid,noexec	0 0" >> /mnt/gentoo/etc/fstab

# Set Root password
echo -e "echo \"Please enter your root password\"\npasswd" >> part2.sh


# Chroot and run installer
echo -e "Chrooting into almost completed installation\n"
chroot /mnt/gentoo /bin/bash part2.sh
