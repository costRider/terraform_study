#!/bin/bash
apt update -y
apt install -y apache2

systemctl enable apache2
systemctl start apache2

echo '<html><h1>Hello From My Ubuntu Web Server!</h1></html>' > /var/www/html/index.html
