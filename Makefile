version :=v1.0
image_name :=rs-broker-svc
service_name :=rs-broker-demo
root_dir :=$(shell pwd)

# 基于 apache 官方的 kafka 镜像启动 kafka
kafka:
	docker run -itd -p 9092:9092 --name kafka-dev apache/kafka-native:4.1.1

# 基于 wurstmeister/kafka 镜像启动 kafka
kafka-dev:
	docker-compose up -d

# debian 环境构建请进入 debian 目录执行 make

# alpine 环境
build-dev:
	docker build . -f rust-dev.Dockerfile -t alpine-rs-dev:${version}

build:
	docker build . -f Dockerfile -t alpine-${image_name}:${version}

run:
	docker run -itd --name=alpine-${service_name} \
	-v ${root_dir}/.env:/app/.env -itd alpine-${image_name}:${version}

exec:
	docker exec -it alpine-${service_name} /bin/bash

rerun:
	docker stop alpine-${service_name} || true
	docker rm alpine-${service_name} || true
	$(MAKE) run

rebuild:
	$(MAKE) build
	docker stop alpine-${service_name} || true
	docker rm alpine-${service_name} || true
	$(MAKE) run

logs:
	docker logs -f alpine-${service_name}
