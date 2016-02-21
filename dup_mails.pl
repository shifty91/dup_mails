#!/usr/bin/env perl
#
# Time-stamp: <2016-02-21 18:18:23 kurt>
#
# dup_mails.pl -- Script to find and remove duplicates mails in a Maildir.
#
# Copyright (c) 2016, Kurt Kanzenbach <kurt@kmk-computers.de>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

use strict;
use warnings;
use Digest::SHA qw(sha1_hex);
use Getopt::Long;

# config options
my ($maildir, $body, $msgids, $force, $printonly, $verbose, $version, $help);

# statistics
my ($mails_processed, $duplicates_found, $duplicates_removed) = (0, 0, 0);

# data
my (%data);

sub vprint
{
    my ($msg) = @_;

    chomp $msg;
    print qq{$msg\n} if $verbose;

    return;
}

sub kurt_err
{
    my ($msg) = @_;
    my (undef, $file, $line, undef) = caller(0);

    chomp $msg;
    print STDERR "[ERROR $file:$line]: $msg\n";

    exit -1;
}

sub print_usage_and_die
{
    print STDERR << "EOF";
$0 [options] <Maildir>
Options:
  -b, --body      : Compare mailbodies for finding duplicates
  -m, --messageids: Compare message ids for finding duplicates
  -f, --force     : Remove duplicate mails
  -p, --printonly : Print deplicates to STDOUT (default behaviour)
  -v, --verbose   : Enable verbose logging
  -h, --help      : Print this help text
  --version       : Print the version information
Force and printonly cannot be used together! Just use one of them.
The same holds true for body and messageids.
EOF

    exit -1;
}

sub print_version_and_die
{
    print STDERR << "EOF";
$0 -- Find and remove duplicates mails in Maildir
Version: 1.0
(C) 2016 Kurt Kanzenbach <kurt\@kmk-computers.de>
EOF

    exit -1;
}

sub get_args
{
    GetOptions("body"       => \$body,
               "messageids" => \$msgids,
               "force"      => \$force,
               "printonly"  => \$printonly,
               "verbose|v"  => \$verbose,
               "help",      => \$help,
               "version"    => \$version) || print_usage_and_die();
    ($maildir) = @ARGV;
    print_usage_and_die()   if defined $help;
    print_version_and_die() if defined $version;
    print_usage_and_die()   unless defined $maildir;
    print_usage_and_die()   if defined $printonly && defined $force;
    print_usage_and_die()   if defined $body && defined $msgids;

    return;
}

sub index_files
{
    my ($dir) = @_;
    my ($dh, $entry);

    vprint qq{Processing directory '$dir'...\n};
    opendir($dh, $dir) or kurt_err(qq{Failed to open directory '$dir': $!});
    while ($entry = readdir $dh) {
        my ($fh, $file, $hash);

        $file = $dir . q{/} . $entry;
        next if $entry =~ /^\./xms;
        index_files($file) if -d $file;
        next unless -f $file;

        # switch: hash body vs. msg id
        message_id($file) if $msgids;
        hash_body($file)  if $body;
        ++$mails_processed;
    }
    closedir $dh;

    return;
}

sub hash_body
{
    my ($file) = @_;
    my ($fh, $line, $line_old, $hash);

    open($fh, q{<}, $file) or kurt_err(qq{Failed to open file '$file': $!});
    # skip header
    $line_old = "";
    while ($line = <$fh>) {
        last if (($line     eq qq{\n} || $line     eq qq{\r\n}) &&
                 ($line_old eq qq{\n} || $line_old eq qq{\r\n}));
        $line_old = $line;
    }
    # hash body
    $hash = sha1_hex(do { local $/ = undef; <$fh>; });
    close $fh;

    $data{$hash} = () unless exists $data{$hash};
    push @{ $data{$hash} }, $file;
    ++$duplicates_found if @{ $data{$hash} } > 1;

    return;
}

sub message_id
{
    my ($file) = @_;
    my ($fh, $line);

    open($fh, q{<}, $file) or kurt_err(qq{Failed to open file '$file': $!});
    while ($line = <$fh>) {
        my ($id);

        if (($id) = $line =~ /^Message-ID:\s*<(.*?)>$/xmsi) {
            $data{$id} = () unless exists $data{$id};
            push @{ $data{$id} }, $file;
            ++$duplicates_found if @{ $data{$id} } > 1;
            last;
        }
    }
    close $fh;

    return;
}

sub print_duplicates
{
    foreach my $item (keys %data) {
        print "Duplicates: " . join(q{ }, @{ $data{$item} }) . qq{\n} if @{ $data{$item} } > 1;
    }

    return;
}

sub remove_duplicates
{
    foreach my $item (keys %data) {
        my ($num) = scalar @{ $data{$item} };

        next unless $num > 1;

        # keep first mail
        for my $i (1..$num-1) {
            my ($file) = ($data{$item}->[$i]);
            unlink $file or kurt_err(qq{Removal of file '$file' failed: $!});
            ++$duplicates_removed;
            vprint qq{Removed mail '$file'};
        }
    }

    return;
}

sub print_statistics
{
    print q{-} x 80 . qq{\n};
    print qq{Mails processed: $mails_processed
Duplicates found: $duplicates_found
Duplicates remove: $duplicates_removed\n};
    print q{-} x 80 . qq{\n};

    return;
}

sub main
{
    get_args();
    index_files($maildir);
    print_duplicates()  if $printonly;
    remove_duplicates() if $force;
    print_statistics();

    return;
}

main();

exit 0;

__END__

=pod

=head1 NAME

dup_mail.pl - Find and remove duplicate mails in Maildir

=head1 DESCRIPTION

This script can be used to find and remove duplicate emails in a Maildir. This
script currently uses two mechanisms to find duplicates. The first one uses the
message id and the second compares the mail bodies. For a full list of the
options, run: dup_mails.pl --help.

Examples:

1. Find duplicates via Message-Id header (-> will be printed to stdout)

    ./dup_mails -p -m ~/Maildir

2. Remove duplicates via message body (-> better make a backup before)

    ./dup_mails -v -f -m ~/Maildir

=head1 AUTHOR

Kurt Kanzenbach <kurt@kmk-computers.de>

=head1 LICENSE

BSD 2-clause

=cut
