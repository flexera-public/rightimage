# Not necessary for a functional vagrant box, though vbox installer will 
# complain
#if [ `lsb_release -is` = "Ubuntu" ]; then
#  apt-get install xserver-xorg xserver-xorg-core -y
#else
#  yum groupinstall "X Window System" -y
#fi
# Installing the virtualbox guest additions
VBOX_VERSION="4.2.12"
file=/tmp/VBoxGuestAdditions.iso
if [ ! -f $file ]; then
  curl -o $file --fail --silent --location http://download.virtualbox.org/virtualbox/$VBOX_VERSION/VBoxGuestAdditions_$VBOX_VERSION.iso
fi

if [ ! -f /mnt/VBoxLinuxAdditions.run ]; then
  [ ! -e /dev/loop1 ] && MAKEDEV loop1
  mount -o loop /tmp/VBoxGuestAdditions.iso /mnt
fi

# See ../../files/default/uname for explanation of uname thing. Need a fake uname
# to fool the installer about which kernel headers to build against
cp /bin/fakeuname /bin/uname
set +e
# Let it error out, if we don't have xwindows installed
sh /mnt/VBoxLinuxAdditions.run

module=$(find /lib/modules/`/bin/fakeuname -r` -name vboxguest.ko | grep "ko")
if [ -z "$module" ]; then
  echo "Virtualbox guest additions kernel module was not built!"
  exit 1
fi
set -e

mv /bin/realuname /bin/uname
rm -rf /bin/fakeuname
sync
umount /mnt
rm -rf /tmp/VBoxGuestAdditions*.iso
