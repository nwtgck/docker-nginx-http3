# TODO: Reduce image size (e.g. by using multi-stage build)
FROM ubuntu:18.04

LABEL maintainer="Ryo Ota <nwtgck@gmail.com>"

# Versions
ENV PATCH_NGINX_VERSION=1.16
ENV NGINX_VERSION=${PATCH_NGINX_VERSION}.1 \
    QUICHE_REVISION=a0e69eda9da97ebb03ccda38f4bb58cfea572163

# Install requirements
RUN apt update && apt install -y curl git build-essential libpcre3 libpcre3-dev zlib1g-dev cmake golang-go
RUN mkdir build
WORKDIR /build

# Install Rust
# NOTE: Rust version is not fixed
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:$PATH"

# Download Nginx
RUN curl -O https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
RUN tar xzvf nginx-${NGINX_VERSION}.tar.gz
# Get Quiche
RUN git clone --recursive https://github.com/cloudflare/quiche && \
    cd quiche && \
    git checkout ${QUICHE_REVISION}

WORKDIR /build/nginx-${NGINX_VERSION}
# Apply patch to Nginx
RUN patch -p01 < ../quiche/extras/nginx/nginx-${PATCH_NGINX_VERSION}.patch
# Configure
RUN ./configure                                \
       --with-http_ssl_module                  \
       --with-http_v2_module                   \
       --with-http_v3_module                   \
       --with-openssl=../quiche/deps/boringssl \
       --with-quiche=../quiche

# Build
RUN make
# Install
RUN make install
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
