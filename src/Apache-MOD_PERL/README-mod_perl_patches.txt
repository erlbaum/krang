README: Patches to apache, mod_perl and mod_ssl

1. apache 1.3.41 - upgrade to 1.3.42 and patch

To upgrade Krang to build on CentOS 7, apache 1.3.41 had to be upgraded
because it would no longer compile, due to an error in Apache::Symbol
that is fixed in the latest (and probably the last, ever) release of
Apache 1.3x, so we grab that from:

  https://archive.apache.org/dist/httpd/apache_1.3.42.tar.gz

But it has a build problem on CentOS 6 & 7, a conflict with the function
"getline" -- that was found and fixed by this guy: 

  http://jamesnorthway.net/notes/compiling_apache_1_3_centos6.txt

So we apply his fix, which is to rename the getline function:

  krang$ cd src/Apache-MOD_PERL
  src/Apache-MOD_PERL$ tar -xzf apache_1.3.42.tar.gz
  src/Apache-MOD_PERL$ cd apache_1.3.42/src/support/
  src/Apache-MOD_PERL/apache_1.3.42/src/support$ find ./ -type f | xargs sed -i 's/getline/apache_getline/'

And then tar that all back up again:

  src/Apache-MOD_PERL/apache_1.3.42/src/support$ cd ../../../
  src/Apache-MOD_PERL$ rm apache_1.3.42.tar.gz
  src/Apache-MOD_PERL$ tar -czf apache_1.3.42.tar.gz apache_1.3.42/
  src/Apache-MOD_PERL$ rm -rf apache_1.3.42/


1. mod_perl 1.31 - Make our own 1.32 release from its subversion repo

Unfortunately, Apache::Symbol won't compile in mod_perl 1.31 either:

  /usr/bin/perl /root/src/krang/lib/ExtUtils/xsubpp  -typemap
  /usr/share/perl5/ExtUtils/typemap  Symbol.xs > Symbol.xsc && mv
  Symbol.xsc Symbol.c
  gcc -c   -D_REENTRANT -D_GNU_SOURCE -fno-strict-aliasing -pipe 
  -fstack-protector -I/usr/local/include -D_LARGEFILE_SOURCE 
  -D_FILE_OFFSET_BITS=64 -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2
  -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4
  -grecord-gcc-switches -m64 -mtune=generic   -DVERSION=\"1.31\"
  -DXS_VERSION=\"1.31\" -fPIC "-I/usr/lib64/perl5/CORE"   Symbol.c
  Symbol.xs: In function ‘undef’:
  Symbol.xs:33:11: error: lvalue required as left operand of assignment
   CvGV(cv) = gv;   /* let user-undef'd sub keep its identity */
          ^
  make[1]: *** [Symbol.o] Error 1
  make[1]: Leaving directory `src/krang/tmp/cQpyGtuJv0/mod_perl-1.31/Symbol'
  make: *** [subdirs] Error 2
  mod_perl make failed: 512 at src/krang/lib/Krang/Platform.pm line 767.


but, unlike apache, there was no subsequent mod_perl "1.32" release to
distribute a fix.  It was fixed, however on the "1.x" branch of
mod_perl's svn repository, so we check out this this "bleeding edge",
unreleased version of mod_perl 1.x from svn:

  src/Apache-MOD_PERL$ svn checkout http://svn.apache.org/repos/asf/perl/modperl/branches/1.x mod_perl-1.32

and craft our own home-grown mod_perl 1.32 release package, like this:

  src/Apache-MOD_PERL$ find mod_perl-1.32/ -type d | grep .svn | xargs rm -rf
  src/Apache-MOD_PERL$ tar -czf mod_perl-1.32.tar.gz mod_perl-1.32/
  src/Apache-MOD_PERL$ rm -r mod_perl-1.32/
  src/Apache-MOD_PERL$ rm mod_perl-1.31.tar.gz


and now we can build apache 1.3x and mod_perl successfully!

...unless you want to run krang_build --with-ssl

Then soldier on:

3. mod_ssl - bump the version of apache it expects and install openssl

The 1st error:

  Configuring mod_ssl/2.8.31 for Apache/1.3.41
  ./configure:Error: The mod_ssl/2.8.31 can be used for Apache/1.3.41 only.

So we just need to tell it to build against the new apache-1.3.42:
(this fix also from https://jamesnorthway.net/notes/compiling_apache_1_3_centos6.txt)

  src/Apache-MOD_PERL$ tar -xzf mod_ssl-2.8.31-1.3.41.tar.gz
  src/Apache-MOD_PERL$ sed -i 's/3.41/3.42/' mod_ssl-2.8.31-1.3.41/pkg.sslmod/libssl.version
  src/Apache-MOD_PERL$ rm mod_ssl-2.8.31-1.3.41.tar.gz
  src/Apache-MOD_PERL$ tar -czf mod_ssl-2.8.31-1.3.41.tar.gz mod_ssl-2.8.31-1.3.41/
  src/Apache-MOD_PERL$ rm -rf mod_ssl-2.8.31-1.3.41/

2nd Error:

  Error: Cannot find SSL binaries in /krang/lib/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

After some trial and error wrt the version and config params:

  # wget ftp://ftp.openssl.org/source/old/0.9.x/openssl-0.9.8zh.tar.gz
  cd src/Apache-MOD_PERL/
  tar -xvzf openssl-0.9.8zh.tar.gz -C /usr/src 
  cd /usr/src/openssl-0.9.8zh/
  ./config --prefix=/usr     \
       --openssldir=/etc/ssl \
       --libdir=lib          \
       shared                \
       zlib-dynamic          \
       && make depend        \
       && make -j1           \
       && make install       \
       && echo DONE

Then you can finally

  bin/krang_build --with-ssl

and get a

  Build complete!


