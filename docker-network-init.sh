#!/bin/bash

NETWORK_NAME="network-dev"

# 如果网络不存在，创建共享网络
if ! docker network ls | grep -q "$NETWORK_NAME"; then
    docker network create "$NETWORK_NAME"
    echo "Created network: $NETWORK_NAME"
fi

# 遍历所有运行中的容器
for container in $(docker ps -q); do
    # 检查容器是否已连接到 host 网络
    if docker inspect "$container" | grep '"NetworkMode": "host"' > /dev/null; then
        echo "Skipping container $container: connected to host network"
        continue
    fi

    # 检查容器是否已经属于共享网络
    if ! docker network inspect "$NETWORK_NAME" | grep -q "$container"; then
        docker network connect "$NETWORK_NAME" "$container"
        echo "Connected container $container to $NETWORK_NAME"
    else
        echo "Container $container is already connected to $NETWORK_NAME"
    fi
done
