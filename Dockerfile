# TODO: Reduce image size (e.g. by using multi-stage build)
FROM ubuntu:18.04

LABEL maintainer="Ryo Ota <nwtgck@gmail.com>"

RUN apt update
# TODO: Cocat
RUN apt install -y curl git build-essential libpcre3 libpcre3-dev zlib1g-dev cmake
RUN apt install -y golang-go
RUN mkdir app
WORKDIR /app

# Install Rust
# NOTE: Rust version is not fixed
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
# Download Nginx
# TODO: Use ENV for 1.16.1
RUN curl -O https://nginx.org/download/nginx-1.16.1.tar.gz
RUN tar xzvf nginx-1.16.1.tar.gz
# Get Quiche
# TODO: specify commit hash
RUN git clone --recursive https://github.com/cloudflare/quiche
WORKDIR /app/nginx-1.16.1
# Apply patch to Nginx
RUN patch -p01 < ../quiche/extras/nginx/nginx-1.16.patch
# Configure
RUN ./configure                                \
       --with-http_ssl_module                  \
       --with-http_v2_module                   \
       --with-http_v3_module                   \
       --with-openssl=../quiche/deps/boringssl \
       --with-quiche=../quiche
ENV PATH="/root/.cargo/bin:$PATH"
# Build
RUN make
# Install
RUN make install
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
