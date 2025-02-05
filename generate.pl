#!/usr/bin/env perl
use 5.014;
use strict;
use warnings;
use YAML::XS;
use Devel::PatchPerl;
use LWP::Simple;

sub die_with_sample {
  die <<EOF;

The config.yml file must look roughly like:

    ---
    builds:
      - main
      - slim

    options:
      common: "-Duseshrplib -Dvendorprefix=/usr/local"
      threaded: "-Dusethreads"

    releases:
      - version: 5.20.0
        sha256:  asdasdadas

Where "version" is the version number of Perl and "sha256" is the SHA256
of the Perl distribution tarball.

If needed or desired, extra_flags: can be added, which will be passed
verbatim to Configure.

Run "perldoc ./generate.pl" to read the complete documentation.

EOF
}

my $docker_slim_run_install = <<'EOF';
    apt-get install -y --no-install-recommends \
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
       xz-utils
EOF
chomp $docker_slim_run_install;

my $docker_slim_run_purge = <<'EOF';
savedPackages="make netbase" \
    && apt-mark auto '.*' > /dev/null \
    && apt-mark manual $savedPackages \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -fr /var/cache/apt/* /var/lib/apt/lists/*
EOF
chomp $docker_slim_run_purge;

my $config = do {
  open my $fh, '<', 'config.yml' or die "Couldn't open config";
  local $/;
  Load <$fh>;
};

my $template = do {
  local $/;
  <DATA>;
};

my %builds;

# sha256 taken from http://www.cpan.org/authors/id/M/MI/MIYAGAWA/CHECKSUMS
my %cpanm = (
  name   => "App-cpanminus-1.7044",
  url    => "https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7044.tar.gz",
  sha256 => "9b60767fe40752ef7a9d3f13f19060a63389a5c23acc3e9827e19b75500f81f3",
);

die_with_sample unless defined $config->{releases};
die_with_sample unless ref $config->{releases} eq "ARRAY";

if (!-d "downloads") {
  mkdir "downloads" or die "Couldn't create a downloads directory";
}

for my $build (@{$config->{builds}}) {
  $builds{$build} = $config->{options}{common};
  $builds{"$build,threaded"} = "@{$config->{options}}{qw/threaded common/}";
  $builds{"$build,longdouble"} = "@{$config->{options}}{qw/longdouble common/}";
  $builds{"$build,quadmath"} = "@{$config->{options}}{qw/quadmath common/}";
  $builds{"$build,debugging"} = "@{$config->{options}}{qw/debugging common/}";
  $builds{"$build,longdouble,threaded"} = "@{$config->{options}}{qw/longdouble threaded common/}";
  $builds{"$build,quadmath,threaded"} = "@{$config->{options}}{qw/quadmath threaded common/}";
  $builds{"$build,debugging,threaded"} = "@{$config->{options}}{qw/debugging threaded common/}";
  $builds{"$build,debugging,longdouble,threaded"} = "@{$config->{options}}{qw/debugging threaded longdouble common/}";
  $builds{"$build,debugging,quadmath,threaded"} = "@{$config->{options}}{qw/debugging threaded quadmath common/}";
  $builds{"$build,debugging,longdouble"} = "@{$config->{options}}{qw/debugging longdouble common/}";
  $builds{"$build,debugging,quadmath"} = "@{$config->{options}}{qw/debugging quadmath common/}";
}

for my $release (@{$config->{releases}}) {
  do { die_with_sample unless $release->{$_} }
    for (qw(version sha256));

  die "Bad version: $release->{version}" unless $release->{version} =~ /\A5\.\d+\.\d+\Z/;

  my $patch;
  $release->{type} ||= 'bz2';
  my $file = "perl-$release->{version}.tar.$release->{type}";
  my $url  = "https://www.cpan.org/src/5.0/$file";
  if (-f "downloads/$file" && `sha256sum downloads/$file` =~ /^\Q$release->{sha256}\E\s+\Qdownloads\/$file\E/) {
    print "Skipping download of $file, already current\n";
  }
  else {
    print "Downloading $url\n";
    getstore($url, "downloads/$file") or die "failed";
  }
  {
    my $dir = "downloads/perl-$release->{version}";
    qx{rm -fR $dir};
    mkdir $dir or die "Couldn't create $dir";
    qx{
      tar -C "downloads" -axf $dir.tar.$release->{type} &&\
      cd $dir &&\
      find . -exec chmod u+w {} + &&\
      git init &&\
      git add . &&\
      git commit -m tmp
    };
    die "Couldn't create a temp git repo for $release->{version}" if $? != 0;
    Devel::PatchPerl->patch_source($release->{version}, $dir);
    $patch = qx{
      cd $dir && git -c 'diff.mnemonicprefix=false' diff
    };
    die "Couldn't create a Devel::PatchPerl patch for $release->{version}" if $? != 0;
  }

  for my $build (keys %builds) {
    $release->{url}             = $url;
    $release->{"cpanm_dist_$_"} = $cpanm{$_} for keys %cpanm;

    $release->{extra_flags}    ||= '';

    $release->{image} = 'debian';

    for my $debian_release (@{$release->{debian_release}}) {

      my $output = $template;
      $output =~ s/\{\{$_\}\}/$release->{$_}/mg
        for (qw(version pause extra_flags sha256 type url image cpanm_dist_name cpanm_dist_url cpanm_dist_sha256));
      $output =~ s/\{\{args\}\}/$builds{$build}/mg;

        $output =~ s/\{\{docker_slim_run_install\}\}/$docker_slim_run_install/mg;
        $output =~ s/\{\{docker_slim_run_purge\}\}/$docker_slim_run_purge/mg;
	$output =~ s/\{\{tag\}\}/$debian_release/mg;

      my $dir = sprintf "%i.%03i.%03i-%s-%s", ($release->{version} =~ /(\d+)\.(\d+)\.(\d+)/), $build, $debian_release;

      mkdir $dir unless -d $dir;

      # Set up the generated DevelPatchPerl.patch
      {
        open my $fh, ">", "$dir/DevelPatchPerl.patch";
        print $fh $patch;
      }

      $release->{run_tests} //= "parallel";
      if ($release->{run_tests} eq "serial") {
        $output =~ s/\{\{test\}\}/make test_harness/;
      }
      elsif ($release->{run_tests} eq "parallel") {
        $output =~ s/\{\{test\}\}/TEST_JOBS=\$(nproc) make test_harness/;
      }
      elsif ($release->{run_tests} eq "no") {
        # https://metacpan.org/pod/Devel::PatchPerl#CAVEAT
        $output =~ s/\{\{test\}\}/LD_LIBRARY_PATH=. .\/perl -Ilib -de0/;
        # https://metacpan.org/pod/distribution/perl/INSTALL#Building-a-shared-Perl-library
      }
      else {
        die "run_tests was provided for $release->{version} but is invalid; should be 'parallel', 'serial', or 'no'\n";
      }

      open my $dockerfile, ">", "$dir/Dockerfile" or die "Couldn't open $dir/Dockerfile for writing";
      print $dockerfile $output;
      close $dockerfile;
    }
  }
}

=pod

=head1 NAME

generate.pl - generate Dockerfiles for Perl

=head1 SYNOPSIS

    cd /path/to/docker-perl
    ./generate.pl

=head1 DESCRIPTION

generate.pl is meant to be run from the actual repo directory, with a
config.yml file correctly configured.  It contains with a 'releases'
key, which contains a list of releases, each with the following keys:

=over 4

=item REQUIRED

=over 4

=item version

The actual perl version, such as B<5.20.1>.

=item sha256

The SHA-256 of the tarball for that release.

=back

=item OPTIONAL

=over 4

=item debian_release

The Docker image tag which this Perl would build on, common to both the
L<buildpack-deps|https://hub.docker.com/_/buildpack-deps> and
L<debian|https://hub.docker.com/_/debian> Docker images.

This should be a list of tags for different Debian versions:

    - version: 5.30.0
      type:    xz
      debian_release:
        - bullseye
        - buster

C<-slim> will be appended to this value for C<slim> builds.

=item extra_flags

Additional text to pass to C<Configure>.  At the moment, this is
necessary for 5.18.x so that it can get the C<-fwrapv> flag.

Default: C<"">

=item run_tests

This can be 'parallel' (default), 'serial', or 'no'.

Added due to dist/IO/t/io_unix.t failing when TEST_JOBS > 1, but should
only be used in case of a documented issue or old release (see
L<Devel::PatchPerl's CAVEAT|https://metacpan.org/pod/Devel::PatchPerl#CAVEAT>).

Default: C<yes>

=back

=back

=cut

__DATA__
FROM {{image}}:{{tag}}-backports
LABEL maintainer="Ryan Voots <simcop@cpan.org>"

COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

ENV DEBIAN_FRONTEND=noninteractive

RUN perl -i.bak -pE '$x=$_; $x=~s|^deb |deb-src |g;$_.=$x' /etc/apt/sources.list \
    && apt update \
    && apt -yq full-upgrade \
    && apt -yq build-dep perl \
    && {{docker_slim_run_install}} \
    && curl -SL {{url}} -o perl-{{version}}.tar.{{type}} \
    && echo '{{sha256}} *perl-{{version}}.tar.{{type}}' | sha256sum -c - \
    && tar --strip-components=1 -xaf perl-{{version}}.tar.{{type}} -C /usr/src/perl \
    && rm perl-{{version}}.tar.{{type}} \
    && cat *.patch | patch -p1 \
    && echo 'print "1..0 # Skipped: Tests are invalid"' > /usr/src/perl/ext/GDBM_File/t/fatal.t \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && archBits="$(dpkg-architecture --query DEB_BUILD_ARCH_BITS)" \
    && archFlag="$([ "$archBits" = '64' ] && echo '-Duse64bitall' || echo '-Duse64bitint')" \
    && ./Configure -Darchname="$gnuArch" "$archFlag" {{args}} {{extra_flags}} -des \
    && make -j$(nproc) \
    && {{test}} \
    && make install \
    && cd /usr/src \
    && curl -LO {{cpanm_dist_url}} \
    && echo '{{cpanm_dist_sha256}} *{{cpanm_dist_name}}.tar.gz' | sha256sum -c - \
    && tar -xzf {{cpanm_dist_name}}.tar.gz && cd {{cpanm_dist_name}} && perl bin/cpanm . && cd /root \
    && {{docker_slim_run_purge}} \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /usr/src/{{cpanm_dist_name}}* /tmp/*

WORKDIR /

CMD ["perl{{version}}","-de0"]
