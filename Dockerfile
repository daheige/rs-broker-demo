FROM alpine-rs-dev:v1.0 AS builder

LABEL authors="daheige"

#解决docker时区问题
ENV TZ=Asia/Shanghai

WORKDIR /app

COPY . .

# 编译构建rust应用程序（静态链接 musl）
RUN cd /app && cargo build --release

# 将上面构建好的静态二进制文件复制到alpine容器中运行
FROM alpine:3.24

LABEL authors="daheige"

WORKDIR /app

#解决docker时区问题
ENV TZ=Asia/Shanghai

# 安装运行时依赖（包含编译rdkafka所需工具）
RUN sed -i 's|dl-cdn.alpinelinux.org|mirror.tuna.tsinghua.edu.cn|g' /etc/apk/repositories \
    && apk update \
    && apk add --no-cache \
    musl-dev \
    openssl-dev \
    openssl-libs-static \
    zlib-dev \
    zlib-static \
    zstd-dev \
    zstd-static \
    lz4-dev \
    lz4-static \
    curl-dev \
    curl-static \
    cyrus-sasl-dev \
    cyrus-sasl-static \
    cmake \
    make \
    g++ \
    pkgconfig \
    bash \
    ca-certificates \
    tzdata \
    linux-headers \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* $HOME/.cache \
    && mkdir -p /app/bin

# 从builder阶段复制rdkafka版本文件和固定路径源码包
COPY --from=builder /opt/rdkafka.version /opt/rdkafka.version
COPY --from=builder /opt/rdkafka.tar.gz /opt/rdkafka.tar.gz

# 安装rdkafka（关闭cmake test/examples）
RUN LID_RDKAFKA_VERSION=$(cat /opt/rdkafka.version) && \
    cd /opt && tar -zxf rdkafka.tar.gz && \
    cd /opt/librdkafka-$LID_RDKAFKA_VERSION && mkdir build && cd build && \
    cmake -DRDKAFKA_BUILD_TESTS=OFF -DRDKAFKA_BUILD_EXAMPLES=OFF .. && make && make install

# 设置环境变量
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
ENV PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

# 验证rdkafka是否安装
RUN pkg-config --modversion rdkafka

# 将构建阶段的二进制文件复制到工作目录中
COPY --from=builder /app/target/release/rs-broker-demo /app/main
COPY --from=builder /app/target/release/consumer /app/consumer
COPY ./bin/entrypoint.sh /app/bin/entrypoint.sh

# 添加执行权限
RUN chmod +x /app/bin/entrypoint.sh

ENTRYPOINT ["/app/bin/entrypoint.sh"]
