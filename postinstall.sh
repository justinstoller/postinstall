## Install RubyGems
## usage install_rubygems 1.8.11
#install_rubygems() {
#  version=shift
#  gem="rubygems-${version}"
#  tar="$gem.tgz"
#  wget "http://production.cf.rubygems.org/rubygems/${tar}"
#  tar xzf $tar
#  pushd $gem
#    /opt/ruby/bin/ruby setup.rb
#  popd
#  rm -rf $gem
#}
## Install Ruby from source in /opt so that users of Vagrant
## can install their own Rubies using packages or however.
## usage: install_ruby 1.9.3-p392 #patchset required
#install_ruby() {
#  version=shift
#  ruby="ruby-${version}"
#  tar="${ruby}.tar.gz"
#  major_minor=`echo $version | cut -f1,2 -d.`
#  wget "http://ftp.ruby-lang.org/pub/ruby/${major_minor}/${tar}"
#  tar xzf "${tar}"
#  pushd $ruby
#    ./configure --prefix=/opt/ruby
#    make
#    make install
#  popd
#  rm -rf $ruby
#}

# Installing vagrant keys
# usage: install_vagrant_key_for vagrant
install_vagrant_key_for() {
  pushd "/home/$1"
    mkdir -p .ssh
    pushd .ssh
      wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O authorized_keys
      chmod 600 authorized_keys
    popd
    chown -R $1 .ssh
    chmod 700 .ssh
  popd
}

# usage create_admin_user vagrant
create_admin_user() {
  useradd $1
  usermod -a -G admin $1
  # Setup sudo to allow no-password sudo for "admin"
  cp /etc/sudoers /etc/sudoers.orig
  sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=admin' /etc/sudoers
  sed -i -e 's/%admin ALL=(ALL) ALL/%admin ALL=NOPASSWD:ALL/g' /etc/sudoers
}

install_ruby_build() {
  pushd /opt/src
    git clone git://github.com/sstephenson/ruby-build.git
    pushd ruby-build
      sudo ./install.sh
    popd
  popd
}

install_chruby() {
  pushd /opt/src
    wget -O chruby-0.3.4.tar.gz https://github.com/postmodern/chruby/archive/v0.3.4.tar.gz
    tar -xzvf chruby-0.3.4.tar.gz
    pushd chruby-0.3.4
      make install
    popd
  popd
}

# Removing leftover leases and persistent rules
# http://6.ptmc.org/?p=164
# Adding a 2 sec delay to the interface up, to make the dhclient happy
setup_network_settings() {
  rm /var/lib/dhcp3/*
  rm /etc/udev/rules.d/70-persistent-net.rules
  mkdir /etc/udev/rules.d/70-persistent-net.rules
  rm -rf /dev/.udev/
  rm /lib/udev/rules.d/75-persistent-net-generator.rules
  echo "pre-up sleep 2" >> /etc/network/interfaces
}

# Zero out the free space to save space in the final image:
clear_free_space() {
  dd if=/dev/zero of=/EMPTY bs=1M
  rm -f /EMPTY
}

date > /etc/vagrant_build

INSTALL_PACKAGES=(linux-headers-$(uname -r) build-essential install \
                  zlib1g-dev libssl-dev libreadline6-dev libnurses5-dev \
                  curl bison automake autoconf git-core libc6-dev libtool \
                  libyaml-dev openssl pkg-config libsqlite3-dev vim nfs-common)

apt-get -y update
apt-get -y upgrade
apt-get -y install $INSTALL_PACKAGES
apt-get clean

groupadd -r admin

create_admin_user vagrant

mkdir -p /opt/src
mkdir -p /opt/rubies

install_ruby_build
install_chruby

ruby-build 1.9.3-p392 /opt/rubies/1.9.3-p392

for VUSER in root vagrant
do
  install_vagrant_key_for $VUSER
done

clear_free_space

setup_network_settings
