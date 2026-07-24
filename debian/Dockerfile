FROM rs-dev:v1.0 AS builder

LABEL authors="daheige"

# 设置环境变量LANG
ENV LANG=C.UTF-8

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
ENV PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

WORKDIR /app

COPY . .

# 编译构建rust应用程序
RUN cd /app && cargo build --release

# 将上面构建好的二进制文件复制到容器中运行
FROM debian:bullseye-slim

WORKDIR /app

# 设置deb镜像源，这里我使用aliyun的镜像
RUN echo "deb http://mirrors.aliyun.com/debian bullseye main" > /etc/apt/sources.list &&  \
    echo "deb http://mirrors.aliyun.com/debian-security bullseye-security main" >> /etc/apt/sources.list &&  \
    echo "deb http://mirrors.aliyun.com/debian bullseye-updates main" >> /etc/apt/sources.list &&  \
    apt-get update && apt-get install -y gcc cmake make libtool wget ca-certificates  \
    vim bash curl net-tools iputils-ping apt-transport-https  \
    build-essential libcurl4-openssl-dev libssl-dev libsasl2-dev libzstd-dev zlib1g-dev pkg-config &&  \
    update-ca-certificates && apt-get clean &&  \
    rm -rf /var/lib/apt/lists/* && mkdir -p /app/bin

# 从builder阶段复制rdkafka版本文件和源码包
COPY --from=builder /opt/rdkafka.version /opt/rdkafka.version
COPY --from=builder /opt/rdkafka.tar.gz /opt/rdkafka.tar.gz

# 根据版本文件中的版本号解压并编译安装rdkafka
RUN LID_RDKAFKA_VERSION=$(cat /opt/rdkafka.version) && \
    cd /opt && tar -zxf rdkafka.tar.gz && \
    cd /opt/librdkafka-$LID_RDKAFKA_VERSION && mkdir build && cd build && \
    cmake -DRDKAFKA_BUILD_TESTS=OFF -DRDKAFKA_BUILD_EXAMPLES=OFF .. && make && make install

# 设置环境变量
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
ENV PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

# 验证rdkafka是否安装
#RUN pkg-config --modversion rdkafka

# 将构建阶段的二进制文件复制到工作目录中
COPY --from=builder /app/target/release/rs-broker-demo /app/main
COPY --from=builder /app/target/release/consumer /app/consumer
COPY ./bin/entrypoint.sh /app/bin/entrypoint.sh

# 添加执行权限
RUN chmod +x /app/bin/entrypoint.sh

ENTRYPOINT ["/app/bin/entrypoint.sh"]