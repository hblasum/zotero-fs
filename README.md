zotero-fuse: FUSE implementation of Zotero FS
Mounts read-only file systesm.

To install, first install Perl user space FUSE file system and 
the daemon package.
"sudo apt-get install libfuse-perl libproc-daemon-perl".

To mount, call './zotero-fs'. The file system will be mounted at '/tmp/zotero'.
To unmount, call 'sudo umount /tmp/zotero'.

Limitations:
	* tested only on Linux 
	* files are read-only 
	* only local storage prefixed "storage:" (no cloud, no links)
	* only one local profile 
	* output of publication directories is only ASCII, other UTF-8 is filtered

License: LGPL v2.1 (same as Perl Fuse module).
