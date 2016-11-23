from fedora:24
# author: Pavel Studenik <pstudeni@redhat.com>

RUN URL_SW=http://yum.spacewalkproject.org/2.6/Fedora/24/x86_64/ && \
rpm -Uvh $URL_SW/$( curl --silent $URL_SW | grep spacewalk-repo-[0-9] |  grep -Po '(?<=href=")[^"]*' )

ADD jpackage-generic.repo /etc/yum.repos.d/jpackage-generic.repo

RUN dnf install -y spacewalk-setup-postgresql spacewalk-setup tomcat perl-DBD-Pg \
                   spacewalk-taskomatic spacewalk-common && \
    dnf clean all

ADD answer.txt /root/answer.txt
ADD bin/docker-spacewalk-setup.sh /root/docker-spacewalk-setup.sh
ADD bin/docker-spacewalk-run.sh /root/docker-spacewalk-run.sh

RUN chmod a+x /root/docker-spacewalk-{run,setup}.sh

EXPOSE 80 443 5222 69

CMD /root/docker-spacewalk-run.sh

