# --
# Kernel/Modules/AdminPerformanceLog.pm - provides a log view for admins
# Copyright (C) 2001-2006 OTRS GmbH, http://otrs.org/
# --
# $Id: AdminPerformanceLog.pm,v 1.1 2006-08-24 07:15:16 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Modules::AdminPerformanceLog;

use strict;

use vars qw($VERSION);
$VERSION = '$Revision: 1.1 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;


sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    foreach (keys %Param) {
        $Self->{$_} = $Param{$_};
    }

    # check needed Opjects
    foreach (qw(ParamObject LayoutObject LogObject ConfigObject)) {
        if (!$Self->{$_}) {
            $Self->{LayoutObject}->FatalError(Message => "Got no $_!");
        }
    }

    return $Self;
}

sub Run {
    my $Self = shift;
    my %Param = @_;
    # get avarage times
    my @Data = ();
    if ($Self->{ConfigObject}->Get('PerformanceLog')) {
        my $File = $Self->{ConfigObject}->Get('PerformanceLog::File');
        if (open(IN, "< $File")) {
            while (<IN>) {
                my $Line = $_;
                my @Row = split(/::/, $Line);
                push (@Data, \@Row);
#                if ($Row[0] > time()-(60*60*24)) {
#                    last;
#                }
            }
            close (IN);
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message => "Can't open $File: $!",
            );
        }
    }
    foreach my $Minute (5, 30, 60, 2*60, 24*60) {
        my %Count = ();
        my %Sum = ();
        my %Max = ();
        my %Min = ();
        foreach my $Row (reverse @Data) {
            if ($Row->[0] > time()-(60*$Minute)) {
                $Count{$Row->[1]}++;
                $Sum{$Row->[1]} = $Sum{$Row->[1]} + $Row->[2];
                if (!defined($Max{$Row->[1]})) {
                    $Max{$Row->[1]} = $Row->[2];
                }
                elsif ($Max{$Row->[1]} < $Row->[2]) {
                    $Max{$Row->[1]} = $Row->[2];
                }
                if (!defined($Min{$Row->[1]})) {
                    $Min{$Row->[1]} = $Row->[2];
                }
                elsif ($Min{$Row->[1]} > $Row->[2]) {
                    $Min{$Row->[1]} = $Row->[2];
                }
            }
            else {
                last;
            }
        }
        if (%Sum) {
            $Self->{LayoutObject}->Block(
                Name => 'Table',
                Data => {
                    Age => $Self->{LayoutObject}->CustomerAge(Age => $Minute*60, Space => ' '),
                },
            );
        }
        foreach (qw(Agent Customer Public)) {
            if ($Sum{$_}) {
                my $Average = $Sum{$_} / $Count{$_};
                $Average =~ s/^(.*\.\d\d).+?$/$1/g;
                $Self->{LayoutObject}->Block(
                    Name => 'Row',
                    Data => {
                        Interface => $_,
                        Average => $Average,
                        Count => $Count{$_} || 0,
                        Sum => $Sum{$_} || 0,
                        Max => $Max{$_} || 0,
                        Min => $Min{$_} || 0,
                    },
                );
            }
        }
    }
    # create & return output
    my $Output = $Self->{LayoutObject}->Header();
    $Output .= $Self->{LayoutObject}->NavigationBar();
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminPerformanceLog',
        Data => \%Param,
    );
    $Output .= $Self->{LayoutObject}->Footer();
    return $Output;
}
# --
1;
