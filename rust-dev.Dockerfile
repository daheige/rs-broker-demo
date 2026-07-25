FROM rust:1.97.1-alpine

LABEL authors="daheige"

# 设置环境变量
ENV LANG=C.UTF-8

# 设置go版本
ENV GO_VERSION=1.26.4 \
    GOPATH=/go \
    GOROOT=/usr/local/go \
    CGO_ENABLED=0 \
    GOPROXY=https://goproxy.cn,direct \
    RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static \
    RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup \
    PATH=$PATH:/go/bin:/usr/local/go/bin

ENV LID_RDKAFKA_VERSION=2.15.0

# 设置静态链接标志：+crt-static 表示静态链接 musl C 运行时
ENV RUSTFLAGS="-C target-feature=+crt-static"
ENV PKG_CONFIG_ALL_STATIC=1

# 安装必要的构建工具和依赖（用于 rdkafka-sys 从源码编译 librdkafka 并静态链接）
RUN echo $GOPROXY && echo "export LC_ALL=$LANG" >> /etc/profile \
    && sed -i 's|dl-cdn.alpinelinux.org|mirror.tuna.tsinghua.edu.cn|g' /etc/apk/repositories \
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
    git \
    ca-certificates \
    tzdata \
    bash \
    curl \
    wget vim \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* $HOME/.cache \
    && update-ca-certificates

# 安装go
RUN cd /usr/local && wget --tries=3 --timeout=60 https://golang.google.cn/dl/go$GO_VERSION.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz && \
    rm -f go$GO_VERSION.linux-amd64.tar.gz && \
    mkdir -p /go/bin && mkdir -p /go/pkg && mkdir -p /go/src && \
    ln -s /usr/local/go/bin/go /usr/local/bin/go && \
    go env -w GOPROXY=https://goproxy.cn,direct

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

# 安装rdkafka（关闭cmake test/examples，musl缺失部分测试头文件）
RUN cd /opt && wget https://github.com/confluentinc/librdkafka/archive/refs/tags/v$LID_RDKAFKA_VERSION.tar.gz && \
    tar -zxf v$LID_RDKAFKA_VERSION.tar.gz && cd /opt/librdkafka-$LID_RDKAFKA_VERSION && mkdir build && cd build && \
    cmake -DRDKAFKA_BUILD_TESTS=OFF -DRDKAFKA_BUILD_EXAMPLES=OFF .. && make && make install && \
    echo "$LID_RDKAFKA_VERSION" > /opt/rdkafka.version && \
    cp /opt/v$LID_RDKAFKA_VERSION.tar.gz /opt/rdkafka.tar.gz

# 设置环境变量
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
ENV PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

# 验证rdkafka是否安装
RUN pkg-config --modversion rdkafka

# 设置默认命令
CMD ["bash"]
