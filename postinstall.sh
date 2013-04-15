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

home_dir_for() {
  if [[ $1 == root ]]; then
    return "/root";
  else
    return "/home/$1";
  fi
}
setup_ssh_for() {
  pushd `home_dir_for $1`
    mkdir -p .ssh
    pushd .ssh
      touch authorized_keys
      chmod 600 authorized_keys
    popd
    chown -R $1 .ssh
    chmod 700 .ssh
  popd
}

# Installing vagrant keys
# usage: install_vagrant_key_for vagrant
install_vagrant_key_for() {
  pushd "`home_dir_for $1`/.ssh"
    touch authorized_keys
    wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub'
    cat vagrant.pub >> authorized_keys
  popd
}

install_puppetlabs_keys_for() {
  pushd "`home_dir_for $1`/.ssh"
    touch authorized_keys
    wget --no-check-certificat -O 'puppetlabs.pub' 'https://raw.github.com/puppetlabs/puppetlabs-sshkeys/master/templates/ssh/authorized_keys'
    cat puppetlabs.pub >> authorized_keys
  popd
}

# usage create_admin_user vagrant
create_admin_user() {
  if ! [[ $1 == root ]]; then
    useradd $1
  fi
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
    tar -xzf chruby-0.3.4.tar.gz
    pushd chruby-0.3.4
      make install
      ln -s /usr/local/share/chruby/chruby.sh /etc/profile.d/chruby.sh
      source /etc/profile.d/chruby.sh
    popd
  popd
}

# Removing leftover leases and persistent rules
# http://6.ptmc.org/?p=164
# Adding a 2 sec delay to the interface up, to make the dhclient happy
setup_network_settings() {
  rm -rf /var/lib/dhcp3/*
  rm -rf /etc/udev/rules.d/70-persistent-net.rules
  mkdir -p /etc/udev/rules.d/70-persistent-net.rules
  rm -rf /dev/.udev/
  rm -rf /lib/udev/rules.d/75-persistent-net-generator.rules
  echo "pre-up sleep 2" >> /etc/network/interfaces
}

# Zero out the free space to save space in the final image:
clear_free_space() {
  dd if=/dev/zero of=/EMPTY bs=1M
  rm -f /EMPTY
}

date > /etc/vagrant_build

INSTALL_PACKAGES=(linux-headers-$(uname -r) build-essential \
                  zlib1g-dev libssl-dev libreadline6-dev libnurses5-dev \
                  curl bison automake autoconf git-core libc6-dev libtool \
                  libyaml-dev openssl pkg-config libsqlite3-dev vim)

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
ruby-build 2.0.0-p0 /opt/rubies/2.0.0-p0
ruby-build 1.8.7-p371 /opt/rubies/1.8.7-p371

for vUSER in root vagrant
do
  setup_ssh_for $vUSER
  install_vagrant_key_for $vUSER
  install_puppetlabs_keys_for $vUSER
done

clear_free_space

setup_network_settings
