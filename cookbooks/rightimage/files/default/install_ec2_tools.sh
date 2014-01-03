#!/bin/bash -ex


# EC2 API Tools are Python based
# EC2 AMI Tools are Ruby based
case "$PLATFORM" in
ubuntu*)
  apt-get -y install python-dev python-pip wget ruby curl
  ;;
rhel*|redhat*|centos*)
  yum -y install python-pip python-devel python-libs wget ruby curl
  ;;
*)
  echo "ERROR: PLATFORM not set!"
  exit 1
  ;;
esac


if [ -z "$BASE_URL" ]; then
  echo "BASE_URL not set!"
  exit 1
fi


curl_opts="-s -S -f -L --retry 5"
if [ ! -f /tmp/awscli.pybundle ]; then
  curl $curl_opts -o /tmp/awscli.pybundle $BASE_URL/files/awscli-1.2.8.pybundle
fi
pip install /tmp/awscli.pybundle
rm -f /tmp/awscli.pybundle

# Handle ami-tools install
rm -rf /home/ec2  || true
mkdir -p /home/ec2
if [ ! -f /tmp/ec2-ami-tools.zip ]; then
  curl $curl_opts -o /tmp/ec2-ami-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools-1.4.0.9.zip
fi
unzip -o -q /tmp/ec2-ami-tools.zip -d /tmp/
rsync -a /tmp/ec2-ami-tools-*/ /home/ec2
rm -f /tmp/ec2-ami-tools.zip
echo 'export PATH=/home/ec2/bin:${PATH}' > /etc/profile.d/ec2.sh
echo 'export EC2_HOME=/home/ec2' >> /etc/profile.d/ec2.sh
chmod a+x /etc/profile.d/ec2.sh
