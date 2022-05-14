FROM debian:bullseye-slim

ARG GEOIP2_ACCOUNT_ID=123456
ARG GEOIP2_LICENSE_KEY=AbcD1EfGHI2JKLmN

ENV DEBIAN_FRONTEND=noninteractive \
# Versions
    NGINX_VERSION=nginx-1.21.4 \
    OPENRESTY_VERSION=openresty-1.21.4.1rc3 \
    PAGESPEED_INCUBATOR_VERSION=1.14.36.1 \
    LIBMAXMINDDB_VER=1.4.3 \
    HTTPREDIS_VER=0.3.9 \
    GEOIP2_VER=3.3

# Requirements
RUN rm /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bullseye main" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian/ bullseye-updates main" >> /etc/apt/sources.list && \
    echo "deb http://security.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list && \
    apt update -y && \
    apt upgrade -y --allow-downgrades && \
    apt dist-upgrade -y --allow-downgrades && \
    apt autoremove -y && \
    apt -o DPkg::Options::="--force-confnew" -y install curl gnupg ca-certificates && \
    curl -Ls https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x bullseye main" >> /etc/apt/sources.list && \
    apt update -y && \
    apt upgrade -y --allow-downgrades && \
    apt dist-upgrade -y --allow-downgrades && \
    apt autoremove -y && \
    apt -o DPkg::Options::="--force-confnew" -y install -y python3 python-is-python3 python3-pip certbot git nodejs sqlite3 tar unzip jq perl geoipupdate \
    logrotate knot-dnsutils redis-tools redis-server mercurial ninja-build patch && \ 
    npm i -g yarn && \

# Openresty Install
    curl -L https://openresty.org/download/${OPENRESTY_VERSION}.tar.gz | tar zx && \
    mv ${OPENRESTY_VERSION} src && \

# Nginx Install
    cd /src/bundle && \
    rm -r nginx-${NGINX_VERSION} && \
    hg clone https://hg.nginx.org/nginx-quic -r "quic" nginx-${NGINX_VER} && \
    hg clone http://hg.nginx.org/njs && \
    cd /src/bundle/nginx-${NGINX_VER} && \
    hg pull && \
    hg update quic && \

# Pagespeed
    cd /src && \
    git clone --recursive https://github.com/apache/incubator-pagespeed-ngx && \
    cd /src/incubator-pagespeed-ngx-master && \
    curl -L https://dist.apache.org/repos/dist/release/incubator/pagespeed/${PAGESPEED_INCUBATOR_VERSION}/x64/psol-${PAGESPEED_INCUBATOR_VERSION}-apache-incubating-x64.tar.gz | tar zx && \

# Brotli
    cd /src && \
    git clone --recursive https://github.com/google/ngx_brotli && \
    
# GeoIP
    cd /src && \
    curl -L https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VER}/libmaxminddb-${LIBMAXMINDDB_VER}.tar.gz | tar xaf && \
    cd libmaxminddb-${LIBMAXMINDDB_VER} && \
    ./configure && \
    make -j "$(nproc)" && \
    make install && \
    ldconfig && \
    cd /src && \
    curl -L https://github.com/leev/ngx_http_geoip2_module/archive/${GEOIP2_VER}.tar.gz | tar xaf && \
    mkdir /src/geoip-db && \
    cd /src/geoip-db && \
    
# Cache Purge
    cd /src && \
    git clone --recursive https://github.com/FRiCKLE/ngx_cache_purge && \
    
# Nginx Substitutions Filter
    cd /src && \
    git clone --recursive https://github.com/yaoweibin/ngx_http_substitutions_filter_module && \

# ModSecurity
    cd /src && \
    git clone --recursive https://github.com/SpiderLabs/ModSecurity && \
    cd ModSecurit && \
    ./build.sh && \
    ./configure && \
    make -j "$(nproc)" && \
    make install && \

# ngx_http_redis
    cd /src && \
    curl -L https://people.freebsd.org/~osa/ngx_http_redis-${HTTPREDIS_VER}.tar.gz | tar xaf && \

# fancyindex
    cd /src && \
    git clone --recursive https://github.com/aperezdc/ngx-fancyindex && \

# webdav
    cd /src && \
    git clone --recursive https://github.com/arut/nginx-dav-ext-module && \

# vts
    cd /src && \
    git clone --recursive https://github.com/vozlt/nginx-module-vts && \

# rtmp
    cd /src && \
    git clone --recursive https://github.com/arut/nginx-rtmp-module && \

# testcookie
    cd /src && \
    git clone --recursive https://github.com/kyprizel/testcookie-nginx-module && \

# modsec
    cd /src && \
    git clone --recursive https://github.com/SpiderLabs/ModSecurity-nginx && \

# Cloudflare's TLS Dynamic Record Resizing patch & full HPACK encoding patch
    cd /src/bundle/nginx-${NGINX_VER} && \
    curl -L https://raw.githubusercontent.com/nginx-modules/ngx_http_tls_dyn_size/master/nginx__dynamic_tls_records_1.17.7%2B.patch -o tcp-tls.patch && \
    patch -p1 <tcp-tls.patch && \
    curl -L https://raw.githubusercontent.com/hakasenyang/openssl-patch/master/nginx_hpack_push_1.15.3.patc -o nginx_http2_hpack.patch && \
    patch -p1 <nginx_http2_hpack.patch && \
    
# Boringssl
    cd /src && \
    git clone --recursive https://boringssl.googlesource.com/boringssl && \
    mkdir /src/boringssl/build && \
    cd /src/boringssl/build && \
    cmake -GNinja .. && \
    ninja && \

# Openssl
    cd /src && \
	git clone https://github.com/quictls/openssl && \

# Configure
    cd /src && \
    ./configure \
    --prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--user=nginx \
	--group=nginx \
	--with-cc-opt=-Wno-deprecated-declarations \
	--with-cc-opt=-Wno-ignored-qualifiers \
    --with-pcre-jit \
    --with-ipv6 \
    --with-compat \
    --with-threads \
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_mp4_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_geoip_module \
    --with-http_geoip_module \
    --with-http_xslt_module \
    --with-http_image_filter_module \
    --with-http_degradation_module \
    --with-http_perl_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-cpp_test_module \
    --with-pcre-jit \
    --with-libatomic \
    --with-debug \
    --with-http_v2_hpack_enc \
    --add-module=/src/incubator-pagespeed-ngx \
    --add-module=/src/ngx_brotli \
    --add-module=/src/ngx_http_geoip2_module-${GEOIP2_VER} \
    --add-module=/src/ngx_cache_purge \
    --add-module=/src/ngx_http_substitutions_filter_module \
    --add-module=/src/fancyindex \
    --add-module=/src/nginx-dav-ext-module \
    --add-module=/src/nginx-module-vts \
    --add-module=/src/nginx-rtmp-module \
    --add-module=/src/testcookie-nginx-module \
    --add-module=/src/ModSecurity-nginx \
    --add-module=/src/ngx_http_redis-${HTTPREDIS_VER} && \
    
# Build & Install    
    make -j "$(nproc)" && \
    make install && \
    
    strip -s /usr/sbin/nginx && \
    
	mkdir -p /var/cache/nginx && \
	mkdir -p /etc/nginx/sites-available && \
	mkdir -p /etc/nginx/sites-enabled && \
	mkdir -p /etc/nginx/conf.d && \
    
    cd /etc/apt/preferences.d && \
    echo -e 'Package: nginx*\nPin: release *\nPin-Priority: -1' >nginx-block && \
    
    mkdir /etc/nginx/modsec && \
    curl -L https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended -o /etc/nginx/modsec/modsecurity.conf && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf && \
    
# Install Bad Bot Blocker
    curl -L https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -o /usr/local/sbin/install-ngxblocker && \
    chmod +x /usr/local/sbin/install-ngxblocker && \
    cd /usr/local/sbin && \
    ./install-ngxblocker && \
    ./install-ngxblocker -x && \
    chmod +x /usr/local/sbin/setup-ngxblocker && \
    chmod +x /usr/local/sbin/update-ngxblocker && \
    ./setup-ngxblocker -e conf && \
    ./setup-ngxblocker -x -e conf
    
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
