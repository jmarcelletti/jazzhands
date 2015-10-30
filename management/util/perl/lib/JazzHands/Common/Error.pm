#
# Copyright (c) 2012-2013 Matthew Ragan
# Copyright (c) 2012-2015 Todd Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package JazzHands::Common::Error;

use strict;
use warnings;

use Exporter 'import';

our $VERSION = '1.0';

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(SetError );

our %EXPORT_TAGS = ( 'all' => [qw(SetError)], );

#
# This is used external to JazzHands and thus can't really change
# It is used internally to these libraries in a few places to handle cases
# where calls are bath both inside and not inside this library
#
sub SetError {
	my $error = shift;

	if ( ref($error) eq "ARRAY" ) {
		push @{$error}, @_;
		return;
	}

	if ( ref($error) eq "SCALAR" ) {
		$$error = shift;
		return;
	}
}

#
# everything after this is not exported but part of the module
#

#
# tacks all arguments on to the end of the internal error array
#
sub Error {
	my $self = shift @_;

	SetError( $self->{_errors}, @_ );
	if(wantarray) {
		return @{$self->{_errors}};
	} else {
		return join("\n", @{$self->{_errors}});
	}
}

#
# passes arguments through sprintf, and tacks them onto the end of the internal
# error system
#
sub ErrorF { 
	my $self = shift;

	my $str;
	if (@_) {
		my $fmt = shift;
		if (@_) {
			$str = sprintf( $fmt, @_ );
		} else {
			$str = $fmt;
		}
	}
	return $self->Error($str);
}

1;

__END__


=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FILES


=head1 AUTHORS

=cut

