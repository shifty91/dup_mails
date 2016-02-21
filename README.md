# Dup-Mails #

## About ##

Ever had to find duplicate mails in your Maildir? This Perl script does exactly
this. It can be used to find and remove duplicate mails inside a Maildir.

## Usage ##

    ./dup_mails.pl [options] <Maildir>
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

Example: Find duplicates via Message-Id header:

    $ ./dup_mails -m -p ~/Maildir

Example: Remove duplicate mails via message body (*make backup before*):

    ./dup_mails -v -f -b ~/Maildir

## Author ##

(C) Kurt Kanzenbach 2016 <kurt@kmk-computers.de>

## License ##

BSD 2-clause
