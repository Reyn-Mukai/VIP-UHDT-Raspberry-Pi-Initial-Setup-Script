if [ $(id -u) -ne 0 ]; then
echo "Error: Script must be run as root."
exit 1
fi

echo "Updating system..."
apt-get -y update
echo "Upgrading packages... This may take a while..."
apt-get -y upgrade

echo "Installing vim..."
apt-get -y install vim
echo "Purging built in VNC server..."
apt-get -y purge realvnc-server
echo "Installing VNC server..."
apt-get -y install tightvncserver
echo "Installing RDP server..."
apt-get -y install xrdp
echo "Enabling RDP server on startup..."
systemctl enable xrdp
echo "Installing CRC32..."
apt-get -y install libarchive-zip-perl
echo "Installing rpl..."
apt-get -y install rpl

echo "Installing Openssl..."
apt-get -y install openssl
echo "Creating SSL certificate directory..."
cd /home/pi
mkdir ssl
cd /home/pi/ssl
echo "Generating self-signed SSL certificated..."
openssl req -new -newkey rsa:4096 -days 730 -nodes -x509 -sha256 -subj "/C=US/ST=/L=/O=/CN=/" -keyout server.key -out server.crt

echo "Installing FTP server..."
apt-get -y install proftpd
if ! grep -q "#Certificates installed to /home/pi/ssl"
then
  echo "Installing SSL certificate..."
  echo '#Certificates installed to /home/pi/ssl' >> /etc/proftpd/proftpd.conf
  echo 'PassivePorts                 49152 65534' >> /etc/proftpd/proftpd.conf
  echo 'Include                      /etc/proftpd/tls.conf' >> /etc/proftpd/proftpd.conf
  echo 'TLSEngine                    on' >> /etc/proftpd/tls.conf
  echo 'TLSLog                       /var/log/proftpd/tls.log' >> /etc/proftpd/tls.conf
  echo 'TLSProtocol                  SSLv23' >> /etc/proftpd/tls.conf
  echo 'TLSRequired                  on' >> /etc/proftpd/tls.conf
  echo 'TLSRSACertificateFile        /home/pi/ssl/server.crt' >> /etc/proftpd/tls.conf
  echo 'TLSRSACertificateKeyFile     /home/pi/ssl/server.key' >> /etc/proftpd/tls.conf
else
  echo "Warning: FTP server already configured... Skipping..."
fi
  
echo "Creating image directory..."
cd /home/pi
mkdir images
chmod -R 777 images

echo "Installing Apache2 2.4 webserver..."
apt-get -y install apache2
if ! grep -q "#IncludeOptional sites-enabled/*.conf" /etc/apache2/apache2.conf
then
  rpl -w "IncludeOptional sites-enabled/*.conf" "#IncludeOptional sites-enabled/*.conf" /etc/apache2/apache2.conf
fi
if ! grep -q "#Image Folder" /etc/apache2/apache2.conf
then
  echo "Configuring Apache2 virtual hosts..."
  echo '#Image Folder' >> /etc/apachee2/apache2.conf
  echo '<VirtualHost *:80>' >> /etc/apache2/apache2.conf
  echo '<IfModule mod_rewrite.c>' >> /etc/apache2/apache2.conf
  echo '<IfModule mod_ssl.c>' >> /etc/apache2/apache2.conf
  echo '<Location/>' >> /etc/apache2/apache2.conf
  echo 'RewriteEngine on' >> /etc/apache2/apache2.conf
  echo 'RewriteCond %{HTTPS} !^on$ [NC]' >> /etc/apache2/apache2.conf
  echo 'RewriteRule . https://%{HTTP_HOST}%{REQUEST_URI} [L]' >> /etc/apache2/apache2.conf
  echo '</Location>' >> /etc/apache2/apache2.conf
  echo '</IfModule>' >> /etc/apache2/apache2.conf
  echo '</IfModule>' >> /etc/apache2/apache2.conf
  echo '</VirtualHost>' >> /etc/apache2/apache2.conf
  echo '<VirtualHost *:443>' >> /etc/apache2/apache2.conf
  echo 'DocumentRoot /home/pi/images' >> /etc/apache2/apache2.conf
  echo '<Directory "/home/pi/images">' >> /etc/apache2/apache2.conf
  echo 'allow from all' >> /etc/apache2/apache2.conf
  echo 'Options FollowSymLinks Indexes MultiViews SymLinksIfOwnerMatch' >> /etc/apache2/apache2.conf
  echo 'Require all granted' >> /etc/apache2/apache2.conf
  echo 'AllowOverride All' >> /etc/apache2/apache2.conf
  echo '</Directory>' >> /etc/apache2/apache2.conf
  echo 'ServerPath /home/pi/images' >> /etc/apache2/apache2.conf
  echo 'SSLEngine on' >> /etc/apache2/apache2.conf
  echo 'SSLCertificateFile /home/pi/ssl/server.crt' >> /etc/apache2/apache2.conf
  echo 'SSLCertificateKeyFile /home/pi/ssl/server.key' >> /etc/apache2/apache2.conf
  echo 'SSLCompression off' >> /etc/apache2/apache2.conf
  echo 'SSLProtocol All -SSLv2 -SSLv3' >> /etc/apache2/apache2.conf
  echo '</VirtualHost>' >> /etc/apache2/apache2.conf
else
  echo "Warning: VirtualHost already configured... Skipping..."
fi

echo "Installing Samba network sharing server..."
apt-get -y install samba
if ! grep -q "[VIP_UHDT_RapsberryPi]" /etc/samba/smb.conf
then
  echo "Configuring shared folder..."
  echo '[VIP_UHDT_RaspberryPi]' >> /etc/samba/smb.conf
  echo 'path=/home/pi/images' >> /etc/samba/smb.conf
  echo 'browseable=yes' >> /etc/samba/smb.conf
  echo 'writeable=yes' >> /etc/samba/smb.conf
  echo 'only guest=no' >> /etc/samba/smb.conf
  echo 'create mask=0777' >> /etc/samba/smb.conf
  echo 'directory mask=0777' >> /etc/samba/smb.conf
  echo 'public=no' >> /etc/samba/smb.conf
  echo "Creating user pi..."
  smbpasswd -a pi
else
  echo "Warning: SMB share already configured... Skipping..."
fi

echo "Enabling Apache2 SSL and rewrite modules..."
a2enmod ssl
a2enmod rewrite

echo "Restarting reconfigured services..."
systemctl restart proftpd
systemctl restart apache2

echo "Installation complete"
