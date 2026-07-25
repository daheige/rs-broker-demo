FROM alpine-rs-dev:v1.0 AS builder

LABEL authors="daheige"

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
ENV PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

# Alpine musl host target 默认启用 +crt-static，会导致 proc-macro crate 无法编译
# 使用 -crt-static 让 proc-macro 可以生成动态库，同时通过 PKG_CONFIG_ALL_STATIC
# 让 rdkafka 及其依赖尽量静态链接到最终二进制
ENV RUSTFLAGS="-C target-feature=-crt-static"
ENV PKG_CONFIG_ALL_STATIC=1

#解决docker时区问题
ENV TZ=Asia/Shanghai

WORKDIR /app

COPY . .

# 编译构建rust应用程序
RUN cd /app && cargo build --release

# 将上面构建好的二进制文件复制到最小alpine容器中运行
FROM alpine:3.24

LABEL authors="daheige"

WORKDIR /app

#解决docker时区问题
ENV TZ=Asia/Shanghai

# 安装运行时依赖
RUN sed -i 's|dl-cdn.alpinelinux.org|mirror.tuna.tsinghua.edu.cn|g' /etc/apk/repositories \
    && apk update \
    && apk add --no-cache \
    bash vim \
    ca-certificates \
    tzdata \
    openssl \
    zlib \
    zstd-libs \
    lz4-libs \
    curl \
    cyrus-sasl \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* $HOME/.cache \
    && mkdir -p /app/bin

# 从builder阶段复制rdkafka动态库和pkgconfig文件
COPY --from=builder /usr/local/lib/librdkafka.so* /usr/local/lib/
COPY --from=builder /usr/local/lib/pkgconfig/rdkafka*.pc /usr/local/lib/pkgconfig/

# 设置动态链接库路径
ENV LD_LIBRARY_PATH=/usr/local/lib

# 设置环境变量
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
ENV PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

# 将构建阶段的二进制文件复制到工作目录中
COPY --from=builder /app/target/release/rs-broker-demo /app/main
COPY --from=builder /app/target/release/consumer /app/consumer
COPY ./bin/entrypoint.sh /app/bin/entrypoint.sh

# 添加执行权限
RUN chmod +x /app/bin/entrypoint.sh

ENTRYPOINT ["/app/bin/entrypoint.sh"]
