Maatkit includes source code for some user-defined functions (UDFs) for faster checksums.  These create a new SQL function inside the MySQL server.  Tools that do checksumming of data (mk-table-checksum, mk-table-sync) will use these functions if they are installed.  These are much faster and have better data distribution than CRC32() or MD5() or similar, which are the default functions built into MySQL.

The source code for the UDFs is available in trunk/maatkit/udf, or distributed with the downloads of the Maatkit tools.  Binary compiled UDFs are also distributed through Percona's Yum and APT repositories (see http://www.percona.com/docs/wiki/repositories:start).

# Installation #

To install the UDFs, you must compile the source (or use a binary distribution, such as Percona's).  This is generally straightforward, and is covered below.  Once you have a binary .so file, copy it to either a) in your LD\_LIBRARY\_PATH, or b) the server's plugin\_dir, depending on the server version.  This is generally /usr/lib/.

Then, execute one of the following commands, depending on the function you are trying to install:

```
mysql mysql -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'fnv_udf.so'"
mysql mysql -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'fnv1a_udf.so'"
mysql mysql -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'murmur_udf.so'"
```

Confirm that the installation succeeded by running a command such as `SELECT fnv_64('hello world')`.

Troubleshooting:

  * If you get the error "ERROR 1126 (HY000): Can't open shared library 'fnv\_udf.so' (errno: 22 fnv\_udf.so: cannot open shared object file: No such file or directory)" then you may need to copy the .so file to another location in your system.   Try both /lib and /usr/lib.  Look at your environment's $LD\_LIBRARY\_PATH variable for clues.  If none is set, and neither /lib nor /usr/lib works, you may need to set LD\_LIBRARY\_PATH to /lib or /usr/lib.
  * If you get the error "ERROR 1126 (HY000): Can't open shared library 'libfnv\_udf.so' (errno: 22 /lib/libfnv\_udf.so: undefined symbol: gxx\_personality\_v0)" then you may need to use g++ instead of gcc in the compilation instructions below.

# Compilation #

You need the MySQL header files installed to compile, and of course you need a C compiler.  The following instructions are for the fnv\_udf.cc file, and you should adapt them for any other UDF you want to compile.

Compilation is generally very simple:

```
gcc -fPIC -Wall -I/usr/include/mysql -shared -o fnv_udf.so fnv_udf.cc
```

For MySQL version 4.1 or older you must add the following flag to the gcc command above: `-DNO_DECIMAL_RESULT`  Otherwise you will get an error like this: `fnv_udf.cc:167: `DECIMAL\_RESULT' undeclared (first use this function)`  More details on this are in [issue 89](https://code.google.com/p/maatkit/issues/detail?id=89).

On Mac OSX, use -dynamiclib instead of -shared, and add -lstdc++ to the compile flags.

You might need to use g++ instead of gcc on some systems (see the troubleshooting steps in the installation instructions above).