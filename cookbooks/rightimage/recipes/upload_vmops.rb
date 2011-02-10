bash "serve /mnt via http" do
  code do
    set -x
    set -e
    yum -y install httpd
    rm /etc/httpd/conf.d/welcome*
    rm -rf /var/www/html
    ln -s /mnt /var/www/html
    service httpd start
  end
end