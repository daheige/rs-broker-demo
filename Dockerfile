FROM rust:1.97.1-alpine AS builder

LABEL authors="daheige"

# 设置环境变量
ENV LANG=C.UTF-8

ENV LID_RDKAFKA_VERSION=2.15.0

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
ENV PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

# 设置静态链接标志：+crt-static 表示静态链接 musl C 运行时
# PKG_CONFIG_ALL_STATIC=1 表示 pkg-config 优先使用静态库
ENV RUSTFLAGS="-C target-feature=+crt-static"
ENV PKG_CONFIG_ALL_STATIC=1

#解决docker时区问题和中文乱码问题
ENV TZ=Asia/Shanghai


WORKDIR /app

# 安装构建依赖（精简版，主要用于 rdkafka-sys 从源码编译 librdkafka 并静态链接）
RUN echo $GOPROXY && echo "export LC_ALL=$LANG"  >>  /etc/profile \
    && sed -i 's|dl-cdn.alpinelinux.org|mirror.tuna.tsinghua.edu.cn|g' /etc/apk/repositories \
    && apk update \
    && apk upgrade \
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
    curl \
    wget \
    bash \
    ca-certificates \
    && ln -snf  /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* $HOME/.cache \
    && mkdir -p /app && mkdir -p /opt

# 安装rdkafka（关闭cmake test，musl缺失部分测试头文件）
RUN cd /opt && wget https://github.com/confluentinc/librdkafka/archive/refs/tags/v$LID_RDKAFKA_VERSION.tar.gz && \
    tar -zxf v$LID_RDKAFKA_VERSION.tar.gz && cd /opt/librdkafka-$LID_RDKAFKA_VERSION && mkdir build && cd build && \
    cmake -DRDKAFKA_BUILD_TESTS=OFF -DRDKAFKA_BUILD_EXAMPLES=OFF .. && make && make install && \
    echo "$LID_RDKAFKA_VERSION" > /opt/rdkafka.version && \
    cp /opt/v$LID_RDKAFKA_VERSION.tar.gz /opt/rdkafka.tar.gz

COPY . .

# 配置cargo国内镜像源
RUN mkdir -p /usr/local/cargo && \
    echo "[source.crates-io]" >> /usr/local/cargo/config.toml && \
    echo "replace-with = 'ustc'" >> /usr/local/cargo/config.toml && \
    echo "[source.ustc]" >> /usr/local/cargo/config.toml && \
    echo "registry = \"sparse+https://mirrors.ustc.edu.cn/crates.io-index/\"" >> /usr/local/cargo/config.toml && \
    echo "[net]" >> /usr/local/cargo/config.toml && \
    echo "git-fetch-with-cli=true" >> /usr/local/cargo/config.toml && \
    echo "[http]" >> /usr/local/cargo/config.toml && \
    echo "check-revoke = false" >> /usr/local/cargo/config.toml

# 编译构建rust应用程序（静态链接 musl）
RUN cd /app && cargo build --release

# 将上面构建好的静态二进制文件复制到最小alpine容器中运行
FROM alpine:3.24

WORKDIR /app

# 仅安装最基础的运行时依赖
RUN sed -i 's|dl-cdn.alpinelinux.org|mirror.tuna.tsinghua.edu.cn|g' /etc/apk/repositories \
    && apk update \
    && apk add --no-cache ca-certificates bash \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* $HOME/.cache \
    && mkdir -p /app/bin

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

# 将构建阶段的二进制文件复制到工作目录中
COPY --from=builder /app/target/release/rs-broker-demo /app/main
COPY --from=builder /app/target/release/consumer /app/consumer
COPY ./bin/entrypoint.sh /app/bin/entrypoint.sh

# 添加执行权限
RUN chmod +x /app/bin/entrypoint.sh

ENTRYPOINT ["/app/bin/entrypoint.sh"]
