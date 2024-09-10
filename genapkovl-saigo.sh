#!/bin/sh -e

HOSTNAME="xpine"

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup exit

mkdir -p "$tmp"/etc
mkdir -p "$tmp"/etc/apk
mkdir -p "$tmp"/etc/network
mkdir -p "$tmp"/root

makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

# makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
# agetty
# aisleriot
# alpine-base
# alsa-utils
# alsaconf
# dbus-x11
# eudev
# font-noto
# gnome-mines
# mesa-dri-gallium
# network-manager-applet
# networkmanager
# networkmanager-wifi
# pavucontrol
# picom
# pulseaudio
# pulseaudio-alsa
# pulseaudio-bluez
# pulseaudio-utils
# vim
# vlc-qt
# xf86-input-evdev
# xf86-input-libinput
# xf86-input-synaptics
# xf86-input-vmmouse
# xf86-video-fbdev
# xf86-video-intel
# xf86-video-nouveau
# xf86-video-vesa
# xfce4
# xorg-server
# EOF

makefile root:root 0755 "$tmp"/etc/inittab <<EOF
# /etc/inittab

::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

tty1::respawn:/sbin/agetty 38400 tty1 --autologin root --noclear
tty2::respawn:/sbin/getty 38400 tty2

::shutdown:/sbin/openrc shutdown

ttyS0::respawn:/sbin/getty -L 0 ttyS0 vt100
EOF

makefile root:root 0755 "$tmp"/etc/.xinitrc <<EOF
pulseaudio --daemon --system &
feh --bg-fill /etc/wallpaper.png &
picom -c &
tint2 &
exec openbox-session
EOF

makefile root:root 0755 "$tmp"/etc/.profile <<EOF
#!/bin/sh -e

setup-devd -C mdev
setup-xorg-base
setup-desktop xfce
EOF

makefile root:root 0755 "$tmp"/etc/setup-script <<EOF
INTERFACESOPTS="auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    hostname saigo
"

KEYMAPOPTS="us us"
HOSTNAMEOPTS="-n xpine"
DNSOPTS="8.8.8.8"
TIMEZONEOPTS="-z UTC"
PROXYOPTS="none"
APKREPOSOPTS="-1"
SSHDOPTS="-c openssh"
NTPOPTS="-c openntpd"
DISKOPTS="-m sys /dev/vda"
EOF

makefile root:root 0755 "$tmp"/etc/setup.sh <<EOF
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

mv /etc/setup-alpine /sbin/setup-alpine
chmod +x /sbin/setup-alpine
cp /etc/.xinitrc /root/
cp /etc/.profile /root/
/root/.profile
EOF

makefile root:root 0644 "$tmp"/etc/motd <<EOF
Welcome to xpine
EOF

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot

rc_add udev boot

rc_add acpid default
rc_add alsa default
rc_add chronyd default
rc_add crond default
rc_add dbus default
rc_add lightdm default
rc_add networkmanager default
rc_add sshd default
rc_add udev-postmount default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > $HOSTNAME.apkovl.tar.gz
