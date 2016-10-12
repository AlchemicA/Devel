#!/usr/bin/env bash

# Install PPAs
# --------------------
apt-get install -y language-pack-en-base
LC_ALL=en_US.UTF-8 
add-apt-repository ppa:ondrej/php

# Update Apt
# --------------------
apt-get update

# Install Apache & PHP
# --------------------
apt-get install -y apache2
apt-get install -y php7.0
apt-get install -y libapache2-mod-php7.0
apt-get install -y php7.0-mysql php7.0-curl php-xdebug php7.0-gd php7.0-imap php7.0-mbstring php7.0-mcrypt php7.0-sqlite php7.0-xmlrpc php7.0-xsl php7.0-zip php-soap php-xdebug

php7.0enmod mcrypt

# Delete default apache web dir and symlink mounted vagrant dir from host machine
# --------------------
rm -rf /var/www/html
mkdir /vagrant/httpdocs
ln -fs /vagrant/httpdocs /var/www/html

# Replace contents of default Apache vhost
# --------------------
VHOST=$(cat <<EOF
NameVirtualHost *:8080
Listen 8080
<VirtualHost *:80>
  DocumentRoot "/var/www/html"
  ServerName localhost
  <Directory "/var/www/html">
    AllowOverride All
  </Directory>
</VirtualHost>
<VirtualHost *:8080>
  DocumentRoot "/var/www/html"
  ServerName localhost
  <Directory "/var/www/html">
    AllowOverride All
  </Directory>
</VirtualHost>
EOF
)

echo "$VHOST" > /etc/apache2/sites-enabled/000-default.conf

# Set groups
usermod -a -G www-data vagrant
usermod -a -G vagrant www-data

# XDebug
if [[ -f "/etc/php/mods-available/xdebug.ini" ]]; then
  echo 'xdebug.default_enable=1' >> /etc/php/mods-available/xdebug.ini
  echo 'xdebug.idekey="vagrant"' >> /etc/php/mods-available/xdebug.ini
  echo 'xdebug.remote_enable=1' >> /etc/php/mods-available/xdebug.ini
  echo 'xdebug.remote_autostart=0' >> /etc/php/mods-available/xdebug.ini
  echo 'xdebug.remote_port=9000' >> /etc/php/mods-available/xdebug.ini
  echo 'xdebug.remote_handler=dbgp' >> /etc/php/mods-available/xdebug.ini
  echo 'xdebug.remote_log="/tmp/xdebug.log"' >> /etc/php/mods-available/xdebug.ini
  echo 'xdebug.remote_host=10.0.2.2' >> /etc/php/mods-available/xdebug.ini
fi

a2enmod rewrite
service apache2 restart

# MySQL
# --------------------
# Ignore the post install questions
export DEBIAN_FRONTEND=noninteractive
# Install MySQL quietly
apt-get -q -y install mysql-server-5.6
#apt-get -q -y install mysql-client-5.6

mysql -u root -e "CREATE DATABASE IF NOT EXISTS drupal"
mysql -u root -e "GRANT ALL PRIVILEGES ON drupal.* TO 'user'@'localhost' IDENTIFIED BY 'password'"
mysql -u root -e "FLUSH PRIVILEGES"

# Clean-up
apt-get -q -y autoremove

# Drupal
# --------------------

# Composer
apt-get -q -y install git
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
# Drush 8.x
mkdir -p /usr/share/php/drush-8
cd /usr/share/php/drush-8
composer require drush/drush:8.*
#ln -s /usr/share/php/drush-8/vendor/bin/drush /usr/local/bin/drush
ln -s /usr/share/php/drush-8/vendor/drush/drush/drush /usr/local/bin/drush

# Download and extract
if [[ ! -f "/vagrant/httpdocs/index.php" ]]; then
  cd /vagrant/httpdocs
  #wget https://ftp.drupal.org/files/projects/drupal-8.2.1.tar.gz
  #tar -zxvf drupal-8.2.1.tar.gz
  drush dl drupal -y --drupal-project-rename=drupal-latest
  mv drupal-latest/* drupal-latest/.htaccess .
  # Clean up downloaded file and extracted dir
  rm -rf drupal-latest*
  drush site-install minimal -y --db-url='mysql://user:password@localhost/drupal' --site-name=Vagrant --account-name=admin --account-pass=password
fi

