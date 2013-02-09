#!/usr/bin/env perl
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

use strict;
use warnings;
use POSIX;
use Data::Dumper;
use Carp;
use JazzHands::STAB;
use JazzHands::GenericDB qw(_dbx);

do_dns_toplevel();

sub do_dns_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $dnsid = $stab->cgi_parse_param('dnsdomainid');

	if ( !defined($dnsid) ) {

		# dump_all_zones($stab,$cgi,$dbh);
		dump_all_zones_dropdown($stab);
	} else {
		dump_zone( $stab, $dnsid );
	}
}

sub dump_all_zones_dropdown {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html({-title=>"DNS Zones", -javascript => 'dns'}), "\n";


	print $cgi->h4( { -align => 'center' }, "Find a Zone" );
	print $cgi->start_form( { -action => "search.pl" } );
	print $cgi->start_table( { -align => 'center' } );
	print $stab->build_tr( undef, undef, "b_dropdown", "Zone",
		'DNS_DOMAIN_ID' );
	print $cgi->Tr(
		{ -align => 'center' },
		$cgi->td(
			{ -colspan => 2 },
			$cgi->submit(
				-name  => "Zone",
				-value => "Go to Zone"
			)
		)
	);
	print $cgi->end_table;
	print $cgi->end_form;

	print $cgi->hr;

	print $cgi->h4( { -align => 'center' },
		$cgi->a( { -href => "addazone.pl" }, "Add A Zone" ) );

	print $cgi->hr;

	print $cgi->h4( { -align => 'center' },
		"Reconcile non-autogenerated zones" );
	print $cgi->start_form(
		{ -action => "dns-reconcile.pl", -method => 'GET' } );
	print $cgi->start_table( { -align => 'center' } );
	print $stab->build_tr( { -only_nonauto => 'yes' },
		undef, "b_dropdown", "Zone", 'DNS_DOMAIN_ID' );
	print $cgi->Tr(
		{ -align => 'center' },
		$cgi->td(
			{ -colspan => 2 },
			$cgi->submit(
				-name  => "Zone",
				-value => "Go to Zone"
			)
		)
	);
	print $cgi->end_table;
	print $cgi->end_form;

	print $cgi->end_html, "\n";
}

sub dump_all_zones {
	my ( $stab, $cgi, $dbh ) = @_;

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html({-title=>"DNS Zones", -javascript => 'dns'}), "\
n";


	my $q = qq{
		select 	dns_domain_id,
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
			should_generate,
			last_generated
		  from	dns_domain
		order by soa_name
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err($dbh);
	$sth->execute || return $stab->return_db_err($sth);

	my $maxperrow = 4;

	print $cgi->start_table( { -border => 1, -align => 'center' } ), "\n";

	my $curperrow = -1;
	my $rowtxt    = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( ++$curperrow == $maxperrow ) {
			$curperrow = 0;
			print $cgi->Tr($rowtxt), "\n";
			$rowtxt = "";
		}

		if ( !defined( $hr->{_dbx('LAST_GENERATED')} ) ) {
			$hr->{_dbx('LAST_GENERATED')} = $cgi->escapeHTML('<never>');
		}

		my $xbox =
		  $stab->build_checkbox( $hr, "ShouldGen", "SHOULD_GENERATE",
			'DNS_DOMAIN_ID' );

		$stab->textfield_sizing(0);
		my $serial =
		  $stab->b_textfield( $hr, 'SOA_SERIAL', 'DNS_DOMAIN_ID' );
		my $refresh =
		  $stab->b_textfield( $hr, 'SOA_REFRESH', 'DNS_DOMAIN_ID' );
		my $retry =
		  $stab->b_textfield( $hr, 'SOA_RETRY', 'DNS_DOMAIN_ID' );
		my $expire =
		  $stab->b_textfield( $hr, 'SOA_EXPIRE', 'DNS_DOMAIN_ID' );
		my $minimum =
		  $stab->b_textfield( $hr, 'SOA_MINIMUM', 'DNS_DOMAIN_ID' );
		$stab->textfield_sizing(1);

		my $link = build_dns_link( $stab, $hr->{_dbx('DNS_DOMAIN_ID')} );
		my $zone = $cgi->a( { -href => $link }, $hr->{_dbx('SOA_NAME')} );

		my $entry = $cgi->table(
			{ -width => '100%', -align => 'top' },
			$cgi->Tr(
				$cgi->td(
					{
						-align => 'center',
						-style => 'background: green'
					},
					$cgi->b($zone)
				)
			),

			#$cgi->Tr($cgi->td("Serial: ", $serial )),
			#$cgi->Tr($cgi->td("Refresh: ", $refresh )),
			#$cgi->Tr($cgi->td("Retry: ", $retry )),
			#$cgi->Tr($cgi->td("Expire: ", $expire )),
			#$cgi->Tr($cgi->td("Minimum: ", $minimum )),
			$cgi->Tr(
				$cgi->td( "LastGen:", $hr->{_dbx('LAST_GENERATED')} )
			),
			$cgi->Tr( $cgi->td($xbox) )
		) . "\n";

		$rowtxt .= $cgi->td( { -valign => 'top' }, $entry );
	}
	print $cgi->Tr($rowtxt), "\n";
	print $cgi->end_table;
	print $cgi->end_html, "\n";

	$sth->finish;
	$dbh = undef;
}

sub zone_dns_records {
	my ( $stab, $dnsdomainid ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $q = qq{
		select	dns.dns_record_id,
				dns.dns_name,
				dns.dns_domain_id,
				dns.dns_ttl,
				dns.dns_class,
				dns.DNS_TYPE,
				dns.dns_value,
				dns.is_enabled,
				dns.should_generate_ptr,
				nb.netblock_id,
				net_manip.inet_dbtop(nb.ip_address) as IP
		 from 	dns_record dns
				inner join val_dns_type vdt on
					dns.dns_type = vdt.dns_type
				left join netblock nb
					on nb.netblock_id = dns.netblock_id
		where	vdt.id_type in ('ID', 'NON-ID')
		  and	dns.dns_name is NULL
		  and	dns.reference_dns_record_id is null
		  and	dns.dns_domain_id = ?
		order by dns.dns_type
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err($dbh);
	$sth->execute($dnsdomainid) || return $stab->return_db_err($sth);

	while ( my $hr = $sth->fetchrow_hashref ) {
		print build_fwd_zone_Tr( $stab, $hr, 1 );
	}
	$sth->finish;
}

sub build_fwd_zone_Tr {
	my ( $stab, $hr, $iszone ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";

	my $ttl =
	  $stab->b_offalwaystextfield( $hr, 'DNS_TTL', 'DNS_RECORD_ID' );
	$stab->textfield_sizing(0);

	my $value = "";
	my $name  = "";
	my $class = "";
	my $type  = "";

	if ( defined($hr) && defined( $hr->{_dbx('DNS_NAME')} ) ) {
		$name = $hr->{_dbx('DNS_NAME')};
	}
	my $showexcess = 1;
	my $ttlonly    = 0;
	if ( defined($hr) && $hr->{_dbx('DEVICE_ID')} ) {
		$showexcess = 0 if ( $hr->{_dbx('SHOULD_GENERATE_PTR')} eq 'Y' );
		$ttlonly = 1;
		my $link = "../device/device.pl?devid=" . $hr->{_dbx('DEVICE_ID')};
		$name = $cgi->a( { -href => $link }, $name );

	   #$class = $stab->b_dropdown(undef, $hr, 'DNS_CLASS', 'DNS_CLASS', 1);
	   #$type = $stab->b_dropdown(undef, $hr, 'DNS_TYPE', 'DNS_TYPE', 1);
		$class = $hr->{_dbx('DNS_CLASS')};
		$type  = $hr->{_dbx('DNS_TYPE')};
		$value = $hr->{_dbx('DNS_VALUE')};
		if ( defined($hr) && $hr->{_dbx('DNS_TYPE')} eq 'A' ) {
			$value = $hr->{_dbx('IP')};
		}
	} elsif ( !defined($iszone) ) {
		$name = $stab->b_textfield( $hr, 'DNS_NAME', 'DNS_RECORD_ID' );
		$class =
		  $stab->b_dropdown( $hr, 'DNS_CLASS', 'DNS_RECORD_ID', 1 );
		$type =
		  $stab->b_dropdown( $hr, 'DNS_TYPE', 'DNS_RECORD_ID', 1 );
		$value = $stab->b_textfield( { -textfield_width => 40 },
			$hr, 'DNS_VALUE', 'DNS_RECORD_ID' );
		if ( defined($hr) && $hr->{_dbx('DNS_TYPE')} eq 'A' ) {

			# [XXX] hack hack hack, needs to be fixed right.
			$hr->{_dbx('DNS_VALUE')} = $hr->{_dbx('IP')};
			$value = $stab->b_textfield( $hr, 'DNS_VALUE',
				'DNS_RECORD_ID' );
		}
	} else {
		$value = $stab->b_textfield( { -textfield_width => 40 },
			$hr, 'DNS_VALUE', 'DNS_RECORD_ID' );
		if ( defined($hr) && $hr->{_dbx('DNS_TYPE')} eq 'A' ) {

			# [XXX] hack hack hack, needs to be fixed right.
			$hr->{_dbx('DNS_VALUE')} = $hr->{_dbx('IP')};
			$value = $stab->b_textfield( $hr, 'DNS_VALUE',
				'DNS_RECORD_ID' );
		}
		$class =
		  $stab->b_dropdown( $hr, 'DNS_CLASS', 'DNS_RECORD_ID', 1 );
		$type =
		  $stab->b_dropdown( $hr, 'DNS_TYPE', 'DNS_RECORD_ID', 1 );
	}

	my $excess = "";
	if ($showexcess) {
		if ( defined($hr) ) {
			$excess .= $cgi->checkbox(
				{
					-name => "Del_"
					  . $hr->{_dbx('DNS_RECORD_ID')},
					-label => 'Delete',
				}
			);
		} else {
			$excess .= "(Add)";
		}
	}
	if ( $ttlonly && defined($hr) ) {
		$excess .= $cgi->hidden(
			{
				-name  => "ttlonly_" . $hr->{_dbx('DNS_RECORD_ID')},
				-value => 'ttlonly'
			}
		);
	}

	my $hidden = "";
	if ($hr) {
		$hidden = $cgi->hidden(
			{
				-name => "DNS_RECORD_ID_"
				  . $hr->{_dbx('DNS_RECORD_ID')},
				-value => $hr->{_dbx('DNS_RECORD_ID')}
			}
		);
	}

	my $enablebox = $stab->build_checkbox( { -default => 'Y' },
		$hr, "", "IS_ENABLED", 'DNS_RECORD_ID' );

	$stab->textfield_sizing(1);
	return $cgi->Tr(
		$cgi->td( $hidden, $enablebox ), $cgi->td($name),
		$cgi->td($ttl),  $cgi->td($class),
		$cgi->td($type), $cgi->td($value),
		$cgi->td($excess)
	);
}

sub zone_fwd_records {
	my ( $stab, $dnsdomainid ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $q = qq{
		select	dns.dns_record_id,
				dns.dns_name,
				dns.dns_domain_id,
				dns.dns_ttl,
				dns.dns_class,
				dns.DNS_TYPE,
				dns.dns_value,
				dns.netblock_id,
				dns.should_generate_ptr,
				dns.is_enabled,
				nb.netblock_id,
				net_manip.inet_dbtop(nb.ip_address) as IP,
				ni.device_id
		 from 	dns_record dns
				inner join val_dns_type vdt on
					dns.dns_type = vdt.dns_type
				left join netblock nb
					on nb.netblock_id = dns.netblock_id
				left join network_interface ni
					on ni.v4_netblock_id = nb.netblock_id
		where	vdt.id_type in ('ID', 'NON-ID')
		  and	
				(	
					dns.dns_name is not NULL
				or
		  			dns.reference_dns_record_id is not null
				)
		  and	dns.dns_domain_id = ?
		order by dns.dns_name
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err($dbh);
	$sth->execute($dnsdomainid) || return $stab->return_db_err($sth);

	while ( my $hr = $sth->fetchrow_hashref ) {
		print build_fwd_zone_Tr( $stab, $hr );
	}
	$sth->finish;
}

sub zone_rvs_records {
	my ( $stab, $dnsdomainid ) = @_;

	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $q = qq{
		select  distinct nb.ip_address,
			net_manip.inet_dbtop(nb.ip_address) as ip,
			dns.dns_name,
			dns.is_enabled,
			dom.soa_name,
			net_manip.inet_dbtop(
				net_manip.inet_base(nb.ip_address,  
				nb.netmask_bits)) as ip_base,
			nb.netmask_bits as netmask_bits,
			ni.device_id
		  from  netblock nb
				inner join dns_record dns
					on nb.netblock_id = dns.netblock_id
				inner join dns_domain dom
					on dns.dns_domain_id =
						dom.dns_domain_id
				left join network_interface ni
					on ni.v4_netblock_id = nb.netblock_id,
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
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err($dbh);
	$sth->execute($dnsdomainid) || return $stab->return_db_err($sth);

	$stab->textfield_sizing(0);
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $lastoctet = ( split( /\./, $hr->{_dbx('IP')} ) )[3];

		# only print the shortname if it is actually set.
		my $name = (
			defined( ( $hr->{_dbx('DNS_NAME')} ) )
			? $hr->{_dbx('DNS_NAME')} . "."
			: "" )
		  . $hr->{_dbx('SOA_NAME')} . ".";

		my $ttl   = "";
		my $class = 'IN';
		my $type  = 'PTR';
		my $value =
		  $stab->b_textfield( $hr, 'DNS_VALUE', 'DNS_RECORD_ID' );
		if ( $hr && $hr->{_dbx('DNS_TYPE')} && $hr->{_dbx('DNS_TYPE')} eq 'A' ) {
			$value =
			  $stab->b_textfield( $hr, 'IP', 'DNS_RECORD_ID' );
		}

		if ( $hr->{_dbx('DEVICE_ID')} ) {
			my $link =
			  "../device/device.pl?devid=" . $hr->{_dbx('DEVICE_ID')};
			$name = $cgi->a( { -href => $link }, $name );
		}

	      #
	      # at this point, we don't want direct manipulation of PTR records.
	      #
		my $button = "";
		if ( 0 && defined($hr) && defined( $hr->{_dbx('DNS_RECORD_ID')} ) ) {

			# [XXX] these aren't buttons now, but rather
			# a delete check box...
			$button = $cgi->submit(
				{
					-name => "Update_"
					  . $hr->{_dbx('DNS_RECORD_ID')},
					-value => 'Update'
				}
			);
			$button .= $cgi->submit(
				{
					-name => "Del_"
					  . $hr->{_dbx('DNS_RECORD_ID')},
					-value => 'Delete'
				}
			);
		}

		my $hidden = "";
		if ( $hr && $hr->{_dbx('DNS_RECORD_ID')} )
		{    # should not need the && case?
			$hidden = $cgi->hidden(
				{
					-name => "DNS_RECORD_ID_"
					  . $hr->{_dbx('DNS_RECORD_ID')},
					-value => $hr->{_dbx('DNS_RECORD_ID')}
				}
			);
		}

		# this is disabled at present since disabling from the forward
		# record likely makes more sense.
		#my $enablebox = $stab->build_checkbox({-default=>'Y'},
		#	$hr, "", "IS_ENABLED", 'DNS_RECORD_ID');
		my $enablebox = "";

		print $cgi->Tr(
			$cgi->td(
				[
					$enablebox, $lastoctet, $ttl,
					$class,     $type,      $name,
					$button,
				]
			),
		);
	}
	$stab->textfield_sizing(1);
	$sth->finish;
}

sub dump_zone {
	my ( $stab, $dnsdomainid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $q = qq{
		select 	d1.dns_domain_id,
			d1.soa_name,
			d1.soa_class,
			d1.soa_ttl,
			d1.soa_serial,
			d1.soa_refresh,
			d1.soa_retry,
			d1.soa_expire,
			d1.soa_minimum,
			d1.soa_mname,
			d1.soa_rname,
			d1.should_generate,
			d1.parent_dns_domain_id,
			d2.soa_name as parent_soa_name,
			d1.last_generated
		  from	dns_domain d1
				left join dns_domain d2 on
					d1.parent_dns_domain_id = d2.dns_domain_id
		where	d1.dns_domain_id = ?
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err($dbh);
	$sth->execute($dnsdomainid) || return $stab->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !defined($hr) ) {
		$stab->error_return("Unknown Domain");
	}

	my $title = $hr->{_dbx('SOA_NAME')};
	$title .= " (Auto Generated) " if ( $hr->{_dbx('SHOULD_GENERATE')} eq 'Y' );

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html({-title=> $title, -javascript => 'dns'} ), "\n";
	print $cgi->start_form( { -action => "write/update_domain.pl" } );
	print $cgi->hidden(
		-name    => 'DNS_DOMAIN_ID',
		-default => $hr->{'DNS_DOMAIN_ID'}
	);

	my $lastgen = 'never';
	if(defined($hr->{_dbx('LAST_GENERATED')})) {
		$lastgen = $hr->{_dbx('LAST_GENERATED')};
	}

	print $cgi->hr;
	print $cgi->start_table( { -align => 'center', -border => 1 } );
	print $cgi->Tr(
		$cgi->td( "Last Generated: $lastgen") );
	my $autogen = "";
	if ( $hr->{_dbx('SHOULD_GENERATE')} eq 'Y' ) {
		$autogen = "Turn Off Autogen";
	} else {
		$autogen = "Turn On Autogen";
	}
	print $cgi->Tr(
		{ -align => 'center' },
		$cgi->td(
			$cgi->submit(
				{
					-align => 'center',
					-name  => "AutoGen",
					-value => $autogen
				}
			)
		)
	);
	print $cgi->end_table;

	my $parlink = "--none--";
	if ( $hr->{_dbx('PARENT_DNS_DOMAIN_ID')} ) {
		my $url =
		  build_dns_link( $stab, $hr->{_dbx('PARENT_DNS_DOMAIN_ID')} );
		my $parent =
		  ( $hr->{_dbx('PARENT_SOA_NAME')} )
		  ? $hr->{_dbx('PARENT_SOA_NAME')}
		  : "unnamed zone";
		$parlink = $cgi->a( { -href => $url }, $parent );
	}
	$parlink = $cgi->span( $cgi->b("Parent: ") . $parlink );
	my $nblink = build_reverse_association_section( $stab, $dnsdomainid );

	if ( $nblink && length($nblink) ) {
		$nblink = $cgi->br($nblink);
	}

	print $cgi->div( { -align => 'center' }, $parlink, $nblink );

	print $cgi->hr;

	print $stab->zone_header( $hr, 'update' );
	print $cgi->submit(
		{
			-align => 'center',
			-name  => "SOA",
			-value => "Submit SOA Changes"
		}
	);
	print $cgi->end_form;

	print $cgi->hr;

	#
	# second form, second table
	#
	print $cgi->start_form( { -action => "update_dns.pl" } );
	print $cgi->start_table;
	print $cgi->hidden(
		-name    => 'DNS_DOMAIN_ID',
		-default => $hr->{'DNS_DOMAIN_ID'}
	);

	print $cgi->Tr(
		$cgi->th(
			[ 'Enable', 'Record', 'TTL', 'Class', 'Type', 'Value' ]
		)
	);

	zone_dns_records( $stab, $hr->{_dbx('DNS_DOMAIN_ID')} );
	print build_fwd_zone_Tr($stab);

	zone_fwd_records( $stab, $hr->{_dbx('DNS_DOMAIN_ID')} );
	zone_rvs_records( $stab, $hr->{_dbx('DNS_DOMAIN_ID')} );

	print $cgi->end_table;
	print $cgi->submit(
		{
			-align => 'center',
			-name  => "Records",
			-value => "Submit DNS Record Changes"
		}
	);
	print $cgi->end_form;
}

sub build_reverse_association_section {
	my ( $stab, $domid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $dbh = $stab->dbh || die "Could not create dbh";

	my $q = qq{
		select	d.netblock_id,
			net_manip.inet_dbtop(nb.ip_address),
			nb.netmask_bits
		  from	dns_record d
			inner join netblock nb
				on nb.netblock_id = d.netblock_id
		 where	d.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		   and	d.dns_domain_id = ?
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err($dbh);
	$sth->execute($domid) || return $stab->return_db_err($sth);

	my $linkage = "";
	while ( my ( $nbid, $ip, $bits ) = $sth->fetchrow_array ) {
		$linkage =
		  $cgi->a( { -href => "../netblock/?nblkid=$nbid" },
			"$ip/$bits" );
	}
	$linkage = $cgi->b("Reverse Linked Netblock:") . $linkage if ($linkage);
	$sth->finish;
	$linkage;
}

sub build_dns_link {
	my ( $stab, $dnsdomainid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $n = new CGI($cgi);
	$n->param( 'dnsdomainid', $dnsdomainid );
	$n->self_url;
}
