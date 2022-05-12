requires 'Devel::PatchPerl';
requires 'YAML::XS';

on 'develop' => sub {
    requires 'Perl::Tidy';
};

requires 'LWP::Simple';
requires 'LWP::Protocol::https';
