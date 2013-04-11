%define	prefix	/usr
%define	zgroot	libexec/jazzhands/zonegen
Summary:    jazzhands-zonegen-server - generates and pushes out zones
Vendor:     JazzHands
Name:       jazzhands-zonegen-server
Version:    0.52
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:	%{name}.tgz
BuildRoot:      %{_tmppath}/%{name}-root
BuildArch:	noarch
Requires:       jazzhands-perl-common, perl-JazzHands-DBI, bind
# bind is there for named-checkzone


%description
Generates zone and configuration from JazzHands database

%prep
%setup -q -n %{name}

%install

rm -rf %{buildroot}
mkdir -p %{buildroot}/%{prefix}/%{zgroot}
for file in do-zone-generation.sh generate-zones.pl ; do
	newfn=`echo $file | sed 's/\..*$//'`
	install -m 555  $file %{buildroot}/%{prefix}/%{zgroot}/$newfn
done

%clean
rm -rf %{buildroot}


%files
%defattr(755,root,root,-)

%{prefix}/%{zgroot}/do-zone-generation
%{prefix}/%{zgroot}/generate-zones

%post

if [ ! -d /var/lib/zonegen ] ; then 
	mkdir  -p /var/lib/zonegen/run
	mkdir  -p /var/lib/zonegen/auto-gen/perserver
	mkdir  -p /var/lib/zonegen/auto-gen/zones
	mkdir  -p /var/lib/zonegen/auto-gen/etc
	chown -R zonegen:zonegen /var/lib/zonegen/run
	chown -R zonegen:zonegen /var/lib/zonegen/auto-gen
fi

%changelog
* Thu Mar  7 2013 Todd Kover <kovert@omniscient.com> 0.52-1
- initial release
