#!/bin/bash

apt update -y
apt install -y apache2

sed -i "s/Listen 80/Listen ${server_port}/" /etc/apache2/ports.conf

systemctl enable apache2
systemctl restart apache2

echo '<html><h1>Hello From Your Ubuntu Web Server running on port ${server_port}! </h1></html>' > /var/www/html/index.html

