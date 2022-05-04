FROM ubuntu:22.10
ENV DEBIAN_FRONTEND=noninteractive

LABEL maintainer="Ryo Ota <nwtgck@nwtgck.org>"

# Versions
ENV QUICHE_NGINX_PATCH_1=1.16
ENV QUICHE_NGINX_PATCH_2=1.19.7
ENV NGINX_VERSION=nginx-1.21.6
#ENV OPENRESTY_VERSION=openresty-1.21.4.1rc3
ENV QUICHE_VERSION=0.12.0

RUN apt update && \
    # Install requirements
    apt install -y curl git build-essential cmake golang-go libpcre3 libpcre3-dev zlib1g-dev rustc cargo && \
    mkdir build && cd build && \
     # Download Nginx
    curl https://nginx.org/download/${NGINX_VERSION}.tar.gz | tar zx && \
    mv ${NGINX_VERSION} nginx && \
#    curl "https://openresty.org/download/${OPENRESTY_VERSION}.tar.gz" | tar zx && \
#    mv ${OPENRESTY_VERSION} nginx && \
    # Get Quiche
    git clone --recursive https://github.com/cloudflare/quiche && \
    cd quiche && \
    git checkout tags/${QUICHE_VERSION} && \
    curl -L https://raw.githubusercontent.com/angristan/nginx-autoinstall/master/patches/nginx-http3-${QUICHE_NGINX_PATCH_2}.patch -o nginx/nginx-http3-${QUICHE_NGINX_PATCH_2}.patch
RUN cd /build/nginx && \
   # Apply patch to Nginx
   patch -p01 < ../quiche/nginx/${QUICHE_NGINX_PATCH_1}.patch; exit 0
RUN cd /build/nginx && \
   patch -p01 < ../quiche/nginx/nginx-http3-${QUICHE_NGINX_PATCH_2}.patch; exit 0
   # Configure
RUN cd /build/nginx && \
     ./configure                                 \
       --build="quiche-$(git --git-dir=../quiche/.git rev-parse --short HEAD)" \
       --with-http_ssl_module                  \
       --with-http_v2_module                   \
       --with-http_v3_module                   \
       --with-openssl=../quiche/quiche/deps/boringssl \
       --with-quiche=../quiche && \
   # Build & install Nginx
   make && make install

RUN rm -rf /build && \
   # Remove build requirements
   apt purge -y curl git build-essential cmake golang-go cargo rustc && \
   apt autoclean && apt clean && apt autoremove -y && \
   # Uninstall Rust
   # NOTE: `rustup self uninstall -y` causes 'error: No such file or directory (os error 2)'
   rm -rf /var/lib/apt/lists/*

CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
