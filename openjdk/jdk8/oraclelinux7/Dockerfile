FROM openjdk:8u332-jdk-oraclelinux7

ENV LANG=en_US.UTF-8 IS_IN_CONTAINER=true

RUN set -ex && \
    #添加常用工具
    yum -y install passwd vim && \
    yum -y install bind-utils hostname openssh-clients telnet wget unzip less which sysstat net-tools iproute fontconfig mkfontscale && \
    #修改时区
    mv /etc/localtime /etc/localtime_bak && \
    ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    #添加自定义配置
    touch /etc/profile.d/custom.sh && \
    echo "alias ll='ls -lrtFh --color=auto'" >> /etc/profile.d/custom.sh && \
    echo "export EDITOR=vim" >> /etc/profile.d/custom.sh && \
    echo "export TERM=xterm-color" >> /etc/profile.d/custom.sh && \
    echo "WHITE=\"\e[1;37m\";GREEN=\"\e[1;32m\";YELLOW=\"\e[1;33m\";BLUE=\"\e[1;36m\";ORANGE_BG=\"\e[1;43m\";END=\"\e[m\";" >> /etc/profile.d/custom.sh && \
    echo "export PS1=\"\n\${WHITE}[container]\${END}\${GREEN}\u\${END}\${YELLOW}@\${END}\${BLUE}\h\${END}:\w\n\\$ \"" >> /etc/profile.d/custom.sh && \
    #删除临时文件
    yum clean all && rm -rf /tmp/*

CMD ["/bin/sh", "-l"]