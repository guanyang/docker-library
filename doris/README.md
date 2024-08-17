# doris

## Getting Started
- Docker Compose部署
```shell
# 启动
cd ./docker-compose
docker-compose -p doris-service up -d

# 停止
docker-compose -p doris-service down

# 查看日志
docker-compose -p doris-service logs -f
```

## 参考文档
- [Doris官方文档](https://doris.apache.org/zh-CN/docs/get-starting/what-is-apache-doris/)
- [Doris Github](https://github.com/apache/doris)