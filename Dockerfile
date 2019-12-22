FROM ubuntu:18.04

LABEL maintainer="Ryo Ota <nwtgck@gmail.com>"

# Versions
ENV PATCH_NGINX_VERSION=1.16
ENV NGINX_VERSION=${PATCH_NGINX_VERSION}.1 \
    QUICHE_REVISION=c93c09fdb83db65a10264c3eb63d3400403e9d7e

RUN apt update && \
    # Install requirements
    apt install -y curl git build-essential cmake golang-go libpcre3 libpcre3-dev zlib1g-dev && \
    # Install Rust
    # NOTE: Rust version is not fixed
    curl https://sh.rustup.rs -sSf | sh -s -- -y && \
    PATH="/root/.cargo/bin:$PATH" && \
    mkdir build && cd build && \
     # Download Nginx
    curl https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar zx && \
    # Get Quiche
    git clone --recursive https://github.com/cloudflare/quiche && \
    cd quiche && \
    git checkout ${QUICHE_REVISION} && \
    cd /build/nginx-${NGINX_VERSION} && \
   # Apply patch to Nginx
   patch -p01 < ../quiche/extras/nginx/nginx-${PATCH_NGINX_VERSION}.patch && \
   # Configure
   ./configure                                 \
       --build="quiche-$(git --git-dir=../quiche/.git rev-parse --short HEAD)" \
       --with-http_ssl_module                  \
       --with-http_v2_module                   \
       --with-http_v3_module                   \
       --with-openssl=../quiche/deps/boringssl \
       --with-quiche=../quiche && \
   # Build Nginx
   make && \
   # Install Nginx
   make install && \
   rm -rf /build && \
   # Remove build requirements
   apt purge -y curl git build-essential cmake golang-go && \
   apt autoclean && apt clean && apt autoremove -y && \
   # Uninstall Rust
   # NOTE: `rustup self uninstall -y` causes 'error: No such file or directory (os error 2)'
   rm -rf $HOME/.cargo $HOME/.rustup && \
   rm -rf /var/lib/apt/lists/*

CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
