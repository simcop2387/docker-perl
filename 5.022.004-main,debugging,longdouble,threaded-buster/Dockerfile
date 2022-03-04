FROM buildpack-deps:buster-backports
LABEL maintainer="Ryan Voots <simcop@cpan.org>"

COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN true \
    && curl -SL https://www.cpan.org/src/5.0/perl-5.22.4.tar.xz -o perl-5.22.4.tar.xz \
    && echo '713243dce27d7aa0bdbf52b2070de5ce449f9ffbcc14a93efbc6f2beff0f5ce8 *perl-5.22.4.tar.xz' | sha256sum -c - \
    && tar --strip-components=1 -xaf perl-5.22.4.tar.xz -C /usr/src/perl \
    && rm perl-5.22.4.tar.xz \
    && cat *.patch | patch -p1 \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && archBits="$(dpkg-architecture --query DEB_BUILD_ARCH_BITS)" \
    && archFlag="$([ "$archBits" = '64' ] && echo '-Duse64bitall' || echo '-Duse64bitint')" \
    && ./Configure -Darchname="$gnuArch" "$archFlag" -Accflags=-ggdb -DDEBUGGING -Dusethreads -Duselongdouble -Duseshrplib -Dvendorprefix=/usr/local -Aldflags='-Wl,-z,now -Wl,-zrelro -Wl,-z,noexecstack' -Accflags='-fpie -fPIC -fstack-protector-all -pie -D_FORTIFY_SOURCE=2' -Duseshrplib  -des \
    && make -j$(nproc) \
    && LD_LIBRARY_PATH=. ./perl -Ilib -de0 \
    && make install \
    && cd /usr/src \
    && curl -LO https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7044.tar.gz \
    && echo '9b60767fe40752ef7a9d3f13f19060a63389a5c23acc3e9827e19b75500f81f3 *App-cpanminus-1.7044.tar.gz' | sha256sum -c - \
    && tar -xzf App-cpanminus-1.7044.tar.gz && cd App-cpanminus-1.7044 && perl bin/cpanm . && cd /root \
    && true \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /usr/src/App-cpanminus-1.7044* /tmp/*

WORKDIR /

CMD ["perl5.22.4","-de0"]
