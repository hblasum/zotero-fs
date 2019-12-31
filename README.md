zotero-fuse: FUSE implementation of Zotero FS
Mounts read-only fise 

To install, first install Perl user space FUSE file system and 
the daemon package.
"sudo apt-get install libfuse-perl libproc-daemon-perl".

To mount, call './zotero-fs'. The file system will be mounted at '/tmp/zotero'.
To unmount, call 'sudo umount /tmp/zotero'.

License: LGPL v2.1 (same as Perl Fuse module).
