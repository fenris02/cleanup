#!/usr/bin/perl -w
##############################################################################
# $Id: ldapcat,v 1.2 2002/02/22 00:41:31 jheiss Exp $
##############################################################################
# Search LDAP for users or groups and print them out in standard UNIX
# format.
#
# TODO:
# - Allow user to specify options to ldapsearch, like -x
##############################################################################
# $Log: ldapcat,v $
# Revision 1.2  2002/02/22 00:41:31  jheiss
# Made Base64 decoding optional.
# Don't print out full entry for KERBEROS type passwords, just a marker.
#
# Revision 1.1  2002/02/09 03:24:50  jheiss
# Initial revision
#
##############################################################################

# Includes and such
use strict;

# Constants
# Set the following to true to have any Base64 encoded fields decoded.
# Requires that you have the MIME::Base64 module from CPAN.
my $DECODE_BASE64 = 1;    # 1 for yes, 0 for no

sub usage
{
    die "Usage: $0 {passwd|group}\n";
}

if (scalar @ARGV == 0)
{
    usage();
}

my %entries;
my $entry;
my @elements;

if ($ARGV[0] eq 'passwd')
{
    open(LS,
             "ldapsearch -LLL '(objectClass=posixAccount)' uid userPassword "
           . "uidNumber gidNumber cn homeDirectory loginShell |"
        )
      || die "Failed to run ldapsearch";

    #open(LS, "ldapsearch -x -LLL '(objectClass=posixAccount)' uid " .
    #"userPassword uidNumber gidNumber cn homeDirectory loginShell |") ||
    #die "Failed to run ldapsearch";
} elsif ($ARGV[0] eq 'group')
{
    open(LS,
             "ldapsearch -LLL '(objectClass=posixGroup)' cn userPassword "
           . "gidNumber memberUid |"
        )
      || die "Failed to run ldapsearch";

    #open(LS, "ldapsearch -x -LLL '(objectClass=posixGroup)' cn userPassword " .
    #"gidNumber memberUid |") ||
    #die "Failed to run ldapsearch";
} else
{
    usage();
}

while (<LS>)
{
    #print "line:  '$_'\n";

    if (/^dn: /)
    {
        if ($ARGV[0] eq 'passwd')
        {
            /dn: uid=(\w+),/;
            $entry = $1;
        } elsif ($ARGV[0] eq 'group')
        {
            /dn: cn=(\w+),/;
            $entry = $1;
        }

        if (!$entry)
        {
            $entry = 'bogus';
        }
    } else
    {
        chomp;

        /^(\w+):/;
        if ($1)
        {
            my $field = $1;

            #print "Field line:  $_\n";
            #print "Field:  $field\n";

            # Take off the field label
            $_ =~ s/^[[:alpha:]]+://;

            #print "Stripped:  '$_'\n";

            # Check to see if the entry was encoded
            if (/^: /)
            {
                #print "Encoded field $field\n";
                $_ =~ s/^: //;
                if ($DECODE_BASE64)
                {
                    require MIME::Base64;
                    $_ = MIME::Base64::decode_base64($_);
                }
            } else
            {
                $_ =~ s/^ //;
            }

            # The userPassword field looks like:  {type}password
            if ($field eq 'userPassword')
            {
                /^{(\w+)}(.*)/;
                my $passtype = $1;
                my $password = $2;

                #print "passtype:  $1\n";
                #print "password:  $2\n";

                if ($passtype eq 'crypt')
                {
                    $_ = $2;
                } elsif ($passtype eq 'KERBEROS')
                {
                    $_ = '*K*';
                } else
                {
                    # Let other types pass through since I don't know what
                    # else is possible
                }
            }

            # There can be multiple members in a group
            if ($field eq 'memberUid')
            {
                push(@{$entries{$entry}->{$field}}, $_);
            } else
            {
                $entries{$entry}->{$field} = $_;
            }
        }
    }
}
close(LS);

if ($ARGV[0] eq 'passwd')
{
    foreach my $user (sort keys %entries)
    {
        print "$user:";
        print $entries{$user}->{'userPassword'} . ":";

        #print "x:";  # Fake password
        print $entries{$user}->{'uidNumber'} . ":";
        print $entries{$user}->{'gidNumber'} . ":";
        print $entries{$user}->{'cn'} . ":";
        print $entries{$user}->{'homeDirectory'} . ":";
        print $entries{$user}->{'loginShell'} . "\n";
    }
} elsif ($ARGV[0] eq 'group')
{
    foreach my $group (sort keys %entries)
    {
        print "$group:";
        print $entries{$group}->{'userPassword'} . ":";

        #print "*:";  # Fake password
        print $entries{$group}->{'gidNumber'} . ":";
        print join(',', @{$entries{$group}->{'memberUid'}}) . "\n";
    }
}

