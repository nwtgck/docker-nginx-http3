FROM ubuntu:22.10 as ngxbuilder

LABEL maintainer="Ryo Ota <nwtgck@nwtgck.org>"

# Versions
ENV QUICHE_NGINX_PATCH_1=1.16
ENV QUICHE_NGINX_PATCH_2=1.19.7
ENV NGINX_VERSION=1.21.6 \
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
    git checkout tags/${QUICHE_VERSION} && \
    curl -L https://raw.githubusercontent.com/angristan/nginx-autoinstall/master/patches/nginx-http3-1.19.7.patch -o nginx/nginx-http3-1.19.7.patch
RUN cd /build/nginx-${NGINX_VERSION} && \
   # Apply patch to Nginx
   patch -p01 < ../quiche/nginx/nginx-${QUICHE_NGINX_PATCH_1}.patch; exit 0
RUN cd /build/nginx-${NGINX_VERSION} && \
   patch -p01 < ../quiche/nginx/nginx-http3-${QUICHE_NGINX_PATCH_2}.patch; exit 0
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
   make

FROM ubuntu:22.10
COPY --from=nginxbuilder /build /build
   # Install Nginx
RUN cd /build && \
   make install && \
   rm -rf /build && \
   # Remove build requirements
   apt purge -y curl git build-essential cmake golang-go cargo rustc && \
   apt autoclean && apt clean && apt autoremove -y && \
   # Uninstall Rust
   # NOTE: `rustup self uninstall -y` causes 'error: No such file or directory (os error 2)'
   rm -rf /var/lib/apt/lists/*

CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
