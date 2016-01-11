%define prefix	/usr/share/php

Name:   	php-jazzhands-appauthal
Version:        __VERSION__
Release:        1%{?dist}
Summary:        JazzHands App Authorization Abstraction Layer for php
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:	noarch
#BuildRequires: 
Requires:      	php

%description

Rudimentary AppAuthAL database auth module for jazzhands 

%prep
%setup -q -n %{name}-%{version}
make -f Makefile.jazzhands

%install
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} PREFIX=%{prefix} install

%clean
make -f Makefile.jazzhands clean

%files
%defattr(755,root,root,-)
%{prefix}/jazzhands/dbauth.php
