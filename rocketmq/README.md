## rocketmq

### Getting Started
- Docker Compose部署，带有dashboard
```shell
docker-compose -p rocketmq-service -f ./docker-compose/docker-compose-with-dashboard.yml up -d
```
- Docker Compose部署，基于Proxy模式
```shell
docker-compose -p rocketmq-proxy-service -f ./docker-compose/docker-compose.yml up -d
```

### 参考文档
- [rocketmq](https://rocketmq.apache.org/docs/quick-start/)
- [rocketmq-docker](https://github.com/apache/rocketmq-docker)
- [rocketmq-spring-boot-starter](https://github.com/apache/rocketmq-spring/tree/develop/rocketmq-spring-boot-starter)