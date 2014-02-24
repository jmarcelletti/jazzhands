#!/bin/sh -e

tarroot=`pwd`

ROOT=..

RELEASEDIR=/tmp/releaseit.$$
mkdir $RELEASEDIR


for input in `cat releases | sed 's/#.*$//'` ; do
	dirname=`dirname $input`
	basename=`basename $input | sed s/.spec//`
	if [ `expr $input : '.*\.spec'` -eq 0 ] ; then
		echo 1>&2 $input is not a spec based release.  Unsupported.  DIE.
		exit 1
		rootname=$dirname
	else
		spec="$input"
		echo Processing $spec ...
		rootname=`rpm -q --specfile $ROOT/$spec --queryformat '%{name}-%{version}\n' | head -1`
	fi
	mkdir $RELEASEDIR/$rootname
	(cd $ROOT/$dirname ; tar cf - . ) | (cd $RELEASEDIR/$rootname ; tar xpf  - )
	(cd $RELEASEDIR ; tar zcf $tarroot/${rootname}.tar.gz $rootname )
done

rm -rf $RELEASEDIR/

exit 0