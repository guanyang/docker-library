FROM centos:centos7

RUN set -ex && \
    echo "---------- Update yum packages ----------" && \
    yum -y provides '*/applydeltarpm' && \
    yum -y install deltarpm bind-utils hostname openssh-clients telnet wget unzip less which sysstat net-tools iproute fontconfig && \
    echo "---------- add lnmp ----------" && \
    wget http://soft.vpser.net/lnmp/lnmp1.8.tar.gz -cO lnmp1.8.tar.gz && tar zxf lnmp1.8.tar.gz && cd lnmp1.8 && LNMP_Auto="y" DBSelect="4" DB_Root_Password="root" InstallInnodb="y" PHPSelect="10" SelectMalloc="1" ./install.sh lnmp && \
    echo "---------- add profile ----------" && \
    touch /etc/profile.d/custom.sh && \
    echo "alias ll='ls -lrtFh --color=auto'" >> /etc/profile.d/custom.sh && \
    echo "export EDITOR=vim" >> /etc/profile.d/custom.sh && \
    echo "export TERM=xterm-color" >> /etc/profile.d/custom.sh && \
    echo "WHITE=\"\e[1;37m\";GREEN=\"\e[1;32m\";YELLOW=\"\e[1;33m\";BLUE=\"\e[1;36m\";ORANGE_BG=\"\e[1;43m\";END=\"\e[m\";" >> /etc/profile.d/custom.sh && \
    echo "export PS1=\"\n\${WHITE}[container]\${END}\${GREEN}\u\${END}\${YELLOW}@\${END}\${BLUE}\h\${END}:\w\n\\$ \"" >> /etc/profile.d/custom.sh && \
    echo "---------- delete tmp files ----------" && \
    yum clean all && rm -rf /tmp/*

EXPOSE 443 80

WORKDIR "/home/wwwroot"
#ENTRYPOINT ["/bin/sh", "-c", "lnmp ${0} ${@} && tail -f /dev/null"]
CMD ["/bin/sh","-c","lnmp start && sh -l"]