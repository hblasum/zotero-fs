#!/usr/bin/perl

# zotero 5.x query

# recursive path lookup
#  sqlite3 /tmp/zotero.sqlite
# .tables
# .schema mytable

# NB: instead of raw SQL invocations it would 
# be better to use Zotero API


use strict;
package ZoteroRoDB;
use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $dbh;
my $location;

sub location { 

	# get path of zotero database
	my $profile_name = `grep Path ~/.zotero/zotero/profiles.ini`;
	chomp $profile_name;
	$profile_name =~ /Path=(.*)/;
	my $zotero_sql_path = `grep 'extensions.zotero.dataDir' ~/.zotero/zotero/$1/prefs.js`;
	$zotero_sql_path =~ /user_pref\("extensions\.zotero\.dataDir", "(.*)"\)/;
	return $1;
}

sub init {

	my $zotero_sql_path = location();
	
	if ( ! ( -e "/tmp/zotero.sqlite")) {
    	`cp $zotero_sql_path/zotero.sqlite /tmp`;
	}

	$dbh = DBI->connect("dbi:SQLite:dbname=/tmp/zotero.sqlite",  undef, undef, { sqlite_open_flags => SQLITE_OPEN_READONLY, sqlite_use_immediate_transaction => 1, }) or die "$DBI::errstr";
	return $dbh;
}

# subcollections in collection, reset $result

sub folderdir { 
	my ($result, $itemid) = @_;
	my $query = $itemid ? "='$itemid'" : "is null";
	my $array = $dbh->selectall_arrayref("
	select collectionName, collectionID from collections where parentCollectionId $query");
	%$result = ();
    for my $file (@$array) {
    	$$result{$$file[0]} = $$file[1];
	}
} 

# files in collection, do not reset $result

sub folderfiles { 
	my ($result, $itemid) = @_;
	my $query = $itemid ? "='$itemid'" : "is null";
	my $array = $dbh->selectall_arrayref("
	select items.ItemId, creators.lastName, itemData.fieldID, 
		itemDataValues.value
	from collectionItems
	left outer join items 
	left outer join itemCreators left outer join creators 
	left outer join itemDataValues left outer join itemData 
	where CollectionId $query and items.ItemID = collectionItems.itemID 
	and items.ItemID = itemCreators.itemID 
	and itemCreators.creatorID = creators.creatorID
	and itemCreators.orderIndex = 0
	and itemData.itemID = items.ItemID
	and itemDataValues.valueID = itemData.valueID
	and (itemData.fieldID = 14 or itemData.fieldID = 110)
	order by items.ItemID");	
	my $year;
	my $title;
    for my $file (@$array) {
		my $id = $$file[0]; #zotero item ID
		my $creator = $$file[1]; 
		$creator =~ s/[^A-Za-z0-9]//g;
		if (defined($$file[2])) {	
			if ($$file[2] == "14") { #comes first
				$year = substr($$file[3], 0, 4);
				$year =~ s/[^A-Za-z0-9]//g;
				$title = "";
			}
			if ($$file[2] == "110") { #comes second
				if (!defined($year)) {
					$year = ""; 
				}
				$title = substr($$file[3], 0, 20);
				$title =~ s/ /-/g;
				$title =~ s/[^A-Za-z0-9-]//g;
    			$$result{"ZZ-$creator-$year-$title-$id"} = "P$id";
			}
		} 
	}
} 

# files in publication, reset $result
# only storage:, not links 

sub publicationfiles { 
	my ($result, $itemid) = @_;
	$itemid =~ /^P(.*)$/;
	%$result = ();
	## may fail
	my $array = $dbh->selectall_arrayref("
	select itemAttachments.itemID, items.key, path from itemAttachments left outer join items where itemAttachments.parentItemID = '$1' and itemAttachments.itemid = items.itemid");
    for my $file (@$array) {
		if (defined($$file[2])) { # list of attachments is not empty
			print "(ATTACH:$$file[2])\n";
			if ($$file[2] =~ /^storage:/) {	
				$$file[2] =~ s/^storage://; # chop off storage prefix
				# '-' encodes that file has not been e_opened before
    			$$result{$$file[2]} = "F-$$file[1]F$$file[2]";	
			}	
		}
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
