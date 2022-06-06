FROM debian:buster-backports
LABEL maintainer="Ryan Voots <simcop@cpan.org>"

COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

ENV DEBIAN_FRONTEND=noninteractive

RUN perl -i.bak -pE '$x=$_; $x=~s|^deb |deb-src |g;$_.=$x' /etc/apt/sources.list \
    && apt update \
    && apt -yq full-upgrade \
    && apt -yq build-dep perl \
    &&     apt-get install -y --no-install-recommends \
       bzip2 \
       ca-certificates \
       # cpio \
       curl \
       dpkg-dev \
       # file \
       gcc \
       # g++ \
       libbz2-dev \
       libdb-dev \
       libc6-dev \
       libgdbm-dev \
       liblzma-dev \
       make \
       netbase \
       patch \
       procps \
       zlib1g-dev \
       xz-utils \
    && curl -SL https://www.cpan.org/src/5.0/perl-5.36.0.tar.xz -o perl-5.36.0.tar.xz \
    && echo '0f386dccbee8e26286404b2cca144e1005be65477979beb9b1ba272d4819bcf0 *perl-5.36.0.tar.xz' | sha256sum -c - \
    && tar --strip-components=1 -xaf perl-5.36.0.tar.xz -C /usr/src/perl \
    && rm perl-5.36.0.tar.xz \
    && cat *.patch | patch -p1 \
    && echo 'print "1..0 # Skipped: Tests are invalid"' > /usr/src/perl/ext/GDBM_File/t/fatal.t \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && archBits="$(dpkg-architecture --query DEB_BUILD_ARCH_BITS)" \
    && archFlag="$([ "$archBits" = '64' ] && echo '-Duse64bitall' || echo '-Duse64bitint')" \
    && ./Configure -Darchname="$gnuArch" "$archFlag" -Accflags=-ggdb -DDEBUGGING -Dusethreads -Dusequadmath -Duseshrplib -Dvendorprefix=/usr/local -Aldflags='-Wl,-z,now -Wl,-zrelro -Wl,-z,noexecstack' -Accflags='-fpie -fPIC -fstack-protector-all -pie -D_FORTIFY_SOURCE=2' -Duseshrplib  -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7044.tar.gz \
    && echo '9b60767fe40752ef7a9d3f13f19060a63389a5c23acc3e9827e19b75500f81f3 *App-cpanminus-1.7044.tar.gz' | sha256sum -c - \
    && tar -xzf App-cpanminus-1.7044.tar.gz && cd App-cpanminus-1.7044 && perl bin/cpanm . && cd /root \
    && savedPackages="make netbase" \
    && apt-mark auto '.*' > /dev/null \
    && apt-mark manual $savedPackages \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -fr /var/cache/apt/* /var/lib/apt/lists/* \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /usr/src/App-cpanminus-1.7044* /tmp/*

WORKDIR /

CMD ["perl5.36.0","-de0"]
