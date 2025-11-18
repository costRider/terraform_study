 #!/bin/bash
 yum -y install httpd
 sed -i 's/Listen 80/Listen ${var.server_port}/' /etc/httpd/conf/httpd.conf
 systemctl enable httpd
 systemctl start httpd
 echo '<html><h1>Hello From My Linux Web Server! ${var.server_port} </h1></html>' > /var/www/html/index.html