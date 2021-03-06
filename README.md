zotero-fs: file system interface to local Zotero database
=========================================================

Zotero is a reference manager tool (https://www.zotero.org/).

This program copies a zotero.sqlite database to /tmp and mounts 
that copy as read-only file system. It uses the FUSE user-space
file system.

Technology readiness level: proof-of-concept.

Note that if you are interested in this program, you also might 
be interested in the much more mature ZotFile plugin (https://www.zotfile.com),
which is also likely to address your needs, e.g. you also can mirror the 
collection hierarchy with it or put everything into a flat folder. ZotFile 
and this program can be combined (e.g. you can use ZotFile to have a good 
file name structure and this program for an additional view on it).

Use cases
=========

	* analyze/browse a Zotero collection hierarchy with file system tools
	* symlink often-used files/collections directly into your file system 
		(if you want instant access, after remount, run "find" from 
		/tmp/zotero; for automatizing this, incomment last line from 
		zotero-fs/zotero-fs)

Limitations
===========

	* tested only on Linux 
	* operates on copy of zotero.sqlite, hence newer changes in 
		zotero DB since last mount are not reflected
	* only is aware of collections and files that are in those
		collections
	* files are read-only 
	* no notes
	* only local storage prefixed "storage:" and absolute paths ("zotero
		links", cloud not tested and probably not working out 
		of the box)
	* only one local profile 
	* output of publication directories is only ASCII, other UTF-8 is filtered
	* file size is given as not accurate in directory listings
	* debugging output is overly verbose

Features
========

	* represent collection hierarchy
	* give name of authors as file names
	* files are only read in when opened, to allow quick perusal

Installation
============
	
	* To install, first install Perl user space FUSE file system, the  
		daemon package, SQLite3 interface, Slurp module for handling
		complete files, (if not already installed) git. At least in 
		Debian, all this is pre-packaged as follows.
		"sudo apt-get install libfuse-perl libproc-daemon-perl libdbd-sqlite3-perl libfile-slurp-perl git"
	* git clone https://github.com/hblasum/zotero-fs
	* zotero-fs/zotero-fs
	* ls /tmp/zotero # collection hierarchy should be visible
	* debugging/logging output in /tmp/zotero-fs-debug.txt and 
		/tmp/zotero-fs-output.txt

Use 
===	

	* To mount, call './zotero-fs'. The file system will be mounted 
		at '/tmp/zotero'.
	* To unmount, call 'sudo umount /tmp/zotero'.

Implementation/hacking
======================

	* zotero-fs is based on the fuse user file system implementation
		and the Perl Fuse module.
	* ZoteroRoDB.pm operates on the zotero database ("model");
		zotero-fuse/zotero-fuse.pl ("view") creates a virtual file 
		system based on fuse; zotero-fs is just a start script for 
		starting the daemon running zotero-fuse.pl. File operations 
		coming from the user ("ls", "cd", "find", ...) act as controller.
	* within the virtual file system, ZoteroRoDB.pm uses records to 
		pass file content of collections / publication entries 
		to zotero-fuse.pl. 
	* alternatively, ZoteroRoDB.pm could be written to operate on 
		some Zotero API rather than the direct database.

Changelog
=========
* 2021-01-02: replaced hardcoding of database fields for title and date by lookup in "fields" table; added functionality to follow absolute paths 

License: LGPL v2.1 (same as Perl Fuse module) or Affero GPL 3 
	(same as Zotero) or Creative Commons Zero (CC0), at your choice.
Contact: holger-r-zotero-fs@blasum.net (Holger).
The idea of "virtual drive for the storage folder", including use of
FUSE, has been discussed before: e.g. https://forums.zotero.org/discussion/6474/zotero-for-document-management 

As mentioned before, note that if you are interested in this program, because you
want to enhance the default Zotero storage structure, you also might 
be interested in the much more mature ZotFile plugin (https://www.zotfile.com), which
works differently by putting attachment directly into more human-readable locations.
ZotFile and zotero-fs can also be used together (e.g. you can start with using 
ZotFile and then add mount with zotero-fs for an additional view).
