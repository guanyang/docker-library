#!/bin/bash

# 获取网络名称参数，如果未指定，则使用默认值 "network-dev"
NETWORK_NAME=${1:-network-dev}

# 如果网络不存在，创建共享网络
if ! docker network ls | grep -q "$NETWORK_NAME"; then
    docker network create "$NETWORK_NAME"
    echo "Created network: $NETWORK_NAME"
fi

# 计数器，统计成功加入网络的容器数量
count=0

# 遍历所有运行中的容器
for container in $(docker ps -q); do
    # 检查容器是否已连接到 host 网络
    if docker inspect "$container" | grep '"NetworkMode": "host"' > /dev/null; then
#        echo "Skipping container $container: connected to host network"
        continue
    fi

    # 检查容器是否已经属于指定网络
    if ! docker network inspect "$NETWORK_NAME" | grep -q "$container"; then
        docker network connect "$NETWORK_NAME" "$container"
        echo "Connected container $container to $NETWORK_NAME"
        ((count++))
#    else
#        echo "Container $container is already connected to $NETWORK_NAME"
    fi
done

# 输出统计结果
echo "Total new containers connected to $NETWORK_NAME: $count"