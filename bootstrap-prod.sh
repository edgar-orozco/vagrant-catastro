#!/usr/bin/env bash

# Aprovisionador para CentOS 7. Ambiente de producción.

# Actualizar repo de paquetes
# Configurar idioma de sistema
# Instalar y configurar git, curl, wget, vim
# Instalar apache mod_rewrite y configurar FQDN.
# Instalar php
# Instalar postgres y postgres contrib, configurar usuario postgres y base
# Instalar ntpd
# Deshabilitar firewall
# Instalar composer
# Instalar laravel


# 1. Actualizacion y Creacion de cache de repos de paquetes
sudo yum makecache fast

# 2. Configurando idioma y encoding
sudo localedef -v -c -i es_MX -f UTF-8 es_MX.UTF-8
sudo localectl set-locale LANG=es_MX.UTF-8
sudo localectl set-keymap es

# Configurando hostname
sudo hostnamectl set-hostname catastro-prod

# 3. Instalar git curl y wget
sudo yum install -y git curl wget vim

# 4. Instalando apache
sudo yum install -y httpd
sudo systemctl enable httpd.service

# 5 Instalando PHP
sudo yum install -y php php-pgsql php-gd php-pear php-curl php-memcached php-mhash php-xmlrpc php-xsl php-intl php-mbstring

# mCrypt no existe en repos oficiales CentOS 7 por alguna insólita y estúpida razón... vamos a instalarlo desde el repo epel
cd /tmp/ && wget ftp://ftp.sunet.se/pub/Linux/distributions/fedora/epel/7/x86_64/epel-release-7-1.noarch.rpm
sudo yum -y install epel-release-7-1.noarch.rpm
sudo yum -y install php-mcrypt*

# Deshabilitando firewall
sudo systemctl mask firewalld

# Deshabilitamos selinux (que chille Dan Walsh, ya está grandecito como para afrontar las consecuencias de sus actos)
cat > /etc/selinux/config <<FiNSel
SELINUX=permissive
SELINUXTYPE=targeted
FiNSel

# Instalando memcached
sudo yum install -y memcached

# Instalando postgresql
sudo yum install -y http://yum.postgresql.org/9.3/redhat/rhel-7-x86_64/pgdg-centos93-9.3-1.noarch.rpm
sudo yum install -y postgresql93
sudo yum install -y postgresql93-libs
sudo yum install -y postgresql93-devel
sudo yum install -y postgresql93-server
sudo yum install -y postgresql93-contrib

# Inicializando espacio de datos
su - postgres -c /usr/pgsql-9.3/bin/initdb

# Configurando permisos de acceso de desarrollo local
cat > /var/lib/pgsql/9.3/data/pg_hba.conf <<FiN
# Database administrative login by Unix domain socket
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all             postgres                                trust
# IPv4 local connections:
host    all             postgres             127.0.0.1/32       trust
# IPv6 local connections:
host    all             postgres             ::1/128            trust
FiN

# Configurando las direcciones de escucha de postgres local
sed -i -e "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/9.3/data/postgresql.conf

# Inscribiendo el script de autoinicio en boot del postgres
chkconfig postgresql-9.3 on

# Levantamos postgres
service postgresql-9.3 start

# Creando la base de catastro
createdb catastro -U postgres

# Instalando el cliente del protocolo NTP
yum install -y ntp

# Configurando el timezone del servidor local al tiempo central
yes | cp -f /usr/share/zoneinfo/Mexico/General /etc/localtime

# Instalando COMPOSER
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/bin/composer

# Instalando LARAVEL
#composer create-project laravel/laravel /var/www/html --prefer-dist
# Como ya existe el proyecto en github ahora se clona:
git clone https://github.com/edgar-orozco/catastro.git /var/www/html
cd /var/www/html
composer install

# Cambiando permisos para storage
chown apache.apache /var/www/html/app/storage -R
chmod 775 /var/www/html/app/storage -R
# Se cambian permisos para carpeta web donde se escriben algunos archivos
chown apache.apache /var/www/html/public/css/images/logos -R
chmod 755 /var/www/html/public/css/images/logos -R
#se cambian permisos para directorio de datos complementarios
chown apache.apache /var/www/html/public/complementarios/anexos -R
chmod 755 /var/www/html/public/complementarios/anexos -R
#se cambian permisos para directorio de documentos requisitos en tramites
chown apache.apache /var/www/html/public/documentos -R
chmod 755 /var/www/html/public/documentos -R
#se cambian permisos para directorio de documentos de predios valuados (corevat)
chown apache.apache /var/www/html/public/corevat -R
chmod 755 /var/www/html/public/corevat -R
#se cambian permisos para directorio de imágenes de código de barras
chown apache.apache /var/www/html/public/barcodes -R
chmod 755 /var/www/html/public/barcodes -R


# Configurando apache
cat > /etc/httpd/conf/httpd.conf <<FINApache
ServerRoot "/etc/httpd"
Listen 80
Include conf.modules.d/*.conf

User apache
Group apache

ServerAdmin root@localhost

<Directory />
    AllowOverride none
    Require all denied
</Directory>

DocumentRoot "/var/www/html/public"

<Directory "/var/www/html/public">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

<IfModule dir_module>
    DirectoryIndex index.html
</IfModule>

<Files ".ht*">
    Require all denied
</Files>

ErrorLog "logs/error_log"

LogLevel warn

<IfModule log_config_module>
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %b" common

    <IfModule logio_module>
      LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %I %O" combinedio
    </IfModule>
    CustomLog "logs/access_log" combined
</IfModule>

<IfModule mime_module>
    TypesConfig /etc/mime.types

    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz
    AddType text/html .shtml
    AddOutputFilter INCLUDES .shtml
</IfModule>

AddDefaultCharset UTF-8

<IfModule mime_magic_module>
    MIMEMagicFile conf/magic
</IfModule>

EnableSendfile off

IncludeOptional conf.d/*.conf
FINApache

# Requerimientos paqs geograficos
yum install -y gdal
sudo yum install -y postgis2_93*

# Tenemos que tener los paquetes geograficos en el tmp
cd /tmp
tar xvzf mapserver.tgz
yum install -y mapserver-6.2.1-5.el7.centos.x86_64.rpm mapserver-debuginfo-6.2.1-5.el7.centos.x86_64.rpm mapserver-perl-6.2.1-5.el7.centos.x86_64.rpm mapserver-python-6.2.1-5.el7.centos.x86_64.rpm
yum install -y php-mapserver-6.2.1-5.el7.centos.x86_64.rpm

# Finalmente cargamos la base seed si es que existe el dump en el tmp
psql catastro -U postgres -f /tmp/dump.sql

# Reboot para que se refresquen cambios de hostname y demás
reboot

echo "###################################################";
echo "#################### FIN ##########################";
echo "###################################################";
