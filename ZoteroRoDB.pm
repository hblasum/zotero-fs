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
my $field_title;
my $field_date;

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
	my $array = $dbh->selectall_arrayref("select fieldId from fields where fieldName = 'title'");
	$field_title = $array->[0][0];
	$array = $dbh->selectall_arrayref("select fieldId from fields where fieldName = 'date'");
	$field_date = $array->[0][0];
	return $dbh;
}

# subcollections in collection, reset $result

sub collection_collections { 
	my ($result, $itemid) = @_;
	my $query = $itemid ? "='$itemid'" : "is null";
	my $array = $dbh->selectall_arrayref("
	select collectionName, collectionID from collections where parentCollectionId $query");
	%$result = ();
    for my $file (@$array) {
    	$$result{$$file[0]} = $$file[1];
	}
} 

# items in collection, do not reset $result

sub collection_items { 
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
	and (itemData.fieldID = $field_title or itemData.fieldID = $field_date)
	order by items.ItemID");	
	my $year;
	my $title;
	# if data base entry data is complete: two rows where first row is 
	# 	itemData.field = "year" and second row itemData.field = "title" 
	# if data base entry is does not have title or does not have year: one 
	# 	row with either 14 or 110 is given
	# case with entry neither having title or year is not handled
	my $lastfield; # catch entries without title
	my $lastcreator; # catch entries without title
	my $lastid; # catch entries without title
    for my $file (@$array) {
		my $id = $$file[0]; #zotero item ID
		my $creator = $$file[1]; 
		$creator =~ s/[^A-Za-z0-9]//g;
		if (defined($$file[2])) {
			if ($$file[2] == $field_date) { #title comes first
				if ($lastfield == $field_date) { # previous result did not have title, 
					# so dump it first
    				$$result{"ZZ-$lastcreator-$year-$lastid"} = "P$id";
				}
				$year = substr($$file[3], 0, 4);
				$year =~ s/[^A-Za-z0-9]//g;
				$title = "";
				$lastfield = $field_date;
				$lastid = $id;
				$lastcreator = $creator;
			}
			if ($$file[2] == $field_title) { #title comes second
				if (!defined($year)) {
					$year = ""; 
				}
				$title = substr($$file[3], 0, 20);
				$title =~ s/ /-/g;
				$title =~ s/[^A-Za-z0-9-]//g;
				$lastfield = $field_title;
    			$$result{"ZZ-$creator-$year-$title-$id"} = "P$id";
			}
		} 
	}
} 

# raw files in collection

sub attachment_path {
	my ($dir, $attachment) = @_;
	if ($attachment =~ /^storage:/) {	
		$attachment =~ s/^storage://; # chop off storage prefix
    		return "F-${dir}F${attachment}";	
	} else {
    		return "A-${attachment}";	
	}
}

sub collection_files { 
	my ($result, $itemid) = @_;
	%$result = ();
	my $query = $itemid ? "='$itemid'" : "is null";
	my $array = $dbh->selectall_arrayref("
	select items.ItemId, items.key, itemAttachments.path
	from collectionItems
	left outer join items 
	left outer join itemAttachments
	where CollectionId $query and items.ItemID = collectionItems.itemID 
	and items.itemID = itemAttachments.itemID 
	order by items.ItemID");
	print "COLL($query)\n";	
    for my $file (@$array) {
		print "COLL-FILE ($$file[0]|$$file[1]|$$file[2])";
		if (defined($$file[2])) { # list of attachments is not empty
			my $ap = attachment_path($$file[1], $$file[2]);
			print "(ATTACH:$$file[2](ap:$ap))\n";
			if ($$file[2] =~ /^storage:/) {	
				$$file[2] =~ s/^storage://; # chop off storage prefix
			} 
			# '-' encodes that file has not been e_opened before
    			$$result{$$file[2]} = $ap;	
		}
	}
}


# files in publication, reset $result
# only storage:, not links 

sub item_files { 
	my ($result, $itemid) = @_;
	$itemid =~ /^P(.*)$/;
	%$result = ();
	## may fail
	my $array = $dbh->selectall_arrayref("
	select itemAttachments.itemID, items.key, path from itemAttachments left outer join items where itemAttachments.parentItemID = '$1' and itemAttachments.itemid = items.itemid");
    for my $file (@$array) {
		if (defined($$file[2])) { # list of attachments is not empty
			my $ap = attachment_path($$file[1], $$file[2]);
			print "(ATTACH:$$file[2](ap:$ap))\n";
			if ($$file[2] =~ /^storage:/) {	
				$$file[2] =~ s/^storage://; # chop off storage prefix
			}
    			$$result{$$file[2]} = $ap;
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
