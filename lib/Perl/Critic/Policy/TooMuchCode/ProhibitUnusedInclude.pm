package Perl::Critic::Policy::TooMuchCode::ProhibitUnusedInclude;

use strict;
use warnings;
use Scalar::Util qw(refaddr);
use Perl::Critic::Utils;
use parent 'Perl::Critic::Policy';

sub default_themes       { return qw( maintenance )     }
sub applies_to           { return 'PPI::Document' }

#---------------------------------------------------------------------------


## This mapping fines a set of modules with behaviour that introduce
## new words as subroutine names or method names when they are `use`ed
## without argumnets.

use constant IMPORT_IMPLICIT => {
    'Data::Dumper'   => ['Dumper'],
    'Encode'         => [qw(decode  decode_utf8  encode  encode_utf8 str2bytes bytes2str encodings  find_encoding clone_encoding)],
    'File::Which'    => ['which'],
    'HTTP::Date'     => [qw(time2str str2time)],
    'JSON::PP'       => [qw(encode_json decode_Json)],
    'JSON::XS'       => [qw(encode_json decode_json)],
    'MIME::Base64'   => [qw(encode_base64 decode_base64)],
    'Module::Spy'    => ['spy_on'],
    'Path::Tiny'     => ['path'],
    'Plack::Builder' => [qw(builder mount)],
    'Smart::Args'    => [qw(args args_pos)],
    'Test::More'     => [qw(ok use_ok require_ok is isnt like unlike is_deeply cmp_ok skip todo todo_skip pass fail eq_array eq_hash eq_set $TODO plan done_testing can_ok isa_ok new_ok diag note explain subtest BAIL_OUT)],
    'Test::Time'     => [qw(time sleep)],
    'Time::Piece'    => [qw(localtime gmtime)],
    'Time::Seconds'  => [qw(ONE_MINUTE ONE_HOUR ONE_DAY ONE_WEEK ONE_MONTH ONE_YEAR ONE_FINANCIAL_MONTH LEAP_YEAR NON_LEAP_YEAR)],
    'Try::Tiny'      => [qw(try catch finally)],
    'URI::Escape'    => [qw(uri_escape uri_unescape uri_escape_utf8)],
    'URI::QueryParam' => [qw(query_param)],
    'Test::Exception' => [qw(dies_ok lives_ok throws_ok lives_and)],
};

sub violates {
    my ( $self, $elem, $doc ) = @_;

    my @includes = grep {
        !$_->pragma && $_->module && $_->module !~ /\A Mo([ou](?:se)?)? (\z|::)/x
    } @{ $doc->find('PPI::Statement::Include') ||[] };
    return () unless @includes;

    my %uses;
    $self->gather_uses_try_family(\@includes, $doc, \%uses);
    $self->gather_uses_objective(\@includes, $doc, \%uses);
    $self->gather_uses_generic(\@includes, $doc, \%uses);

    return map {
        $self->violation(
            "Unused include: " . $_->module,
            "A module is `use`-ed but not really consumed in other places in the code",
            $_
        )
    } grep {
        ! $uses{refaddr($_)}
    } @includes;
}

sub gather_uses_generic {
    my ( $self, $includes, $doc, $uses ) = @_;

    my @words = grep { ! $_->statement->isa('PPI::Statement::Include') } @{ $doc->find('PPI::Token::Word') || []};
    my @mods = map { $_->module } @$includes;

    my @inc_without_args;
    for my $inc (@$includes) {
        if ($inc->arguments) {
            my $r = refaddr($inc);
            $uses->{$r} = -1;
        } else {
            push @inc_without_args, $inc;
        }
    }

    for my $word (@words) {
        for my $inc (@inc_without_args) {
            my $mod = $inc->module;
            my $r   = refaddr($inc);
            next if $uses->{$r};
            $uses->{$r} = 1 if $word->content =~ /\A $mod (\z|::)/x;
            $uses->{$r} = 1 if grep { $_ eq $word } @{IMPORT_IMPLICIT->{$mod} ||[]};
        }
    }
}

sub gather_uses_try_family {
    my ( $self, $includes, $doc, $uses ) = @_;

    my %is_try = map { $_ => 1 } qw(Try::Tiny Try::Catch Try::Lite TryCatch Try);
    my @uses_tryish_modules = grep { $is_try{$_->module} } @$includes;
    return unless @uses_tryish_modules;

    my $has_try_block = 0;
    for my $try_keyword (@{ $doc->find(sub { $_[1]->isa('PPI::Token::Word') && $_[1]->content eq 'try' }) ||[]}) {
        my $try_block = $try_keyword->snext_sibling or next;
        next unless $try_block->isa('PPI::Structure::Block');
        $has_try_block = 1;
        last;
    }
    return unless $has_try_block;

    $uses->{refaddr($_)} = 1 for @uses_tryish_modules;
}

sub gather_uses_objective {
    my ( $self, $includes, $doc, $uses ) = @_;

    my %is_objective = map { ($_ => 1) } qw(HTTP::Tiny HTTP::Lite LWP::UserAgent File::Spec);
    for my $inc (@$includes) {
        my $mod = $inc->module;
        next unless $is_objective{$mod} && $doc->find(
            sub {
                my $el = $_[1];
                $el->isa('PPI::Token::Word') && $el->content eq $mod && !($el->parent->isa('PPI::Statement::Include'))
            }
        );

        $uses->{ refaddr($inc) } = 1;
    }
}

1;

=encoding utf-8

=head1 NAME

TooMuchCode::ProhibitUnusedInclude -- Find unused include statements.

=head1 DESCRIPTION

This critic policy scans for unused include statement according to their documentation.

For example, L<Try::Tiny> implicity introduce a C<try> subroutine that takes a block. Therefore, a
lonely C<use Try::Tiny> statement without a C<try { .. }> block somewhere in its scope is considered
to be an "Unused Include".

=cut
