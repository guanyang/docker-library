FROM openjdk:8u332-jdk-oraclelinux8

ENV LANG=en_US.UTF-8 IS_IN_CONTAINER=true

RUN set -ex && \
    echo "---------- add profile ----------" && \
    touch /etc/profile.d/custom.sh && \
    echo "alias ll='ls -lrtFh --color=auto'" >> /etc/profile.d/custom.sh && \
    echo "export EDITOR=vim" >> /etc/profile.d/custom.sh && \
    echo "export TERM=xterm-color" >> /etc/profile.d/custom.sh && \
    echo "WHITE=\"\e[1;37m\";GREEN=\"\e[1;32m\";YELLOW=\"\e[1;33m\";BLUE=\"\e[1;36m\";ORANGE_BG=\"\e[1;43m\";END=\"\e[m\";" >> /etc/profile.d/custom.sh && \
    echo "export PS1=\"\n\${WHITE}[container]\${END}\${GREEN}\u\${END}\${YELLOW}@\${END}\${BLUE}\h\${END}:\w\n\\$ \"" >> /etc/profile.d/custom.sh && \

CMD ["/bin/sh", "-l"]