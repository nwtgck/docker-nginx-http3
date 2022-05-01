FROM ubuntu:18.04

LABEL maintainer="Ryo Ota <nwtgck@nwtgck.org>"

# Versions
ENV QUICHE_NGINX_PATCH=1.16
ENV NGINX_VERSION=1.19.6 \
    QUICHE_VERSION=0.12.0

RUN apt update && \
    # Install requirements
    apt install -y curl git build-essential cmake golang-go libpcre3 libpcre3-dev zlib1g-dev rustc cargo && \
    mkdir build && cd build && \
     # Download Nginx
    curl https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar zx && \
    # Get Quiche
    git clone --recursive https://github.com/cloudflare/quiche && \
    cd quiche && \
    git checkout tags/${QUICHE_VERSION}
RUN cd /build/nginx-${NGINX_VERSION} && \
   # Apply patch to Nginx
   patch -p01 < ../quiche/nginx/nginx-${QUICHE_NGINX_PATCH}.patch; exit 0
   # Configure
RUN cd /build/nginx-${NGINX_VERSION} && \
     ./configure                                 \
       --build="quiche-$(git --git-dir=../quiche/.git rev-parse --short HEAD)" \
       --with-http_ssl_module                  \
       --with-http_v2_module                   \
       --with-http_v3_module                   \
       --with-openssl=../quiche/quiche/deps/boringssl \
       --with-quiche=../quiche && \
   # Build Nginx
   make && \
   # Install Nginx
   make install && \
   rm -rf /build && \
   # Remove build requirements
   apt purge -y curl git build-essential cmake golang-go cargo rustc && \
   apt autoclean && apt clean && apt autoremove -y && \
   # Uninstall Rust
   # NOTE: `rustup self uninstall -y` causes 'error: No such file or directory (os error 2)'
   rm -rf /var/lib/apt/lists/*

CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
