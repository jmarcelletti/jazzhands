#!/usr/pkg/bin/perl
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
# $Id$
#
# Automatically generate zones from JazzHands, including hierarchies
# appropriate for disting to nameservers.  It's totally awesome.
#

### XXX: SIGALRM that kills after one zone hasn't been processed for 20 mins?

use strict;
use warnings;
use FileHandle;
use JazzHands::DBI;
use JazzHands::Common::Util qw(_dbx);
use Net::Netmask;
use Getopt::Long qw(:config no_ignore_case bundling);
use Socket;
use POSIX;
use Pod::Usage;
use Carp;

my $output_root = "/var/lib/zonegen/auto-gen";

my $dhcp_range_table;
my $verbose = 0;
my $debug   = 0;

umask(022);

#
# returns a valid sth given a query.  This is used to minimize the amount
# of reprocessing required for rerunning the same query.
#
my (%allsth);

sub getSth {
	my ( $dbh, $q ) = @_;

	my $sth;
	if ( exists( $allsth{$q} ) ) {
		$sth = $allsth{$q};
		$sth->finish;
	} else {
		$sth = $dbh->prepare_cached($q) || confess $dbh->errstr;
		$allsth{$q} = $sth;
	}
	$sth;
}

#
# print comments to a FileHandle object to indicate that the file is
# auto-generated and likely not hand maintained.
#
sub print_comments {
	my ( $fn, $commchr ) = @_;

	$commchr = '#' if ( !defined($commchr) );

	my $where  = `hostname`;
	my $whence = ctime(time);

	$where  =~ s/\s*$//s;
	$whence =~ s/\s*$//s;

	my $idtag =
	  '$Id$';

	$fn->print(
		qq{
$commchr
$commchr DO NOT EDIT THIS FILE BY HAND.  YOUR CHANGES WILL BE LOST.
$commchr This file was auto- generated from JazzHands on the machine:
$commchr 			$where 
$commchr by the DNS zone generation system. (look under /prod/zonegen/).
$commchr
$commchr It was generated at $whence by
$commchr $idtag
$commchr
$commchr Please contact jazzhands\@example.com. if you require more info.
}
	);

}

#
# implement mkdir -p in perl
#
sub mkdir_p {
	my ($dir) = @_;
	my $mode = 0755;

	my (@d) = split( m-/-, $dir );
	my $ne = $#d + 1;
	for ( my $i = 1 ; $i <= $ne ; $i++ ) {
		my (@dir) = split( m-/-, $dir );
		splice( @dir, $i );
		my $thing = join( "/", @dir );
		mkdir( $thing, $mode );
	}
}

#
# convert an ip address sto an integer from text.
#
sub iptoint {
	my ($ip) = @_;

	my $intip = inet_aton($ip);
	my $num = unpack( 'N', $intip );
	$num;
}

#
# record that a zone has been generated and bump the soa.
#
sub record_newgen {
	my ( $dbh, $domid, $script_start ) = @_;

	# not sure if this needs to be oratime anymore
	my $oratime = strftime( "%F %T", gmtime($script_start) );

	my $sth = getSth(
		$dbh, qq{
		update	dns_domain
		  set	soa_serial = soa_serial + 1,
			last_generated = to_date(:whence, 'YYYY-MM-DD HH24:MI:SS')
		where	dns_domain_id = :domid
	}
	);
	$sth->bind_param( ':whence', $oratime ) || die $sth->errstr;
	$sth->bind_param( ':domid', $domid ) || die $sth->errstr;
	$sth->execute  || die $sth->errstr;
}

#
# an exhaustive check for changes.  This is resource intensive  and is being
# phased out.
#
sub check_for_changes {
	my ( $dbh, $domid, $last ) = @_;

	$last = "1970-01-01 00:00:00" if ( !defined($last) );

	#
	# check for forward dns and the domain itself
	#
	my $sth = getSth(
		$dbh, qq{
		select  count(*)
		  from  dns_record d
		    left join netblock nb
			on d.netblock_id = nb.netblock_id
		 where  d.dns_domain_id = :domid
		   and  (
				d.data_ins_date > :whence
			   or   d.data_upd_date > :whence
			   or   nb.data_ins_date > :whence
			   or   nb.data_upd_date > :whence
			)
	}
	);

	$sth->bind_param( ':whence', $last ) || die $sth->errstr;
	$sth->bind_param( ':domid', $domid ) || die $sth->errstr;
	$sth->execute || die $sth->errstr;
	my $count = ( $sth->fetchrow_array )[0];
	$sth->finish;
	return $count if ($count);

	#
	# check for inverse dns
	#
	$sth = getSth(
		$dbh, qq{
		select count(*) 
		  from  netblock nb 
			inner join dns_record dns
			    on nb.netblock_id = dns.netblock_id
			inner join dns_domain dom
			    on dns.dns_domain_id =
				dom.dns_domain_id,
		    netblock root
			inner join dns_record rootd
			    on rootd.netblock_id = root.netblock_id
			    and rootd.dns_type = 
				'REVERSE_ZONE_BLOCK_PTR'
		 where  dns.should_generate_ptr = 'Y'
		   and  dns.dns_class = 'IN' and dns.dns_type = 'A'
		   and  net_manip.inet_base(nb.ip_address, root.netmask_bits) =
			net_manip.inet_base(root.ip_address,
			    root.netmask_bits)
		   and  rootd.dns_domain_id = :domid
		   and  (
				nb.data_ins_date > :whence
			   or (nb.data_upd_date is not NULL and nb.data_upd_date > :whence)
			   or dns.data_ins_date > :whence
			   or (dns.data_upd_date is not NULL and dns.data_upd_date > :whence)
			   or dom.data_ins_date > :whence  
			   or (dom.data_upd_date is not NULL and dom.data_upd_date > :whence)
			   or root.data_ins_date > :whence 
			   or (root.data_upd_date is not NULL and root.data_upd_date > :whence )
			   or rootd.data_ins_date > :whence
			   or (rootd.data_upd_date is not NULL and rootd.data_upd_date > :whence)
			)
		order by nb.ip_address
	}
	);

	$sth->bind_param( ':domid', $domid ) || die $sth->errstr;
	$sth->bind_param( ':whence', $last ) || die $sth->errstr;
	$sth->execute || die $sth->errstr;
	$count += ( $sth->fetchrow_array )[0];
	return $count if ($count);
	0;
}

#
# used internally to figure out where we do dhcp ranges rather than hammer
# the db more than necessary.
#
sub build_dhcp_range_table {
	my ($dbh) = @_;

	my $sth = getSth(
		$dbh, qq{
		select  dr.dhcp_range_id,
			dr.start_netblock_id,
			dr.stop_netblock_id,
			nbstart.ip_address as start_num_ip,
			nbstop.ip_address as stop_num_ip,
			net_manip.inet_dbtop(nbstart.ip_address) as start_ip,
			net_manip.inet_dbtop(nbstop.ip_address) as stop_ip,
			dom.soa_name,
			dr.data_ins_date as range_insert_date,
			dr.data_upd_date as range_update_date,
			nbstart.data_ins_date as start_insert_date,
			nbstart.data_upd_date as start_update_date,
			nbstop.data_ins_date as stop_insert_date,
			nbstop.data_upd_date as stop_update_date
		  from  dhcp_range dr
				inner join netblock nbstart
					on dr.start_netblock_id = nbstart.netblock_id
				inner join netblock nbstop
					on dr.stop_netblock_id = nbstop.netblock_id,
			network_interface ni
				inner join netblock nb
					on ni.v4_netblock_id = nb.netblock_id
				inner join dns_record dns
					on dns.netblock_id = nb.netblock_id
				inner join dns_domain dom
					on dom.dns_domain_id = dns.dns_domain_id
		where
			ni.network_interface_id = dr.network_interface_id
		and
		(
			net_manip.inet_base(nb.ip_address, nbstart.netmask_bits) =
				net_manip.inet_base(nbstart.ip_address, nbstart.netmask_bits)
		   or
			net_manip.inet_base(nb.ip_address, nbstop.netmask_bits) =
				net_manip.inet_base(nbstop.ip_address, nbstop.netmask_bits)
		)
	}
	);

	$sth->execute || die $sth->errstr;

	my $rv = $sth->fetchall_hashref(_dbx('DHCP_RANGE_ID'));
	$sth->finish;
	$rv;
}

sub process_fwd_dhcp {
	my ( $dbh, $out, $domid, $domain ) = @_;

	foreach my $rangeid ( keys(%$dhcp_range_table) ) {
		my $rec = $dhcp_range_table->{$rangeid};

		my $soa_name = $rec->{_dbx('SOA_NAME')};
		next if ( $soa_name ne $domain );

		my $start = $rec->{_dbx('START_NUM_IP')};
		my $stop  = $rec->{_dbx('STOP_NUM_IP')};

		for ( my $i = $start ; $i <= $stop ; $i++ ) {
			my $real_int_ip = pack( 'N', $i );
			my $ip = inet_ntoa($real_int_ip);

			my $human = $ip;
			$human =~ s/\./-/g;
			$human = "dhcp-$human";
			$out->print("$human\tIN\tA\t$ip\n");
		}
	}

}

sub process_rvs_dhcp {
	my ( $dbh, $out, $domid, $block ) = @_;

	my $sth = getSth(
		$dbh, qq{
		select  distinct
			net_manip.inet_dbtop(
				net_manip.inet_base(n.ip_address,n.netmask_bits)),
			netmask_bits
		  from  netblock n
			inner join dns_record d
				on d.netblock_id = n.netblock_id
		 where  d.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		   and  d.dns_domain_id = ?
	}
	);
	$sth->execute($domid) || die $sth->errstr;

	my ( $base, $bits ) = $sth->fetchrow_array;
	$sth->finish;
	return if ( !defined($base) || !defined($bits) );

	my $nb         = new Net::Netmask("$base/$bits") || return;
	my $low_block  = iptoint( $nb->base() );
	my $high_block = iptoint( $nb->broadcast() );

	foreach my $rangeid ( keys(%$dhcp_range_table) ) {
		my $rec = $dhcp_range_table->{$rangeid};

		my $soa_name = $rec->{_dbx('SOA_NAME')};

		my $start = $rec->{_dbx('START_NUM_IP')};
		my $stop  = $rec->{_dbx('STOP_NUM_IP')};

		my $start_ip = $rec->{_dbx('START_IP')};
		my $stop_ip  = $rec->{_dbx('STOP_IP')};

		if (
			!(
				(
					   $start >= $low_block
					&& $start <= $high_block
				)
				|| (       $stop >= $low_block
					&& $stop <= $high_block )
			)
		  )
		{

			next;
		}

		if ( $start < $low_block ) {
			$start = $low_block;
		}

		if ( $stop > $high_block ) {
			$stop = $high_block;
		}

		for ( my $i = $start ; $i <= $stop ; $i++ ) {
			my $real_int_ip = pack( 'N', $i );
			my $ip          = inet_ntoa($real_int_ip);
			my $lastoctet   = ( split( /\./, $ip ) )[3];

			if ( !defined( $$block[$lastoctet] ) ) {
				$ip =~ s/\./-/g;
				$ip = "dhcp-$ip";
				$$block[$lastoctet] = "$ip.$soa_name.";
			}
		}
	}
}

sub process_child_ns_records {
	my ( $dbh, $out, $domid, $parent_domain ) = @_;

	my $sth = getSth(
		$dbh, qq{
		select	distinct
			dom.soa_name,
			dns.dns_class,
			dns.dns_type,
			dns.dns_value,
			dns.is_enabled
		  from	dns_domain dom
			inner join dns_record dns
				on dns.dns_domain_id = dom.dns_domain_id
		 where	dns.dns_name is NULL
		  and	dns.dns_type = 'NS'
		  and 	dom.parent_dns_domain_id = ?
		order by dom.soa_name, dns.dns_value
	}
	);

	$sth->execute($domid) || die $sth->errstr;

	while ( my ( $dom, $class, $type, $ns, $enable ) =
		$sth->fetchrow_array )
	{
		my $com = ( $enable eq 'N' ) ? ";" : "";
		$class = 'IN' if ( !defined($class) );
		$type  = 'NS' if ( !defined($type) );
		$ns .= "." if ( $ns !~ /\.$/ );
		$dom =~ s/.$parent_domain$//;
		$out->print("$com$dom\t$class\t$type\t$ns\n");
	}

}

sub process_fwd_records {
	my ( $dbh, $out, $domid, $domain ) = @_;

	#
	# sort_order is arranged such that records for the domain itself
	# end up first.  The processing of the query inserts a newline when
	# going between the two, so that value is also used later.
	#
	# NOTE:  It is possible to have an in database "cname" that causes
	# another records ip address or name to be put in.  This only works
	# for NS, A, AAAA, MX and CNAMEs.  It almost certainly needs to be
	# broken out better in the db.
	#
	my $sth = getSth(
		$dbh, qq {
		select  distinct
			d.dns_record_id, d.dns_name, d.dns_ttl, d.dns_class,
			d.dns_type, d.dns_value, 
			d.dns_priority,
			net_manip.inet_dbtop(ni.ip_address) as ip,
			rdns.dns_record_Id,
			rdns.dns_name,
			d.dns_srv_service, d.dns_srv_protocol, 
			d.dns_srv_weight, d.dns_srv_port,
			d.is_enabled,
			dv.dns_name as val_dns_name,
			dv.soa_name as val_domain,
			dv.dns_value as val_value,
			dv.ip as val_ip,
			(CASE WHEN(d.dns_name is NULL and
				   d.reference_dns_record_id is NULL)
				THEN 0
			 	ELSE 1
			 END
			) as sort_order
		  from	dns_record d
			left join netblock ni
				on d.netblock_id = ni.netblock_id
			left join dns_record rdns
				on rdns.dns_record_id =
					d.reference_dns_record_id
			left join (
				select	dr.dns_record_id, dr.dns_name, 
					dom.dns_domain_id, dom.soa_name,
					dr.dns_value,
					net_manip.inet_dbtop(dnb.ip_address) as ip
				  from	dns_record dr
				  	inner join dns_domain dom
						using (dns_domain_id)
					left join netblock dnb
						using (netblock_id)
			) dv on d.dns_value_record_id = dv.dns_record_id
		 where	d.dns_domain_id = ?
		   and	d.dns_type != 'REVERSE_ZONE_BLOCK_PTR'
		order by sort_order, net_manip.inet_dbtop(ni.ip_address)
	}
	);

	$sth->execute($domid) || die $sth->errstr;

	my $lastso = 0;
	while (
		my (
			$id,       $name,      $ttl,     $class,
			$type,     $val,       $pri,     $ip,
			$rid,      $rname,,    $srv,
			$srvproto, $srvweight, $srvport, $enable,
			$valname,  $valdomain, $valval,  $valip,
			$so
		)
		= $sth->fetchrow_array
	  )
	{
		my $com = ( $enable eq 'N' ) ? ";" : "";
		if ( $lastso == 0 && $so == 1 ) {
			$out->print("\n");
		}
		$lastso = $so;
		$name   = "" if ( !defined($name) && !defined($rname) );
		$name   = $rname if ( !defined($name) );
		my $value = $val;
		if ( $type eq 'A'|| $type eq 'AAAA' ) {
			$value = ($valip)?$valip:$ip;
		} elsif ( $type eq 'MX' ) {

			# at the moment, STAB nudges people towards putting
			# the mx value in the "value field", overloading it.
			# while this needs to be fixed, this causes bum
			# records to not be generated.
			if ( !defined($pri) ) {
				if ( $value !~ /^\s*\d+\s+\S/ ) {
					$pri = 0;
				} else {
					$pri = "";
				}
			}
			$pri .= " " if ( defined($pri) );
			$value = "$pri$value";
			if($valname) {
				if($valdomain eq $domain) {
					$value = $valname;
				} else {
					$value = "$valname.$valdomain";
				}
			}
		} elsif ( $type eq 'TXT' ) {
			$value =~ s/^"//;
			$value =~ s/"$//;
			$value = "\"$value\"";
		} elsif ( $type eq 'CNAME' || $type eq 'NS') {
			if($valname) {
				if($valdomain eq $domain) {
					$value = $valname;
				} else {
					$value = "$valname.$valdomain";
				}
			}
		} elsif ( $type eq 'SRV' ) {
			if ( $srvproto && $srvproto !~ /^_/ ) {
				$srvproto = "_$srvproto";
			}
			$name = ".$name" if ( $srvproto && length($name) );
			$name = "$srvproto$name" if ($srvproto);
			$name = ".$name"         if ( $srv && length($name) );
			$name = "$srv$name"      if ($srv);

		 #
		 # these should never be not set, but people are cramming the
		 # srv values into the value field (because stab doesn't support
		 # otherwise, so it does happen).
		 #
			$pri       ||= '';
			$srvweight ||= '';
			$srvport   ||= '';

			$value = "$pri $srvweight $srvport $value";
		}

		#
		# so == 0 means it's a record or the zone, so this gets
		# indented less
		#
		my $width = 25;
		$width = 0 if ( $so == 0 );

		$ttl = "" if ( !defined($ttl) );
		$out->printf( "%s%-*s\t%s %s\t%s\t%s\n",
			$com, $width, $name, $ttl, $class, $type, $value );
	}
	$out->print("\n");
	process_fwd_dhcp( $dbh, $out, $domid, $domain );
	$out->print("\n");
}

sub process_reverse {
	my ( $dbh, $out, $domid ) = @_;

	my $sth = getSth(
		$dbh, qq{
		select  net_manip.inet_dbtop(nb.ip_address) as ip,
			dns.dns_name,
			dom.soa_name,
			net_manip.inet_dbtop(
				net_manip.inet_base(nb.ip_address,
				nb.netmask_bits)) as ip_base,
			nb.netmask_bits as netmask_bits,
			dns.is_enabled
		  from  netblock nb
				inner join dns_record dns
					on nb.netblock_id = dns.netblock_id
				inner join dns_domain dom
					on dns.dns_domain_id =
						dom.dns_domain_id,
			netblock root
				inner join dns_record rootd
					on rootd.netblock_id = root.netblock_id
					and rootd.dns_type =
						'REVERSE_ZONE_BLOCK_PTR'
		 where  dns.should_generate_ptr = 'Y'
		   and  dns.dns_class = 'IN' and dns.dns_type = 'A'
		   and  net_manip.inet_base(nb.ip_address, root.netmask_bits) =
				net_manip.inet_base(root.ip_address,
					root.netmask_bits)
		   and  rootd.dns_domain_id = ?
		order by nb.ip_address
	}
	);

	$sth->execute($domid) || die $sth->errstr;

	my @com;

	my (@block);
	while ( my ( $ip, $sn, $dom, $base, $bits, $enable ) =
		$sth->fetchrow_array )
	{
		my $lastoctet = ( split( /\./, $ip ) )[3];
		$com[$lastoctet] = $enable;
		if ($sn) {
			$block[$lastoctet] = "$sn.$dom.";
		} else {
			$block[$lastoctet] = "$dom.";
		}
	}
	process_rvs_dhcp( $dbh, $out, $domid, \@block );

	for ( my $i = 0 ; $i <= $#block ; $i++ ) {
		next if ( !defined( $block[$i] ) );
		my $com = ( $com[$i] && $com[$i] eq 'N' ) ? ";" : "";
		$out->print( "$com$i\tIN\tPTR\t" . $block[$i] . "\n" );
	}
}

sub process_soa {
	my ( $dbh, $out, $domid ) = @_;

	my $sth = getSth(
		$dbh, qq{
		select	soa_name, soa_class, soa_ttl,
			soa_serial, soa_refresh, soa_retry,
			soa_expire, soa_minimum,
			soa_mname, soa_rname
		  from	dns_domain
		 where	dns_domain_id = ?
	}
	);

	$sth->execute($domid) || die $sth->errstr;

	my (
		$dom, $class, $ttl, $serial, $ref,
		$ret, $exp,   $min, $mname,  $rname
	) = $sth->fetchrow_array;
	$sth->finish;

	$class  = 'IN'    if ( !defined($class) );
	$ttl    = 72000   if ( !defined($ttl) );
	$serial = 0       if ( !defined($serial) );
	$ref    = 3600    if ( !defined($ref) );
	$ret    = 1800    if ( !defined($ret) );
	$exp    = 2419200 if ( !defined($exp) );
	$min    = 3006    if ( !defined($min) );

	$rname = 'hostmaster.example.com' if ( !defined($rname) );
	$mname = "auth00.example.com"     if ( !defined($mname) );

	$mname =~ s/\@/./g;

	$mname .= "." if ( $mname =~ /\./ );
	$rname .= "." if ( $rname =~ /\./ );

	print_comments( $out, ';' );

	$out->print( '$TTL', "\t$min\n" );
	$out->print("@\t$ttl\t$class\tSOA $mname $rname (\n");
	$out->print("\t\t\t\t$serial\t; serial number\n");
	$out->print("\t\t\t\t$ref\t; refresh\n");
	$out->print("\t\t\t\t$ret\t; retry\n");
	$out->print("\t\t\t\t$exp\t; expire\n");
	$out->print("\t\t\t\t$min )\t; minimum\n\n");

}

#
# if zoneroot is undef, then dump the zone to stdout.
#
sub process_domain {
	my ( $dbh, $zoneroot, $domid, $domain, $errcheck, $last ) = @_;

	my $inaddr = "";
	if ( $domain =~ /in-addr.arpa$/ ) {
		$inaddr = "inaddr/";
	}

	my ( $fn, $tmpfn );

	if ($zoneroot) {
		$fn    = "$zoneroot/$inaddr$domain";
		$tmpfn = "$fn.tmp.$$";
	} else {
		$tmpfn = "/dev/stdout";
	}

	my $out = new FileHandle(">$tmpfn") || die "$tmpfn: $!";

	print STDERR "\tprocess SOA to $tmpfn\n" if ($debug);
	process_soa( $dbh, $out, $domid );
	print STDERR "\tprocess fwd\n" if ($debug);
	process_fwd_records( $dbh, $out, $domid, $domain );
	print STDERR "\tprocess child ns\n" if ($debug);
	process_child_ns_records( $dbh, $out, $domid, $domain );
	print STDERR "\tprocess rvs\n" if ($debug);
	process_reverse( $dbh, $out, $domid );
	print STDERR "\tprocess_domain complete\n" if ($debug);
	$out->close;

	if($last) {
		my($y,$m,$d,$h,$min,$s)  = ( $last =~ /^(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)\D/ );
		my $whence = mktime($s, $min, $h, $d, $m - 1, $y - 1900);
		utime($whence, $whence, $tmpfn);  # If it does not work, then Vv
	} 

	if ( !$zoneroot ) {
		return 0;
	}

	#
	# run named-checkzone to see if its a valid or bump zone, and if it
	# failed the test, then spit out an error message and return something
	# indicating as such.
	#
	my $prog = "named-checkzone $domain $tmpfn";
	print "running $prog\n" if ($debug);
	my $output = `$prog`;
	if ( ( $? >> 8 ) ) {
		my $errmsg = "[not pushing out]";
		if ($errcheck) {
			$errmsg = "[WARNING: PUSHING OUT!]";
		}
		warn "$domain was generated with errors $errmsg ($output)\n";
		if ( !$errcheck ) {
			return 0;
		}
	}

	unlink($fn);
	rename( $tmpfn, $fn );
	return 1;
}

sub generate_complete_files {
	my ( $dbh, $zoneroot, $zonesgend ) = @_;

	my $cfgdir = "$zoneroot/../etc";

	mkdir_p("$cfgdir");
	my $cfgfn    = "$cfgdir/named.conf.auto-gen";
	my $tmpcfgfn = "$cfgfn.tmp.$$";
	my $cfgf     = new FileHandle(">$tmpcfgfn") || die "$tmpcfgfn\n";

	print_comments( $cfgf, '#' );

	my $sth = getSth(
		$dbh, qq{
		select	soa_name
		  from	dns_domain
		 where	should_generate = 'Y'
	}
	);
	$sth->execute || die $sth->errstr;

	while ( my ($zone) = $sth->fetchrow_array ) {
		my $fn = $zone;
		$fn = "inaddr/$zone" if ( $fn =~ /.in-addr.arpa/ );
		$cfgf->print(
"zone \"$zone\" {\n\ttype master;\n\tfile \"auto-gen/zones/$fn\";\n}\n\n"
		);
	}
	$cfgf->close;
	unlink($cfgfn);
	rename( $tmpcfgfn, $cfgfn );

	my $zcfn    = "$cfgdir/zones-changed.rndc";
	my $tmpzcfn = "$zcfn.tmp.$$";
	my $zcf     = new FileHandle(">$tmpzcfn") || die "$zcfn\n";
	chmod( 0755, $tmpzcfn );

	print_comments( $zcf, '#' );
	print_rndc_header($zcf);

	my $tally = 0;
	foreach my $zone ( sort keys(%$zonesgend) ) {
		if ( defined($zonesgend) && defined( $zonesgend->{$zone} ) ) {

			# oh, this is a hack!
			$zcf->print("rndc reload $zone || rndc reload\n");
			$tally++;
		}
	}

	# $zcf->print("rndc reload\n\n") if($tally);
	$zcf->close;
	unlink($zcfn);
	rename( $tmpzcfn, $zcfn );

}

sub process_perserver {
	my ( $dbh, $zoneroot, $persvrroot, $zonesgend ) = @_;

	#
	# we only create symlinks for zones that should be generated
	#
	my $sth = getSth(
		$dbh, qq{
		select	distinct
			dom.dns_domain_id,
			dns.dns_value,
			dom.soa_name
		 from   dns_domain dom
			inner join dns_record dns
				on dns.dns_domain_id = dom.dns_domain_id
		 where  dns.dns_name is NULL
		   and  dns_type = 'NS'
		   and	dom.should_generate = 'Y'
		order by dns.dns_value
	}
	);

	$sth->execute || die $sth->errstr;

	my %servers;
	while ( my ( $id, $ns, $zone ) = $sth->fetchrow_array ) {
		next if ( !$ns );    # this should not happen
		$ns =~ s/\.*$//;
		push( @${ $servers{$ns} }, $zone );
	}

	#
	# now process each server
	#
	my $tally = 0;
	foreach my $server ( keys(%servers) ) {
		my $svrdir  = "$persvrroot/$server";
		my $zonedir = "$svrdir/zones";
		my $cfgdir  = "$svrdir/etc";
		my $zones   = $servers{$server};

		if ( -d $zonedir ) {

			#
			# go through and remove zones that don't belong.
			# This may leave excess in-addrs.  oh well.
			#
			opendir( DIR, $zonedir ) || die "$zonedir: $!";
			foreach my $entry ( readdir(DIR) ) {
				my $fqn = "$zonedir/$entry";
				next if ( !-l $fqn );
				next if ( grep( $_ eq $entry, @$$zones ) );
				unlink($fqn);
			}
			closedir(DIR);
		} else {
			mkdir_p($zonedir);
		}

		my $inaddrdir = "$zonedir/inaddr";
		if ( -d $inaddrdir ) {

			#
			# go through and remove zones that don't belong,
			# which may leave some non-inaddrs.
			#
			opendir( DIR, $inaddrdir ) || die "$inaddrdir: $!";
			foreach my $entry ( readdir(DIR) ) {
				my $fqn = "$inaddrdir/$entry";
				next if ( !-l $fqn );
				next if ( grep( $_ eq $entry, @$$zones ) );
				unlink($fqn);
			}
			closedir(DIR);
		} else {
			mkdir_p($inaddrdir);
		}

	       #
	       # create a symlink in the "perserver" directory for zones
	       # the server servers as well as creating a named.conf
	       # file to be included.  A file that lists all the zones that
	       # are auto-generated that were changed on this run is also saved.
	       #
		mkdir_p("$cfgdir");
		my $cfgfn    = "$cfgdir/named.conf.auto-gen";
		my $tmpcfgfn = "$cfgfn.tmp.$$";
		my $cfgf = new FileHandle(">$tmpcfgfn") || die "$tmpcfgfn\n";

		print_comments( $cfgf, '#' );

		my $zcfn    = "$cfgdir/zones-changed.rndc";
		my $tmpzcfn = "$zcfn.tmp.$$";
		my $zcf     = new FileHandle(">$tmpzcfn") || die "$zcfn\n";
		chmod( 0755, $tmpzcfn );
		print_comments( $zcf, '#' );

		print_rndc_header($zcf);

		foreach my $zone (@$$zones) {
			my $fqn = "$zonedir/$zone";
			my $zr  = $zoneroot;
			if ( $zr =~ /^\.\./ ) {
				$zr = "../../$zr";
			}

			if ( $zone =~ /in-addr.arpa$/ ) {
				if ( $zr =~ /^\.\./ ) {
					$zr = "../$zr";
				}
				$fqn = "$zonedir/inaddr/$zone";
				$zr .= "/inaddr/$zone";
			} else {
				$zr .= "/$zone";
			}

			#
			# now actually create the link, and if the link
			# is pointing to the wrong place, move it
			#
			if ( !-l $fqn ) {
				unlink($zr);
				symlink( $zr, $fqn );
			} else {
				my $ov = readlink($fqn);
				if ( $ov ne $zr ) {
					unlink($fqn);
					symlink( $zr, $fqn );
				}
			}
			if ( !-r $fqn ) {
				warn
"$zone does not exist for $server (see $fqn); possibly needs to be forced before a regular run\n";
			}

			if ( $zone =~ /in-addr.arpa$/ ) {
				$cfgf->print(
"zone \"$zone\" {\n\ttype master;\n\tfile \"auto-gen/zones/inaddr/$zone\";\n};\n\n"
				);
			} else {
				$cfgf->print(
"zone \"$zone\" {\n\ttype master;\n\tfile \"auto-gen/zones/$zone\";\n};\n\n"
				);
			}

			if (       defined($zonesgend)
				&& defined( $zonesgend->{$zone} ) )
			{
				$zcf->print(
					"rndc reload $zone || rndc reload\n");
				$tally++;
			}
		}

		# $zcf->print("rndc reload\n\n") if($tally);

		$cfgf->close;
		unlink($cfgfn);
		rename( $tmpcfgfn, $cfgfn );

		$zcf->close;
		unlink($zcfn);
		rename( $tmpzcfn, $zcfn );
	}
}

sub print_rndc_header {
	my ($zcf) = @_;

	#
	# squirrel a suggested path so that all our various named
	# variants will find it...
	#
	$zcf->print("#!/bin/sh\n");
	$zcf->print("\n");
	$zcf->print(
		'PATH=$PATH:/usr/local/sbin:/usr/sbin:/usr/local/bin:/usr/bin');
	$zcf->print("\n");
	$zcf->print('export PATH');
	$zcf->print("\n\n");

	$zcf->print("rndc reconfig\n\n");
}

#############################################################################
#
# main stuff starts here
#
#############################################################################

my $genall   = 0;
my $dumpzone = 0;
my $forcegen = 0;
my $forcesoa = 0;
my $forceall = 0;
my $nosoa    = 0;
my $help     = 0;

my $script_start = time();

GetOptions(
	'help'       => \$help,          # duh.
	'verbose|v'  => \$verbose,       # duh.
	'debug'      => \$debug,         # even more verbosity.
	'genall|a'   => \$genall,        # generate all, not just new
	'forcegen|f' => \$forcegen,      # force generation of zones
	'force|f'    => \$forceall,      # force everything
	'forcesoa|s' => \$forcesoa,      # force bump of SOA record
	'nosoa'      => \$nosoa,         # never bump soa record
	'dumpzone'   => \$dumpzone,      # dump a zone to stdout
	'outdir|o=s' => \$output_root    # output directory
) || die pod2usage( -verbose => 1 );

$verbose = 1 if ($debug);

if ( $dumpzone && $#ARGV > 0 ) {
	die "can only dump one zone to stdout.\n";
} elsif ( $dumpzone && $#ARGV == -1 ) {
	die "must specify a zone to dump\n";
}

if ($help) {
	pod2usage( -verbose => 1 );
}

if ($forceall) {
	$forcegen = $forcesoa = 1;
}

if ( $nosoa && $forcesoa ) {
	die "Can't both force an SOA serial bump and deny it.\n";
}

#
# note that these are assumed to be under $output_root later.
#
my $zoneroot   = "$output_root/zones";
my $persvrroot = "$output_root/perserver";

mkdir_p($output_root)       if ( !-d "$output_root" );
mkdir_p($zoneroot)          if ( !-d "$zoneroot" );
mkdir_p("$zoneroot/inaddr") if ( !-d "$zoneroot/inaddr" );

my $dbh = JazzHands::DBI->connect( 'zonegen', { AutoCommit => 0 } ) || die;

$dhcp_range_table = build_dhcp_range_table($dbh);

my $should_gen = "where should_generate = 'Y'";
if ( $genall || $dumpzone ) {
	$should_gen = "";
}

my $q = qq{
	select  dns_domain_id, soa_name, should_generate, last_generated,
			zone_last_updated,
			case WHEN last_generated <= ZONE_LAST_UPDATED THEN 'Updated'
				 WHEN last_generated is NULL THEN 'Updated'
				else 'Current'
			END as changed
	  from	dns_domain
	 $should_gen
};

my $sth = $dbh->prepare($q) || die "$q: " . $dbh->errstr;
$sth->execute || die "$q: " . $sth->errstr;

my (%lgupdate);    # used to track when to indicate an update date.
my (%zones);       # zones updated tracked.
while ( my ( $domid, $domain, $genme, $last, $due, $state ) =
	$sth->fetchrow_array )
{

	#
	# this is something of a hack, since process_domain is called in two
	# places.  Probably want to restructure so it only gets called once.
	# [XXX]
	#
	if ( $dumpzone && grep( $_ eq $domain, @ARGV ) ) {
		process_domain( $dbh, undef, $domid, $domain, undef, $last );
		next;
	}

	#
	# only check this zones for changes if we aren't told to forcably
	# generate, or this zone is specified on the command line.
	#
	my $changes;
	if (       ( $#ARGV == -1 && !$forcegen )
		|| ( $#ARGV >= 0 && grep( $_ eq $domain, @ARGV ) ) )
	{
		if ( $state eq 'Updated' ) {
			$changes = 1;
		}

		#print "checking for changes in $domid -- $domain\n" if($debug);
		#$changes = check_for_changes($dbh, $domid, $last);
	}
	if ( $changes || $forcegen ) {
		if ( $#ARGV == -1 || grep( $_ eq $domain, @ARGV ) ) {
			if ( !$nosoa && ( $changes || $forcesoa ) ) {

				# this is deleted to move all the writes to
				# the end so they happen right before the
				# commit.
				$lgupdate{$domid} = $script_start;
			}
			print "$domain\n";
			if (
				process_domain(
					$dbh, $zoneroot, $domid, $domain, undef, $last
				)
			  )
			{
				$zones{$domain}++ if ( $genme eq 'Y' );
			}
		}
	}
}

if ( !$dumpzone ) {
	process_perserver( $dbh, "../zones", $persvrroot, \%zones );

	#
	# generate the master zone server
	#
	#
	generate_complete_files( $dbh, $zoneroot, \%zones );
}

#
# update the db's "last generated" date now.  This is saved to the end so
# that all the updates happen quickly, and right before commit so the time
# that a modification is lingering is minimized.
#
foreach my $domid ( keys(%lgupdate) ) {
	record_newgen( $dbh, $domid, $lgupdate{$domid} );
}

if ($dumpzone) {
	$dbh->rollback;
} else {
	$dbh->commit;
}
$dbh->disconnect;
$dbh = undef;

END {
	if ($dbh) {
		$dbh->rollback;
		$dbh->disconnect;
	}
}

__END__;

=head1 generate-zones

generate-zones -- generate DNS zone files from JazzHands

=head1 SYNOPSIS

generate-zones [ options ] [ zone1 zone2 zone3 ... ]

=head1 OPTIONS

=over

=item B<--genall, -a> generate all zones

=item B<--forcegen> force generation of zones

=item B<--forcesoa> force update of SOA

=item B<--force, -f> force generation and bumping of SOA record

=item B<--nosoa> never update the SOA

=item B<--outdir, -o> change putput

=item B<--dumpzone> dump a zone to stdout.

=back

=head1 DESCRIPTION

The generate-zones command is used to generate zone files, as well
as configuration files and zone file hierarchies that can be copied to
dns servers for inclusion in their DNS configuration files.  This script
is generally invoked by the do-zone-generation script which takes care of
distribution.  An end-user may invoke zonegen-force to invoke the entire
process for a given zone.

Under normal circumstances, the zones are first scanned to determine
changes have been made, and if so, the SOA serial number is incremented
by one, and zone files generated.  A configuration file and a shell
script that invokes rndc for each changed zone is also generated with a
hierarchy of symlinks for distribution to name servers.  These are used
by a wrapper script to copy to machines.

If invoked from the do-zone-generation wrapper script that also
takes care of syncing (the normal invocation), the lock file
/prod/zonegen/run/zonegen.lock will also prevent a run from happening
if the lock file is newer than three hours.

It is possible to specify zone names on the command line.  In that case,
only those zones will be operated on rather than all zones that are in
the database.  Note that you may need to use other options to trigger
the behavior you want, since this option just restricts the zones that
the command operates on, rather than forcing generation of zones.

Unlike what might be expected, this script generates zone files that
make a zone file a 'master' server' rather than one that slaves zones
from another server.

The command has two subdirectories that it creates under the output
directory, 'zones' and 'perserver'.  The zones directory contains forward
zones, and a subdirectory 'inaddr' with the inverse zones.

The perserver directory contains a directory per nameserver.  The
nameservers are those that generate-zones found to be listed as
authoritative for zones with the should_generate flag set to Y.  Each
of these directories contains two directories, "etc", and "zones".  The
etc directory contains part of a named.conf file that can be included on
a name server to make it a master server for auto generated zones.  The
"zones" file contains symlinks back to the master zones directory in
the output_root area.  This entire tree can be copied via rsync or rdist
(by not replicating symlinks) to a nameserver's auto-gen directory under
it's named root.

generate-zones normally does it's work under the /prod/zonegen/auto-gen/
directory.  The B<--outdir> option can be used to change the root of
this work.

The B<--genall> option is used to tell generate-zones that it should
generate zones regardless of if it is marked as such in JazzHands.  Zones
will never be setup to be pushed to DNS servers if they are not
configured for auto-generation.  This option exists to see what a zone
may end up looking like it if it were auto generated.

The B<--forcegen> option skips the check to see if a zone has changed,
and generates a zone anyway.  Other options can influence if a zone
generation will happen, as well.  The SOA serial number will only be
incremented if the zone has changed, however, unless the B<--forcesoa>
option is used.

The B<--forcesoa> option causes the SOA serial number to be incremented
for any generated zones, even if there were no changes to the zone.
This option cannot be combined with the --nosoa option

The B<--force> option causes the zone to be forcibly regenerated and the
SOA serial number to be bumped.  This basically is a shorthand for the
B<--forcegen> and B<--forcesoa> options.  This is a different behavior
than used to be the case for forcing a zone, but most people always used
the two options together, so they were combined.

The B<--nosoa> prevents the serial number from ever being updated on a
Zone.  This option cannot be combined with the --forcesoa optoin.

The B<--dumpzone> takes one zone as an argument and will dump the zone
to stdout.  Note that it does NOT change the serial number if it's due
for updating, so it will match the last generation of the record.  This
is meant as an error checking aide.

generate-zones uses the rows of the dhcp_range, dns_domain,
dns_record, netblock, and network_interface tables in JazzHands to create
zones file.

The dns_domain table contains the typical information about a zone, from
the SOA data, including serial number, to hierarchical relationships
among zones.  It also contains a Y/N flag column, SHOULD_GENERATE and a
value, LAST_GENERATED, to indicate if a zone should be auto-generated by
this script, and the last time it was auto-generated.

The dns_record table contains all records for a given dns_domain.  It
contains typical values for a DNS entry, such as Type and Class, but
also contains a Netblock_id for resolving A records.  If the DNS_NAME
value is set to NULL, the record is assumed to share a name of another
record via the REFERENCE_DNS_RECORD_ID.  If this value is NULL, the record
is assumed to be for the zone.  This is, for example, how NS records are
populated.

Under normal circumstances, PTR records are not explicitly stored in
the db, but instead there is a dns_domain record for each inverse zone.
It has a dns_record of REVERSE_ZONE_BLOCK_PTR that indicates that the
netblock_id for the record, contains the base record for a netblock
that should be used to generate a reverse zone.  All A records matching
this base record will be used to generate a PTR record, unless the
should_generate_ptr flag is set to 'N' for a given A record.

Other records are set via the dns_value flag in the dns_record table.

The dhcp_range simply causes dns entries of the form dhcp<ip>, with
the dots translated to dashes in the appropriate zone (as ascertained
from the dns name of the network_interface record).  If a name is set
elsewhere in the db for an IP, that name will be favored over the
generated name in a dhcp entry.

=head1 ENVIRONMENT

The DBAUTHAL_DIR environment variable is used by JazzHands::DBI to determine
what database credentials to use.

=head1 AUTHORS

Todd Kover

=head1 SEE ALSO

named(9), L<JazzHands::DBI>, L<JazzHands::Common::Util>

=head1 BUGS

If an rsync fails to run, the next run may not notify the far end server
that a zone has changed and an 'rndc' never executed. rsync should
probably be replaced with 'rdist' or some other mechanism that causes the
command to be run when the new file is placed.  An alternative would be to
just run 'rndc reload', without zones, on the clients, which will cause it
to reload all zones.  This may have unintended side effects as well.

It may be desirable to push zones to nameservers that are not listed in the
zone as authoritative.  This does not generate files that make this
straightforward.
