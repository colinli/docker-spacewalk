FROM centos:7
MAINTAINER Pavel Studenik <pstudeni@redhat.com>

RUN rpm --import https://copr-be.cloud.fedoraproject.org/results/%40spacewalkproject/spacewalk-2.8/pubkey.gpg && \ 
    rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 && \
    rpm --import /etc/pki/rpm-gpg/* && \
    rpm -Uvh https://copr-be.cloud.fedoraproject.org/results/%40spacewalkproject/spacewalk-2.8/epel-7-x86_64/00736372-spacewalk-repo/spacewalk-repo-2.8-11.el7.centos.noarch.rpm && \
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    cat /etc/yum.repos.d/*.repo && \
    #yum update -y && \
    yum install yum-utils -y && yum-config-manager repo --enable epel-testing && \
    yum install -y spacewalk-postgresql syslinux  spacewalk-taskomatic spacewalk-common && \
    #yum clean all
    pwd

ADD answer.txt /root/answer.txt
ADD bin/docker-spacewalk-setup.sh /root/docker-spacewalk-setup.sh
ADD bin/docker-spacewalk-run.sh /root/docker-spacewalk-run.sh
ADD bin/spacewalk-hostname-rename.sh /root/spacewalk-hostname-rename.sh

RUN mkdir -p /etc/httpd/conf/ssl.crt /etc/httpd/conf/ssl.key && \
    cp /etc/pki/tls/certs/localhost.crt  /etc/httpd/conf/ssl.crt/server.crt && \
    cp /etc/pki/tls/private/localhost.key  /etc/httpd/conf/ssl.key/server.key && \
    chmod a+x /root/docker-spacewalk-{run,setup}.sh

EXPOSE 69 80 443 5222

CMD /root/docker-spacewalk-run.sh

