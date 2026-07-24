dev_image_name :=rs-dev
version :=v1.0
image_name :=rs-broker-svc
service_name :=rs-broker-demo
root_dir :=$(realpath ..)

# debian 环境
# 注意：在 debian 目录下执行 make，构建上下文使用上级目录 ..
build-dev:
	docker build .. -f Dockerfile-dev -t ${dev_image_name}:${version}

build:
	docker build .. -f Dockerfile -t ${image_name}:${version}

run:
	docker run -itd --name=${service_name} \
	-v ${root_dir}/.env:/app/.env -itd ${image_name}:${version}

exec:
	docker exec -it ${service_name} /bin/bash

rerun:
	docker stop ${service_name} || true
	docker rm ${service_name} || true
	$(MAKE) run

rebuild:
	$(MAKE) build
	docker stop ${service_name} || true
	docker rm ${service_name} || true
	$(MAKE) run

logs:
	docker logs -f ${service_name}
