#
# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# Copyright (c) 2013 Todd Kover, Matthew Ragan
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

package JazzHands::STAB::DBAccess;

use 5.008007;
use strict;
use warnings;

use Data::Dumper;
use JazzHands::DBI;
use JazzHands::Common::Util qw(:all);
use JazzHands::Mgmt;
use URI;
use Carp;
use Math::BigInt;

use Apache2::Log;
use Apache2::Const -compile => qw(OK :log);
use APR::Const -compile     => qw(:error SUCCESS);

our @ISA = qw( JazzHands::Common );

our $VERSION = '1.0.0';

# Preloaded methods go here.

#sub rollback {
#	my ($self) = @_;
#	my $dbh = $self->dbh;
#	$dbh->rollback;
#}
#
#sub commit {
#	my ($self) = @_;
#	my $dbh = $self->dbh;
#	$dbh->commit;
#}

sub prepare {
	my ( $self, $q ) = @_;

	my $dbh = $self->dbh;

	if ( !$self->{_jhSth} ) {
		$self->{_jhSth} = {};
	}

	if ( !defined( $self->{_jhSth}->{$q} ) ) {
		$self->{_jhSth}->{$q} = $dbh->prepare_cached($q)
		  || return undef;
	}
	$self->{_jhSth}->{$q}->finish;
	$self->{_jhSth}->{$q};
}

sub prepare_cached {
	my $self = shift @_;
	$self->prepare(@_);
}

#
# delete netblock
#
sub delete_netblock {
	my ( $self, $id ) = @_;

	my $q = q{
		delete from netblock where netblock_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id) || $self->return_db_err($sth);
	$sth->finish;
}

#
# different from other implementations
#
sub guess_parent_netblock_id {
	my ( $self, $in_ip, $in_bits ) = @_;

	# select is needed for postgres 9.1 to optimize right.
	my $q = qq {
		select  Netblock_Id,
			net_manip.inet_dbtop(ip_address) as IP,
			ip_address,
			netmask_bits
		  from  netblock
		  where	netblock_id in (
			SELECT netblock_utils.find_best_parent_id(
				net_manip.inet_ptodb(:ip), :bits, 'default', 
				0, 'Y')
			)
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->bind_param( ':ip',   $in_ip )   || die $sth->errstr;
	$sth->bind_param( ':bits', $in_bits ) || die $sth->errstr;
	$sth->execute || $self->return_db_err($sth);
	my $rv = $sth->fetchrow_hashref;
	$sth->finish;
	$rv;
}

sub get_interface_from_ip {
	my ( $self, $ip ) = @_;

	my $sth = $self->prepare(
		qq{
		select	ni.*
		  from	network_interface ni
		 		inner join netblock nb
					on nb.netblock_id = ni.netblock_id
		 where	net_manip.inet_ptodb(?) = nb.ip_address
	}
	);
	$sth->execute($ip) || $self->return_db_err($sth);
	my $rv = $sth->fetchrow_hashref;
	$sth->finish;
	$rv;

}

sub check_ip_on_local_nets {
	my ( $self, $devid, $ip ) = @_;

	my $sth = $self->prepare(
		qq{
		select  count(*)
		  from  network_interface ni
			inner join netblock nb on
				ni.netblock_id = nb.netblock_id
		where
			ni.device_id = ?
		 and
			net_manip.inet_base(net_manip.inet_ptodb(?), nb.netmask_bits) =
				net_manip.inet_base(nb.ip_address, nb.netmask_bits)
	}
	);

	$sth->execute( $devid, $ip ) || $self->return_db_err($sth);
	my ($count) = $sth->fetchrow_array;
	$sth->errstr;
	$count;

}

sub get_netblock_from_id {
	my ( $self, $nblkid, $singnocare, $orgnocare ) = @_;

	return undef if ( !defined($nblkid) );

	my $singq = "";
	if ( !defined($singnocare) ) {
		$singq = "and is_single_address = 'Y'";
	}

	my $orgq = "";

	# XXX - need to deal with better as far as types go
	if ( !defined($orgnocare) ) {
		$orgq = "and netblock_type != 'default'";
	} else {
		$orgq = "and netblock_type = 'default'";
	}

	my $q = qq{
		select  netblock.*,
                	net_manip.inet_dbtop(ip_address) as ip
		 from   netblock
		where   netblock_id = ?
		  	$orgq
		  	$singq
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($nblkid) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	return $hr;
}

sub add_netblock {
	my $self = shift @_;
	my $opts = _options(@_);

	# The parent netblock id is handled automatially by triggers
	# most of the time, so no need to do so.
	#my $parid;
	#if ($parnb) {
	#	$bits = $parnb->{ _dbx('NETMASK_BITS') } if ( !$bits );
	#	$parid = $parnb->{ _dbx('NETBLOCK_ID') };
	#}
	#
	#if ( !$bits ) {
	#	return undef;
	#}

	# XXX need to deal with more smartly  -- $isorg!!
	#my $type = 'default';
	#if ( $isorg eq 'Y' ) {
	#	return undef;
	#}

	# these are defaults...
	my $new = {
		ip_address => $opts->{ip_address},
		netblock_type => 'default',
		ip_universe_id => 0,
		netblock_status => 'Allocated',
	};

	for my $f (
			'netmask_bits',
			'netblock_type',
			'is_ipv4_address',
			'is_single_address',
			'can_subnet',
			'parent_netblock_id',
			'netblock_status',
			'nic_id',
			'nic_company_id',
			'ip_universe_id',
			'description',
			'reservation_ticket_number',
			) {
		if(exists($opts->{$f})) {
			$new->{$f} = $opts->{$f};
		}
	}

	if(!defined($new->{can_subnet})) {
		if($new->{is_single_address} eq 'Y') {
			$new->{can_subnet} = 'N';
		} else {
			$new->{can_subnet} = 'Y';
		}
	}

	if(!defined($new->{is_ipv4_address})) {
		if($new->{ip_address} =~ /:/) {
			$new->{is_ipv4_address} = 'N';
		} else {
			$new->{is_ipv4_address} = 'Y';
		}
	}

	my @errs;
	my $numchanges;
	if(! ($numchanges = $self->DBInsert(
		table => 'netblock',
		hash => $new,
		errors => \@errs)
	)) {
		$self->error_return(join(" ", @errs));
	}

	return($new->{_dbx('NETBLOCK_ID')});
}

#############################################################################
# begin weird location stuff - XXX
#############################################################################

# cooked is to make it easier for having multiple things named things things.
# I almost certainly need to provide a generic translation routine and return
# something passed to that rather then the uncooked weirdness.  This was just
# a quick hack...  aren't they all?
#
sub get_rackid_from_params {
	my ( $self, $site, $room, $row, $rack ) = @_;

	my $q = qq{
		select 	rack_id
		  from  rack
		 where  site_code = ?
		  AND	room = ?
		  AND	rack_row = ?
		  AND	rack_name = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute( $site, $room, $row, $rack )
	  || $self->return_db_err($sth);
	my $id = $sth->fetchrow_arry;
	$sth->finish;
	$id;
}

sub get_rack_from_rackid {
	my ( $self, $rackid, $uncooked ) = @_;

	return undef if ( !$rackid );

	my $q = qq{
		select  *
		  from  rack
		 where  rack_id = ?
	};
	if ($uncooked) {
		$q =~ s/\s+as\s+[^,\s]+(,?\s*\n)/$1/gim;
	}
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($rackid) || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$self->fake_unset_location($hr);
}

sub get_location_from_devid {
	my ( $self, $devid, $uncooked ) = @_;

	my $q = qq{
		select
			l.LOCATION_ID,
			l.RACK_ID as LOCATION_RACK_ID,
			l.RACK_U_OFFSET_OF_DEVICE_TOP as LOCATION_RU_OFFSET,
			l.RACK_SIDE as LOCATION_RACK_SIDE,
			l.INTER_DEVICE_OFFSET as LOCATION_INTER_DEV_OFFSET,
			r.SITE_CODE as RACK_SITE_CODE
		  from  location l
			inner join device d on
				d.location_id = l.location_id
			inner join rack r on
				r.rack_id = l.rack_id
		 where  d.device_id = ?
	};
	if ($uncooked) {
		$q =~ s/\s+as\s+[^,\s]+(,?\s*\n)/$1/gim;
	}
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($devid) || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$self->fake_unset_location($hr);
}

#
# If any of the values are negative or n/a, they don't get displaed.
# It basically means they are unset in some fashion or filler records
# because we wanted to propogate just the location or some such.
#
sub fake_unset_location {
	my ( $self, $location ) = @_;

	return undef if ( !$location );

	foreach my $key ( keys %$location ) {
		$key = _dbx($key);
		next if ( $key =~ /^DATA/i );
		if ( $location->{$key} =~ /^[-\d]+$/ ) {
			if ( $location->{$key} < -10 ) {
				$location->{$key} = undef;
			}
		} elsif ( $location->{$key} eq 'n/a' ) {
			$location->{$key} = undef;
		}
	}
	$location;
}

#############################################################################
# end of weird location stuff
#############################################################################

sub create_physical_port {
	my ( $self, $devid, $name, $type, $desc ) = @_;

	my $ppid;
	my $q = qq {
		insert into physical_port (
			device_id, port_name, port_type, description
		) values (
			:devid, :name, :type, :descr
		) returning physical_port_id into :rv
	};
	my $sth = $self->prepare($q) || die $self->return_db_err($self);
	$sth->bind_param( ":devid", $devid ) || $self->return_db_err($sth);
	$sth->bind_param( ":name",  $name )  || $self->return_db_err($sth);
	$sth->bind_param( ":type",  $type )  || $self->return_db_err($sth);
	$sth->bind_param( ":descr", $desc )  || $self->return_db_err($sth);
	$sth->bind_param_inout( ":rv", \$ppid, 500 )
	  || $self->return_db_err($sth);
	$sth->execute || $self->return_db_err($sth);
	$sth->finish;
	$ppid;
}

sub guess_dns_domain_from_devid {
	my ( $self, $device ) = @_;

	my $q = qq{
		select  dns_domain_id
		  from  dns_domain
		 where  soa_name = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);

	my $name = $device->{ _dbx('DEVICE_NAME') };
	while ( $name =~ s/^[^\.]+\.// ) {
		$sth->execute($name) || $self->return_db_err($sth);
		my ($domid) = $sth->fetchrow_array;
		$sth->finish;
		if ( defined($domid) ) {
			return $domid;
		}
	}
	undef;
}

sub get_dns_record_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select  dns_record_Id,
			dns_name,
			dns_domain_id,
			dns_ttl,
			dns_class,
			dns_type,
			dns_value,
			is_enabled,
			netblock_id
		 from   dns_record
		where   dns_record_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_dns_record_from_name {
	my ( $self, $shortname, $domid ) = @_;

	my $q = qq{
		select  dns_record_Id,
			dns_name,
			dns_domain_id,
			dns_ttl,
			dns_class,
			dns_type,
			dns_value,
			netblock_id
		 from   dns_record
		where   dns_name = ?
		 and	dns_domain_id = ?

	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute( $shortname, $domid ) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_dns_domain_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select  dns_domain_id,
			soa_name,
			soa_class,
			soa_ttl,
			soa_serial,
			soa_refresh,
			soa_retry,
			soa_expire,
			soa_minimum,
			soa_mname,
			soa_rname,
			parent_dns_domain_id,
			should_generate
		 from   dns_domain
		where   dns_domain_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_dns_domain_from_name {
	my ( $self, $name ) = @_;

	my $q = qq{
		select  dns_domain_id,
			soa_name,
			soa_class,
			soa_ttl,
			soa_serial,
			soa_refresh,
			soa_retry,
			soa_expire,
			soa_minimum,
			soa_mname,
			soa_rname,
			parent_dns_domain_id,
			should_generate
		 from   dns_domain
		where   soa_name = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($name) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_netblock_from_ip {
	my $self = shift(@_);
	my $opts = _options(@_);

	my @errors;
	my $args = {
		ip_address => $opts->{ip_address},
		netblock_type => 'default',
		single => 'first',
		errors => \@errors,
	};

	if($opts->{'netmask_bits'}) {
		$args->{'netmask_bits'} = $opts->{'netmask_bits'};
	}

	if($opts->{'is_single_address'}) {
		$args->{'is_single_address'} = 'Y';
	}

	if($opts->{'netblock_type'}) {
		$args->{'netblock_type'} = $opts->{'netblock_type'};
	}

	my $netblock = $self->GetNetblock( $args );

	if(!$netblock) {
		if(@errors) {
			$self->error_return("Netblock issue: ".join(';', @errors). "for ".$opts->{ip_address});
		}
		return undef;
	}

	my $h = $netblock->hash;
	if(!$h) {
		if(@errors) {
			$self->error_return("Netblock has hash issue: ".join(';', @errors));
		}
		return undef;
	}
	$h;
}

sub get_dev_from_devid {
	my ( $self, $devid ) = @_;

	my $q = qq{
		select  *
		  from  device
		 where  device_id = :devid
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->bind_param( ':devid', $devid ) || $self->return_db_err($sth);
	$sth->execute || $self->return_db_err($sth);

     # when putting this in, make sure that updates to devices don't touch these
     # fields.  I think it's smart, but make sure. -kovert [XXX]
     #			DATA_INS_USER, DATA_INS_DATE,
     #			DATA_UPD_USER, DATA_UPD_DATE

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub add_location_to_dev {
	my ( $self, $devid, $loc ) = @_;

	my $lq = qq{
	    insert into location (
			RACK_ID,
			RACK_U_OFFSET_OF_DEVICE_TOP,
			RACK_SIDE,
			INTER_DEVICE_OFFSET
	    ) values (
			:rackid,
			:ru,
			:rackside,
			:interu
	    ) returning LOCATION_ID into :locid
	};
	my $lsth = $self->prepare($lq) || $self->return_db_err($self);
	$lsth->bind_param( ':rackid', $loc->{ _dbx('RACK_ID') } )
	  || $self->return_db_err($lsth);
	$lsth->bind_param( ':ru',
		$loc->{ _dbx('RACK_U_OFFSET_OF_DEVICE_TOP') } )
	  || $self->return_db_err($lsth);
	$lsth->bind_param( ':rackside', $loc->{ _dbx('RACK_SIDE') } )
	  || $self->return_db_err($lsth);
	$lsth->bind_param( ':interu', $loc->{ _dbx('INTER_DEVICE_OFFSET') } )
	  || $self->return_db_err($lsth);
	my $locid;
	$lsth->bind_param_inout( ':locid', \$locid, 50 )
	  || $self->return_db_err($lsth);
	$lsth->execute || $self->return_db_err($lsth);

	my ($dq) = qq{
		update	device
		   set	location_id = :2
		  where	device_id = :1
	};
	my $dsth = $self->prepare($dq) || $self->return_db_err($dq);
	$dsth->execute( $devid, $locid ) || $self->return_db_err($dq);

	# 2 changes.
	2;
}

sub get_dev_from_name {
	my ( $self, $name ) = @_;

	my $q = qq{
		select  device_id, device_name,
			device_type_id, serial_number,
			asset_tag, operating_system_id,
			voe_id,
			status, production_state,
			ownership_status,
			is_monitored,
			is_locally_managed,
			identifying_dns_record_id,
			SHOULD_FETCH_CONFIG,
			PARENT_DEVICE_ID,
			IS_VIRTUAL_DEVICE,
			AUTO_MGMT_PROTOCOL
		  from  device
		 where  device_name = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($name) || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_dev_from_serial {
	my ( $self, $serno ) = @_;

	my $q = qq{
		select  device_id, device_name,
			device_type_id, serial_number,
			asset_tag, operating_system_id,
			voe_id,
			status, production_state,
			ownership_status,
			is_monitored,
			is_locally_managed,
			identifying_dns_record_id,
			SHOULD_FETCH_CONFIG,
			PARENT_DEVICE_ID,
			IS_VIRTUAL_DEVICE,
			AUTO_MGMT_PROTOCOL
		  from  device
		 where  lower(serial_number) = lower(?)
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($serno) || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_snmpcommstr_from_id {
	my ( $self, $snmpid ) = @_;

	my $q = qq{
		select  snmp_commstr_id,
			device_id,
			snmp_commstr_type,
			rd_string,
			wr_string,
			purpose
		  from  snmp_commstr
		 where  snmp_commstr_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($snmpid) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_snmpstr_count {
	my ( $self, $deviceid ) = @_;

	my $q = qq{
		select  count(*)
		  from  snmp_commstr
		 where  device_id = :devid
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->bind_param( ':devid', $deviceid ) || $self->return_db_err($sth);
	$sth->execute() || $self->return_db_err($sth);
	my $rv = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$rv;
}

sub ptr_exists {
	my ( $self, $id ) = @_;

	my $q = qq{
		select	count(*)
		  from	dns_record
		 where	netblock_id = ?
		   and	should_generate_ptr = 'Y'
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id) || $self->return_db_err($sth);
	my $tally = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$tally;
}

#
# Adds a dns record, basically a database hash passed in with some extra
# processing done to make it so not everywhere needs to think about it.
#
sub add_dns_record {
	my $self = shift @_;
	my $opts = shift @_;

	$opts = _dbx( $opts, 'lower' );

	if ( $opts->{dns_type} eq 'A' ) {
		$opts->{dns_value} = undef;
		if ( !$opts->{should_generate_ptr} ) {
			if ( $self->ptr_exists( $opts->{netblock_id} ) ) {
				$opts->{should_generate_ptr} = 'N';
			} else {
				$opts->{should_generate_ptr} = 'Y';
			}
		}
	} elsif ( $opts->{dns_type} eq 'REVERSE_ZONE_BLOCK_PTR' ) {
		$opts->{netblock_id} = $opts->{dns_value};
		$opts->{dns_value}   = undef;
	}

	if ( !$opts->{should_generate_ptr} ) {
		$opts->{should_generate_ptr} = 'N';
	}

	my @errs;
	if (
		!(
			$self->DBInsert(
				table  => 'dns_record',
				hash   => $opts,
				errors => \@errs
			)
		)
	  )
	{
		$self->error_return( join( " ", @errs ) );
	}
	return ( $opts->{ _dbx('dns_domain_id') } );
}

sub fetch_property {
	my ( $self, $type, $name ) = @_;

	my @errs;
	my $match = [
		{
			key   => 'property_name',
			value => $name,
		},
		{
			key   => 'property_type',
			value => $type,
		},
	];
	my $rows = $self->DBFetch(
		table  => 'property',
		match  => $match,
		errors => \@errs
	) || die $self->return_db_err();
	my $hr = $rows->[0];
	if ( $hr && defined( $hr->{property_value} ) ) {
		return $hr->{property_value};
	}
	return undef;
}

sub configure_allocated_netblock {
	my ( $self, $ip, $nblk ) = @_;

	my $parnb;
	if ( !defined($nblk) ) {
		$parnb = $self->guess_parent_netblock_id( $ip, 32 );

		# if the ip addres is 0/0 (or 0/anything), then it should
		# be considered unset
		if ( !defined($parnb) || ( !$parnb->{ _dbx('IP_ADDRESS') } ) ) {
			$self->error_return("Unable to find network for $ip");
		}
	} elsif ( $nblk->{ _dbx('NETBLOCK_STATUS') } eq 'Allocated' ) {
		$self->error_return("Address ($ip) is already allocated.");
	}

	# if netblock is reserved, switch it to allocated
	if (
		defined($nblk)
		&& (       $nblk->{ _dbx('NETBLOCK_STATUS') } eq 'Legacy'
			|| $nblk->{ _dbx('NETBLOCK_STATUS') } eq 'Reserved' )
	  )
	{
		my $q = qq{
			update	netblock
		       set	netblock_status = 'Allocated'
		 	 where	netblock_id = ?
		};
		my $sth = $self->prepare($q) || $self->return_db_err($self);
		$sth->execute( $nblk->{ _dbx('NETBLOCK_ID') } )
		  || $self->return_db_err($sth);
	} else {
		$nblk = $self->add_netblock(
			ip_address => $ip,
			parent_netblock_id => $parnb->{_dbx('PARENT_NETBLOCK_ID')}
		);
	}
	$nblk;
}

sub get_operating_system_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select  os.operating_system_id,
			c.company_name,
			os.company_id,
			os.name,
			os.version,
			os.processor_architecture
		  from  operating_system os
			inner join company c on
				c.company_id = os.company_id
		 where  os.operating_system_id = ?
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id) || $self->return_db_err($sth);
	my $os = $sth->fetchrow_hashref;
	$sth->finish;
	$os;
}

sub get_voe_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select  voe.voe_id,
			voe.voe_name,
			voe.sw_package_repository_id,
			voe.voe_state,
			spr.sw_repository_name as sw_package_repository_name,
			spr.description as sw_package_description,
			spr.apt_repository as apt_repository
		  from  VOE voe
			inner join sw_package_repository spr
				on spr.sw_package_repository_id =
					voe.sw_package_repository_id
		 where  voe.voe_id = ?

	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id) || $self->return_db_err($sth);
	my $voe = $sth->fetchrow_hashref;
	$sth->finish;
	$voe;
}

sub get_package_release {
	my ( $self, $id ) = @_;

	# add package_state_restriction
	#	pkg.package_state_restriction,
	# left join sw_package_repository
	my $q = qq{
	    select  pkgr.sw_package_release_id,
		pkg.sw_package_name, pkgr.sw_package_version, pkg.description
	      from  sw_package pkg
		    inner join sw_package_release pkgr
			    on pkgr.sw_package_id = pkg.sw_package_id
		    inner join voe_sw_package voeswp
			    on voeswp.sw_package_release_id =
				pkgr.sw_package_release_id
	     where  voeswp.sw_package_release_id = ?
	    order by pkg.sw_package_name
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id) || $self->return_db_err($sth);
	my $pkg = $sth->fetchrow_hashref;
	$sth->finish;
	$pkg;
}

sub get_device_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select * from device where device_id = ?
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id) || $self->return_db_err($sth);

	my $dt = $sth->fetchrow_hashref;
	$sth->finish;
	$dt;
}

sub get_device_type_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select  dt.DEVICE_TYPE_ID, c.company_name,
			-- p.address as partner_address, XXX
			c.company_id, dt.model,
			dt.config_fetch_type, dt.rack_units,
			dt.description,
			dt.has_802_3_interface,
			dt.has_802_11_interface,
			dt.processor_architecture,
			dt.snmp_capable
		  from  device_type dt
			inner join company c
				on dt.company_id = c.company_id
		where   dt.device_type_id = ?
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id) || $self->return_db_err($sth);

	my $dt = $sth->fetchrow_hashref;
	$sth->finish;
	$dt;
}

sub get_device_type_from_name {
	my ( $self, $companyid, $model ) = @_;

	my $q = qq{
		select  dt.DEVICE_TYPE_ID, c.company_name,
			-- p.address as partner_address, XXX
			dt.company_id, dt.model,
			dt.config_fetch_type, dt.rack_units,
			dt.description,
			dt.has_802_3_interface,
			dt.has_802_11_interface,
			dt.snmp_capable
		  from  device_type dt
			inner join company c
				on dt.company_id = c.company_id
		where   c.company_id = ?
		 AND	dt.model = ?
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute( $companyid, $model ) || $self->return_db_err($sth);

	my $dt = $sth->fetchrow_hashref;
	$sth->finish;
	$dt;
}

sub get_packages_for_voe {
	my ( $self, $voeid ) = @_;

	my $q = qq{
		select  p.sw_package_name,
			pr.sw_package_version as voe_version
		  from  sw_package p
			inner join sw_package_release pr
				on pr.sw_package_id = p.sw_package_id
			inner join voe_sw_package voe
				on pr.sw_package_release_id =
					voe.sw_package_release_id
		 where
			voe.voe_id = ?
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($voeid) || $self->return_db_err($sth);

	my (%pkgs);
	while ( my ( $pkg, $vers ) = $sth->fetchrow_array ) {
		$pkgs{$pkg} = $vers;
	}
	$sth->finish;
	\%pkgs;
}

sub get_dependancies_for_voe {
	my ( $self, $voeid ) = @_;

	my $q = qq{
		select  p.sw_package_name,
			pr.sw_package_version as voe_version
		  from  sw_package p
			inner join sw_package_release pr
				on pr.sw_package_id = p.sw_package_id
			inner join voe_sw_package voe
				on pr.sw_package_release_id =
					voe.sw_package_release_id
		 where
			voe.voe_id = ?
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($voeid) || $self->return_db_err($sth);

	my (%pkgs);
	while ( my ( $pkg, $vers ) = $sth->fetchrow_array ) {
		$pkgs{$pkg} = $vers;
	}
	$sth->finish;
	\%pkgs;
}

sub get_physical_path_from_l1conn {
	my ( $self, $l1conn ) = @_;

	my $q = qq{
		select	pc.PHYSICAL_CONNECTION_ID,
			pc.cable_type,
			p1.physical_port_id as pc_p1_physical_port_id,
			p1.port_name as pc_p1_physical_port_name,
			d1.device_id as pc_p1_device_id,
			d1.device_name as pc_p1_device_name,
			p2.physical_port_id as pc_p2_physical_port_id,
			p2.port_name as pc_p2_physical_port_name,
			d2.device_id as pc_p2_device_id,
			d2.device_name as pc_p2_device_name
		  from	physical_connection pc
			inner join physical_port p1
				on p1.physical_port_id = pc.physical_port_id1
			inner join device d1
				on d1.device_id = p1.device_id
			inner join physical_port p2
				on p2.physical_port_id = pc.physical_port_id2
			inner join device d2
				on d2.device_id = p2.device_id
		connect by prior pc.PHYSICAL_PORT_ID2 = pc.PHYSICAL_PORT_ID1
		start with pc.PHYSICAL_PORT_ID1 =
			(select physical_port1_id from layer1_connection
				where layer1_connection_id = ? )
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);

	$sth->execute($l1conn) || die $self->return_db_err($sth);

	my (@rv);
	while ( my $hr = $sth->fetchrow_hashref ) {
		push( @rv, $hr );
	}
	if ( $#rv == -1 ) {
		undef;
	} else {
		\@rv;
	}
}

sub get_layer1_connection_from_port {
	my ( $self, $port ) = @_;

	my $q = qq{
		select	layer1_connection_id,
			PHYSICAL_PORT1_ID,
			PHYSICAL_PORT2_ID,
			CIRCUIT_ID,
			BAUD,
			DATA_BITS,
			STOP_BITS,
			PARITY,
			FLOW_CONTROL
		  from	layer1_connection
		 where	physical_port1_id = ? or
			physical_port2_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($port) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_layer1_connection {
	my ( $self, $l1cid ) = @_;

	my $q = qq{
		select	layer1_connection_id,
			PHYSICAL_PORT1_ID,
			PHYSICAL_PORT2_ID,
			CIRCUIT_ID,
			BAUD,
			DATA_BITS,
			STOP_BITS,
			PARITY,
			FLOW_CONTROL
		  from	layer1_connection
		 where	layer1_connection_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($l1cid) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_physical_port {
	my ( $self, $pportid ) = @_;

	my $q = qq{
		select	PHYSICAL_PORT_ID,
			DEVICE_ID,
			PORT_NAME,
			PORT_TYPE,
			DESCRIPTION,
			PHYSICAL_LABEL,
			PORT_PURPOSE,
			TCP_PORT
		  from	physical_port
		 where	physical_port_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($pportid) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_physical_port_byport {
	my ( $self, $devid, $port, $type ) = @_;

	my $q = qq{
		select	PHYSICAL_PORT_ID,
			DEVICE_ID,
			PORT_NAME,
			PORT_TYPE,
			DESCRIPTION,
			PHYSICAL_LABEL,
			PORT_PURPOSE,
			TCP_PORT
		  from	physical_port
		 where	device_id = ?
		   and	port_name = ?
		   and	port_type = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute( $devid, $port, $type ) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_physical_port_tally {
	my ( $self, $devid, $type, $limit ) = @_;

	my $limitq = "";
	if ($limit) {

		# ORACLE/PGSQL
		#$limitq = "and	regexp_matches(port_name, ?)";
		$limitq = "and	port_name ~ ?";
	}

	my $sth = $self->prepare(
		qq{
		select	count(*)
		  from	physical_port
		 where	device_id = ?
		   and	port_type = ?
		   $limitq
	}
	);
	if ( defined($limit) ) {
		$sth->execute( $devid, $type, $limit )
		  || $self->return_db_err($sth);
	} else {
		$sth->execute( $devid, $type ) || $self->return_db_err($sth);
	}
	my ($tally) = $sth->fetchrow_array;
	$sth->finish;
	$tally;
}

sub get_physical_ports_for_dev {
	my ( $self, $devid, $type ) = @_;

	my (@rv);

	my $sth;
	if ($type) {
		my $q = qq{
			select	physical_port_id
			  from	physical_port
			 where	port_type = :2
			   and	device_id = :1
		};
		$sth = $self->prepare($q) || $self->return_db_err($self);
		$sth->execute( $devid, $type ) || $self->return_db_err($sth);
	} else {
		my $q = qq{
			select	physical_port_id
			  from	physical_port
			 where	device_id = ?
		};
		$sth = $self->prepare($q) || $self->return_db_err($self);
		$sth->execute($devid) || $self->return_db_err($sth);
	}
	while ( my ($id) = $sth->fetchrow_array ) {
		push( @rv, $id );
	}
	$sth->finish;
	\@rv;
}

sub get_num_dev_notes {
	my ( $self, $devid ) = @_;

	my $q = qq{
		select	count(*)
		  from	device_note
		 where	device_id = :devid
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->bind_param( ':devid', $devid ) || $self->return_db_err($sth);
	$sth->execute() || $self->return_db_err($sth);

	my $tally = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$tally;
}

sub add_to_device_collection {
	my ( $self, $devid, $dcid ) = @_;

	my $sth = $self->prepare(
		qq{
		insert into device_collection_device (
			device_collection_id,
			device_id
		) values (
			?,
			?
		)
	}
	) || $self->return_db_err;

	my $numchanges = 0;
	$numchanges += $sth->execute( $dcid, $devid )
	  || $self->return_db_err($sth);
	$numchanges;
}

sub remove_from_device_collection {
	my ( $self, $devid, $dcid, $type ) = @_;

	my $q = qq{
		delete from device_collection_device
		 where	device_collection_id = :dc
		  and	device_id = :devid
	};

	if ($type) {
		$q .= qq{and device_collection_id in
			(select device_collection_id 
			   from device_collection
			  where	device_collection_type = :type
			)
		};
	}

	my $sth = $self->prepare($q) || $self->return_db_err;

	my $numchanges = 0;
	$sth->bind_param( ':dc',    $dcid )  || $self->return_db_err($sth);
	$sth->bind_param( ':devid', $devid ) || $self->return_db_err($sth);
	if ($type) {
		$sth->bind_param( ':type', $type )
		  || $self->return_db_err($sth);
	}
	$numchanges += $sth->execute || $self->return_db_err($sth);
	$numchanges;
}

sub get_device_collection {
	my ( $self, $dcid ) = @_;

	my $sth = $self->prepare(
		qq{
		select	*
		  from	device_collection
		 where	device_collection_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($dcid) || $self->return_db_err($sth);
	my $dc = $sth->fetchrow_hashref;
	$sth->finish;
	$dc;
}

sub get_device_collections_for_device {
	my ( $self, $devid, $type ) = @_;

	my @dcids;
	my $q = qq{
		select	device_collection_id
		  from	device_collection_device
		 where	device_id = :devid
		  and
				device_collection_id not in
					(select parent_device_collection_id
					  from	device_collection_hier
					)
	};
	if ($type) {
		$q .= qq{and device_collection_id in
			(select device_collection_id 
			  from device_collection 
			  where device_collection_type = :type
			)
		};
	}

	my $sth = $self->prepare($q) || $self->return_db_err;

	$sth->bind_param( ':devid', $devid ) || $self->return_db_err($sth);
	if ($type) {
		$sth->bind_param( ':type', $type )
		  || $self->return_db_err($sth);
	}

	$sth->execute || $self->return_db_err($sth);

	my (@rv);
	while ( my ($dcid) = $sth->fetchrow_array ) {
		push( @rv, $dcid );
	}
	@rv;
}

sub get_system_user {
	my ( $self, $suid ) = @_;

	my $sth = $self->prepare(
		qq{
		select  *
		  from  system_user
		 where  system_user_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($suid) || $self->return_db_err;

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub is_static_route_on_device {
	my ( $self, $devid, $niid, $nbid ) = @_;

	my $sth = $self->prepare(
		qq{
		select	count(*)
		  from	static_route
		 where	device_src_id = ?
		   and	network_interface_dst_id = ?
		   and	netblock_id = ?
	}
	);
	$sth->execute( $devid, $niid, $nbid ) || $self->return_db_err;

	my ($tally) = $sth->fetchrow_array;
	$sth->finish;
	$tally;
}

sub add_static_route_from_template {
	my ( $self, $devid, $tmpltid ) = @_;

	my $sth = $self->prepare(
		qq{
		insert into static_route
			(device_src_id, network_interface_dst_id, netblock_id)
		select
			:2, NETWORK_INTERFACE_DST_ID, NETBLOCK_SRC_ID
		from
			static_route_template
		where
			STATIC_ROUTE_TEMPLATE_ID = ?
	}
	);

	my $tally += $sth->execute( $tmpltid, $devid )
	  || $self->return_db_err($sth);
	$tally;
}

sub rm_static_route_from_device {
	my ( $self, $srid ) = @_;

	my $sth = $self->prepare(
		qq{
		delete from static_route where static_route_id = ?
	}
	);
	my $tally += $sth->execute($srid) || $self->return_db_err($sth);
	$tally;
}

sub rm_static_route_from_netblock {
	my ( $self, $srid ) = @_;

	my $sth = $self->prepare(
		qq{
		delete from static_route_template where static_route_template_id = ?
	}
	);
	my $tally += $sth->execute($srid) || $self->return_db_err($sth);
	$tally;
}

sub validate_route_entry {
	my ( $self, $srcip, $srcbits, $destip ) = @_;

	if (
		( defined($srcip) || defined($srcbits) || defined($destip) )
		&& (       !defined($srcip)
			|| !defined($srcbits)
			|| !defined($destip) )
	  )
	{
		$self->error_return(
"Must specify all of ip, bits and dest IP for static route route"
		);
	}

	if ($srcip) {
		if ( !$self->validate_ip($srcip) ) {
			$self->error_return(
"$srcip for static route is an invalid IP address"
			);
		}
		if ( !$self->validate_ip($destip) ) {
			$self->error_return(
"$destip for static route is an invalid IP address"
			);
		}

		if ( $srcbits !~ /^\d+$/ || $srcbits > 32 ) {
			$self->error_return(
"$srcbits for static route is not a valid number of bits."
			);
		}

		# check valid ip, bits, dest ip
		my $ni = $self->get_interface_from_ip($destip);

		if ( !$ni ) {
			$self->error_return(
"$destip does not correspond to any network interfaces on this device in the database."
			);
		}

		my $nb =
		  $self->get_netblock_from_ip( $srcip, $srcbits, 'N', 'N' );

		if ( !$nb ) {
			my $parnb =
			  $self->guess_parent_netblock_id( $srcip, $srcbits );
			$nb = $self->add_netblock( 
				ip_address => $srcip,
				parent_netblock_id => $parnb->{_dbx('PARENT_NETBLOCK_ID')},
				netmask_bits => $srcbits,
				netblock_type => 'default',	# XXX -- need to reconsider!
			);
		}

		if ( !$nb ) {
			confess
"WEIRD: could not create route on $destip for $srcip/$srcbits to $destip "
			  . $ni->{ _dbx('NETWORK_INTERFACE_ID') };
			$self->error_return(
"There was a temporary error creating the static route.  Please report this. "
			);
		}

		return ( $ni, $nb );
	}

}

sub resync_device_power {
	my ( $self, $dev ) = @_;

	my $sth = $self->prepare(
		qq{
		insert into device_power_interface
			(device_id, power_interface_port)
		select	:1, power_interface_port
		  from	DEVICE_TYPE_POWER_PORT_TEMPLT
		 where	device_type_id = :2
		   and	power_interface_port not in 
			(select power_interface_port from device_power_interface
				where device_id = :1
			)   
	}
	);
	my $tally += $sth->execute(
		$dev->{ _dbx('DEVICE_ID') },
		$dev->{ _dbx('DEVICE_TYPE_ID') }
	) || $self->return_db_err($sth);
	$tally;
}

sub resync_physical_ports {
	my ( $self, $dev, $type ) = @_;

	my $typeadd = "";
	if ($type) {
		$typeadd = "and port_type = :ptype";
	}

	my $sth = $self->prepare(
		qq{
		insert into physical_port
			(device_id, port_name, port_type)
		select	:devid, port_name, port_type
		  from	device_type_phys_port_templt
		 where	device_type_id = :dtid
		   $typeadd
		   and	serial_port not in
				(select port_name from physical_port
					where device_id = :devid
					Rtypeadd
				)
	}
	);
	$sth->bind_param( ':devid', $dev->{ _dbx('DEVICE_ID') } )
	  || $self->return_db_err($sth);
	$sth->bind_param( ':dtid', $dev->{ _dbx('DEVICE_TYPE_ID') } )
	  || $self->return_db_err($sth);
	if ($type) {
		$sth->bind_param( ':ptype', $type )
		  || $self->return_db_err($sth);
	}
	my $tally += $sth->execute || $self->return_db_err($sth);
	$tally;
}

sub get_circuit {
	my ( $self, $cid ) = @_;

	my $sth = $self->prepare(
		qq{
		select  *
		  from  circuit
		 where  circuit_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($cid) || $self->return_db_err;

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_trunk_group {
	my ( $self, $cid ) = @_;

	my $sth = $self->prepare(
		qq{
		select  *
		  from  trunk_group
		 where  trunk_group_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($cid) || $self->return_db_err;

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_x509_cert_by_id {
	my ( $self, $certid ) = @_;

	my $sth = $self->prepare(
		qq{
		select	*
		  from	x509_certificate
		 where	x509_cert_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($certid) || $self->return_db_err;

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub build_netblock_ip_row {
	my ( $self, $params, $blk, $hr, $ip, $reservation ) = @_;

	my $cgi = $self->cgi;

	#
	# This is used to present a gap that a user can expand to add more
	# IP addresses;  used mostly with IPv6 where there is potential for
	# huge spaces between assignments
	if ( $params && $params->{-gap} ) {
		my $trgap   = $params->{-trgap};
		my $gapsize = $params->{-gap};
		my $gapno   = $params->{-gapno};

		my $gapnoid = 'nbgap' . $gapno;
		my $rowid   = "trgap_" . $trgap++;
		return $cgi->Tr(
			{
				-style => 'text-align: center',
				-id    => $rowid,
			},
			$cgi->td(
				$cgi->a(
					{
						-href =>
						  'javascript:void(null);',
						-onClick =>
qq{AddIpSpace(this, "$rowid", "$gapnoid");},
					},
					"ADD",
				)
			),
			$cgi->td(
				{ -colspan => 5 },
				$cgi->em(
					$cgi->span(
						{ -id => $gapnoid }, $gapsize
					),
					"address gap"
				),
			),
		);
	}

	my $showtr = 1;

	my ( $id, $bits, $devid, $name, $dom, $status, $desc, $atix, $atixsys );

	$status = "";
	$name   = "";
	$dom    = "";

	my $editabledesc = 0;

	my $uniqid = $ip;
	if ( defined( $params->{-uniqid} ) ) {
		$uniqid = "new_" . $params->{-uniqid};
	} elsif ( !defined($uniqid) ) {
		$uniqid = "__R" . rand();
	}

	my $printip;
	if ( !defined($ip) ) {

		# [XXX] probably should not asssume this will be there.
		$showtr  = 0;
		$printip = $cgi->textfield(
			-name => "ip_$uniqid",
			-size => '30',
		);
	} else {
		$printip = $ip;
	}

	if ($reservation) {
		$status = 'Allocation';
		$desc   = $reservation;
	} elsif ( defined($hr) ) {
		$id   = $hr->{ _dbx('NETBLOCK_ID') };
		$bits = $hr->{ _dbx('NETMASK_BITS') }
		  || $blk->{ _dbx('NETMASK_BITS') };
		$devid   = $hr->{ _dbx('DEVICE_ID') };
		$name    = $hr->{ _dbx('DNS_NAME') };
		$dom     = $hr->{ _dbx('SOA_NAME') };
		$status  = $hr->{ _dbx('NETBLOCK_STATUS') };
		$desc    = $hr->{ _dbx('DESCRIPTION') };
		$atix    = $hr->{ _dbx('APPROVAL_REF_NUM') };
		$atixsys = $hr->{ _dbx('APPROVAL_TYPE') };

		$printip = "$ip/$bits";

		my $fqhn = "";
		if ( defined($name) ) {
			$fqhn = $name . ( defined($dom) ? ".$dom" : "" );
		}

		if ( $status eq 'Reserved' || $status eq 'Legacy' ) {
			$editabledesc = 1;
			if ( !defined($devid) && $fqhn ) {
				$desc = $fqhn;
			}
		}

		if ( defined($devid) ) {
			$printip = $cgi->a(
				{ -href => "../device/device.pl?devid=$devid" },
				$printip
			);
			$name = $cgi->a(
				{ -href => "../device/device.pl?devid=$devid" },
				$name
			);
			$desc = $fqhn;
		}
	} else {
		$editabledesc = 1;
	}

	my $maketixlink;
	if ($editabledesc) {
		my $h = $cgi->hidden(
			-name    => "rowblk_$uniqid",
			-default => $id
		);
		$desc = ( ($id) ? $h : "" )
		  . $cgi->textfield(
			-name    => "desc_$uniqid",
			-default => ( ($desc) ? $desc : "" ),
			-size    => 50
		  );

		if ( !defined($atix) ) {
			$atix = $self->build_ticket_row( $hr, $uniqid, 'IP' );
		} else {
			$maketixlink = 1;
		}
	} else {
		$maketixlink = 1;
	}

	my $url;
	if ( $maketixlink && defined($atix) ) {
		$url = $self->build_trouble_ticket_link( $atix, $atixsys );
		if ($url) {
			$atix = $cgi->a(
				{
					-href =>
					  $self->build_trouble_ticket_link(
						$atix, $atixsys
					  ),
					-target => 'top'
				},
				"$atixsys:$atix"
			);
		} else {
			$atix = "$atixsys:$atix";
		}
	} else {
		$atix = "";
	}

	my $tds = $cgi->td(
		[ $printip, $status, $name, ($dom) ? $dom : "", $desc, $atix, ]
	);

	if ($showtr) {
		$cgi->Tr($tds);
	} else {
		$tds;
	}
}

1;
__END__

=head1 NAME

JazzHands::STAB::DBAccess - DB interface routines that belong elsewhere

=head1 SYNOPSIS

	don't use this directly; use JazzHands::STAB instead

=head1 DESCRIPTION

DB routines isolated here that need to be foled into a more generic
system

=head1 SEE ALSO

=head1 AUTHOR

Todd Kover

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
