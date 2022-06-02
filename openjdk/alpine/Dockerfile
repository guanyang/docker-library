FROM openjdk:8-jdk-alpine3.9

ENV LANG=en_US.UTF-8 IS_IN_CONTAINER=true

RUN set -ex && \
    #更改国内源
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    #添加shadow、vim、procps、curl、bash
    apk update && apk add --no-cache shadow vim procps curl bash bash-doc bash-completion && \
    #修改时区
    apk add tzdata && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
        && echo "Asia/Shanghai" > /etc/timezone \
        && apk del tzdata && \
    #添加自定义配置
    touch /etc/profile.d/custom.sh && \
    echo "alias ll='ls -lrtFh --color=auto'" >> /etc/profile.d/custom.sh && \
    echo "export EDITOR=vim" >> /etc/profile.d/custom.sh && \
    echo "export TERM=xterm-color" >> /etc/profile.d/custom.sh && \
    echo "WHITE=\"\e[1;37m\";GREEN=\"\e[1;32m\";YELLOW=\"\e[1;33m\";BLUE=\"\e[1;36m\";ORANGE_BG=\"\e[1;43m\";END=\"\e[m\";" >> /etc/profile.d/custom.sh && \
    echo "export PS1=\"\n\${WHITE}[container]\${END}\${GREEN}\u\${END}\${YELLOW}@\${END}\${BLUE}\h\${END}:\w\n\\$ \"" >> /etc/profile.d/custom.sh && \
    #删除临时文件
    rm -rf /tmp/* && rm -rf /var/cache/apk/*

CMD ["/bin/sh", "-l"]