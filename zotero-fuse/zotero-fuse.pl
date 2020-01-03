#!/usr/bin/perl -w
use strict;

# navigate through zotero collection hierarchy as file system
# example.pl and (e_getdir) lookback.pl.gz coming with Fuse.pm gave inspiration 

use ZoteroRoDB;
use Data::Dumper;
use DBI;
use File::Slurp;

$| = 1;

my $curid;
my %files;
my $curdirname;

ZoteroRoDB::init();
curid_root(0);

use Fuse qw(fuse_get_context);
use POSIX qw(ENOENT EISDIR EINVAL);

sub curid_root {

	my ($curid) = @_;
	print "curid_root($curid)\n";	
	%files = ();
	my %curfolder;
	ZoteroRoDB::folderdir(\%curfolder, $curid);
	ZoteroRoDB::folderfiles(\%curfolder, $curid);
	$files{'.'} = {
			cont => $curid,
			type => 0040,
			mode => 0555,
			ctime => time()
	};
	
	for my $file (sort keys %curfolder) {
		print "injecting $file\n";
		$files{$file} = {
			cont => $curfolder{$file},
			type => 0040,
			mode => 0555,
			ctime => time()
		}
	}
}

sub curid_dir {

	my ($curid) = @_;
	my $type; my $mode;
	print "curid_dir($curdirname)($curid)\n";	
	my @files = ('.');
	my %curfolder;
	# is folder 
	if ($curid =~ /^\d/) {
			ZoteroRoDB::folderdir(\%curfolder, $curid);
			ZoteroRoDB::folderfiles(\%curfolder, $curid);
			$type = 0040; # folder
			$mode = 0555;
	# is publication 
	} elsif ($curid =~ /^P/) {
			ZoteroRoDB::publicationfiles(\%curfolder, $curid);
			$type = 0100; # file 
			$mode = 0444;
	}
	for my $file (sort keys %curfolder) {
		print "injecting $file\n";
		$files{"$curdirname/$file"} = {
			cont => $curfolder{$file},
			type => $type,
			mode => $mode,
			ctime => time()
		};
		push @files, $file;
	}
	return (@files, 0);
}


sub filename_fixup {
	my ($file) = shift;
	print "filename_fixup (in:$file) - ";
	$file =~ s,^/,,;
	# $file =~ s/.*\/([^\/]*)$/$1/;
	$file = '.' unless length($file);
	print "filename_fixup (out:$file)\n";
	return $file;
}

sub e_getattr {
	my ($file) = filename_fixup(shift);
	$file =~ s,^/,,;
	$file = '.' unless length($file);
	return -ENOENT() unless exists($files{$file});
	my ($size) = exists($files{$file}{cont}) ? length($files{$file}{cont}) : 0;
	$size = $files{$file}{size} if exists $files{$file}{size};
	my ($modes) = ($files{$file}{type}<<9) + $files{$file}{mode};
	my ($dev, $ino, $rdev, $blocks, $gid, $uid, $nlink, $blksize) = (0,0,0,1,0,0,1,1024);
	my ($atime, $ctime, $mtime);
	$atime = $ctime = $mtime = $files{$file}{ctime};
	return ($dev,$ino,$modes,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks);
}

sub e_getdir {
	my ($odirname) = shift;
	my $dirname = filename_fixup($odirname);
	$curid = $files{$dirname}{cont};
	$curdirname = $dirname;
	print "e_getdir ($odirname) ($dirname) ($curid)";
	#my $file = filename_fixup($ofile);
	return curid_dir($curid);
}

sub e_open {
	# VFS sanity check; it keeps all the necessary state, not much to do here.
    my $file = filename_fixup(shift);
    my ($flags, $fileinfo) = @_;
    print("e_open called $file, $flags, $fileinfo\n");
	return -ENOENT() unless exists($files{$file});
	return -EISDIR() if $files{$file}{type} & 0040;

	my $pointer = $files{$file}{cont}; 
	# file has not been opened before, hence we read in the file 
	# 	content from the file system
	if ($pointer =~ /^F(-?.{8})F(.*)$/) {
		$pointer =~ /^F(-?.{8})F(.*)$/;
		my $source_folder = $1;
		my $source_filename = $2;
		print "(POINTER:$pointer($source_folder|$source_filename))\n";
		if ($source_folder =~ /^-/) {
			$source_folder =~ s/^-//;
	
			my $path = ZoteroRoDB::location() . "/storage/$source_folder/$source_filename";
			print "Reading content for \$files{$file}{cont} from $path\n";
			if (!-e $path) {
				# this check may be triggered if there are paths in 
				# zotero DB that are outdated (e.g. files got lost)
				print "Zoterofs reading error: $path does not exist\n"; 
			} else { 
				$files{$file}{cont} = read_file("$path");
			}
		}
	} 
    my $fh = [ rand() ];
    
    print("open ok (handle $fh)\n");
    return (0, $fh);
}

sub e_read {
	# return an error numeric, or binary/text string.  (note: 0 means EOF, "0" will
	# give a byte (ascii "0") to the reading program)
	my ($file) = filename_fixup(shift);
    my ($buf, $off, $fh) = @_;
    print "e_read from $file, $buf \@ $off\n";
    print "file handle:\n", Dumper($fh);
	return -ENOENT() unless exists($files{$file});
	if(!exists($files{$file}{cont})) {
		return -EINVAL() if $off > 0;
		my $context = fuse_get_context();
		return sprintf("pid=0x%08x uid=0x%08x gid=0x%08x\n",@$context{'pid','uid','gid'});
	}
	return -EINVAL() if $off > length($files{$file}{cont});
	return 0 if $off == length($files{$file}{cont});
	return substr($files{$file}{cont},$off,$buf);
}

sub e_statfs { return 255, 1, 1, 1, 1, 2 }

# If you run the script directly, it will run fusermount, which will in turn
# re-run this script.  Hence the funky semantics.
my ($mountpoint) = "";
$mountpoint = shift(@ARGV) if @ARGV;
Fuse::main(
	mountpoint=>$mountpoint,
	getattr=>"main::e_getattr",
	getdir =>"main::e_getdir",
	open   =>"main::e_open",
	statfs =>"main::e_statfs",
	read   =>"main::e_read",
	threaded=>0
);
