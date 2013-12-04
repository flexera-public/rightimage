#!/bin/bash -ex


# EC2 API Tools are Java based
# EC2 AMI Tools are Ruby based
echo "Installing openjdk ruby curl unzip"
case "$PLATFORM" in
ubuntu*)
  apt-get install -y openjdk-6-jre-headless ruby curl unzip
  echo "export JAVA_HOME=/usr/lib/jvm/java-6-openjdk-amd64/jre" > /etc/profile.d/java.sh
  chmod a+x /etc/profile.d/java.sh
  ;;
centos*|rhel*|redhat*)
  yum install -y java-1.6.0-openjdk ruby curl unzip
  echo "export JAVA_HOME=/etc/alternatives/jre" > /etc/profile.d/java.sh
  chmod a+x /etc/profile.d/java.sh
  ;;
*)
  echo "ERROR: PLATFORM is not set"
  exit 1
esac
source /etc/profile.d/java.sh

rm -rf /home/ec2  || true
mkdir -p /home/ec2
curl_opts="-s -S -f -L --retry 5"
if [ ! -f /tmp/ec2-api-tools.zip ]; then
  curl $curl_opts -o /tmp/ec2-api-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-api-tools-1.6.12.0.zip
fi
if [ ! -f /tmp/ec2-ami-tools.zip ]; then
  curl $curl_opts -o /tmp/ec2-ami-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools-1.4.0.9.zip
fi
unzip -o -q /tmp/ec2-api-tools.zip -d /tmp/
unzip -o -q /tmp/ec2-ami-tools.zip -d /tmp/
cp -r /tmp/ec2-api-tools-*/* /home/ec2/.
rsync -a /tmp/ec2-ami-tools-*/ /home/ec2
rm -r /tmp/ec2-a*
echo 'export PATH=/home/ec2/bin:${PATH}' > /etc/profile.d/ec2.sh
echo 'export EC2_HOME=/home/ec2' >> /etc/profile.d/ec2.sh
chmod a+x /etc/profile.d/ec2.sh