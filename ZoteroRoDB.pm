#!/usr/bin/perl

# zotero 5.x query

# recursive path lookup
#  sqlite3 /tmp/zotero.sqlite
# .tables
# .schema mytable


use strict;
package ZoteroRoDB;
use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $dbh;

sub init {

	# get path of zotero database
	my $profile_name = `grep Path ~/.zotero/zotero/profiles.ini`;
	chomp $profile_name;
	$profile_name =~ /Path=(.*)/;
	my $zotero_sql_path = `grep 'extensions.zotero.dataDir' ~/.zotero/zotero/$1/prefs.js`;
	$zotero_sql_path =~ /user_pref\("extensions\.zotero\.dataDir", "(.*)"\)/;

	
	if ( ! ( -e "/tmp/zotero.sqlite")) {
    	`cp /$1/zotero/zotero.sqlite /tmp`;
	}

	$dbh = DBI->connect("dbi:SQLite:dbname=/tmp/zotero.sqlite",  undef, undef, { sqlite_open_flags => SQLITE_OPEN_READONLY, sqlite_use_immediate_transaction => 1, }) or die "$DBI::errstr";

}

sub folderdir { 
	my ($a2, $itemid) = @_;
	my $query = $itemid ? "='$itemid'" : "is null";
	my $array = $dbh->selectall_arrayref("
	select collectionName, collectionID from collections where parentCollectionId $query");
	%$a2 = ();
    for my $file (@$array) {
    	$$a2{$$file[0]} = $$file[1];
	}
} 

sub parent {

	my ($dbh, $id, $counter, $result) = @_;
	# recursion bound
	if ($counter > 10) {return;}
    my $meta_data = $dbh->selectall_arrayref("select parentCollectionID, collectionName from collections where collectionID = '$id';");
	for my $meta(@$meta_data) {
	   	# print "\nhi($counter)($$meta[0])($$meta[1])";
		$$result = $$meta[1] . "/" . $$result;
		parent ($dbh, $$meta[0], $counter++, $result); 
	}
}

1;
