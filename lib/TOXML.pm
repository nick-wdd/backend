package TOXML;

use Carp;
use strict;
use YAML::Syck;
use Storable;
use Data::Dumper;

use lib "/backend/lib";
require ZOOVY;
require DBINFO;


#
#FORMAT:WRAPPER =
#	pageid is not set
#	fs is not set
#
#FORMAT:PRODUCT =
#	setSTID is the product in focus
#	pageid is the productid ?? (is this necessary)
#	fs is not set
#
#FORMAT:PAGE =
#	pageid is the page name or .safe.path
#	fs is the style of page
#
#FORMAT:WIZARD
#	pageid is the ebay profile
#	fs is not set
#	docid is ebay.profile
#	layout is ebay:template
#
#FORMAT:EMAIL
#	pageid is not set
#	fs is not set
#	&ZOOVY::fetchmerchantns_attrib($USERNAME,$SITE->profile(),'email:docid')
#
#FORMAT:NEWSLETTER
#	pageid is the @campaign
#	fs is not set
#
#layout + format  = file reference
#


##
## for information on the structure of a TOXML object .. 
##
##
##

##
## eventually for non-system layouts i plan to have a separate .bin, or maybe yaml file for just the config
##
sub just_config_please {
	my ($USERNAME,$FORMAT,$DOCID) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($t) = TOXML->new("$FORMAT","$DOCID",USERNAME=>$USERNAME,MID=>$MID);
	my $configel = undef;
	if (defined $t) {
		($configel) = $t->findElements('CONFIG');	# fetch the first CONFIG element out of the document.	
		}
	return($configel);
	}


sub dataref {
	my ($self) = @_;

	}


##
## this will go through the document and generate a 'help' html page that can be embedded into webdoc.
##
sub as_webdochtml {
	my ($self) = @_;

	my $out = '';
	my ($configel) = $self->findElements('CONFIG');	# fetch the first CONFIG element out of the document.	
	$out .= "<h1>".sprintf("%s:%s",$self->format(),$self->docid())." $configel->{'TITLE'}</h1><br>";
	if ($configel->{'OVERLOAD'}) {
		$out .= "OVERLOADS: $configel->{'OVERLOAD'}<br>";
		}
	$out .= "<div>".(($configel->{'SUMMARY'})?$configel->{'SUMMARY'}:"No summary was provided by the designer.")."</div>";
	$out .= "List of Elements:<br>";

	foreach my $el (@{$self->elements()}) {
		my $skipnotes = '';
		if ($el->{'OUTPUTSKIP'} > 0) {
			if ($el->{'OUTPUTSKIP'} & 1) { $skipnotes .= "<li> skipped on outputif condition: $el->{'OUTPUTIF'}"; }
			if ($el->{'OUTPUTSKIP'} & 2) { $skipnotes .= "<li> skipped if secure"; }
			if ($el->{'OUTPUTSKIP'} & 4) { $skipnotes .= "<li> skipped if non-secure"; }
			if ($el->{'OUTPUTSKIP'} & 8) { $skipnotes .= "<li> skipped if user logged in"; }
			if ($el->{'OUTPUTSKIP'} & 16) { $skipnotes .= "<li> skipped if user NOT logged in"; }
			if ($el->{'OUTPUTSKIP'} & 32) { $skipnotes .= "<li> skipped if cart has NO items"; }
			if ($el->{'OUTPUTSKIP'} & 64) { $skipnotes .= "<li> skipped if cart has items"; }
			if ($el->{'OUTPUTSKIP'} & 256) { $skipnotes .= "<li> skipped if 'A' side of site"; }
			if ($el->{'OUTPUTSKIP'} & 512) { $skipnotes .= "<li> skipped if 'B' side of site"; }
			if ($el->{'OUTPUTSKIP'} & 2048) { $skipnotes .= "<li> skipped if in a wrapper"; }
			if ($el->{'OUTPUTSKIP'} & 4096) { $skipnotes .= "<li> skipped if in a layout"; }
			if ($el->{'OUTPUTSKIP'} & 8192) { $skipnotes .= "<li> skipped if in an html wizard"; }
			if ($el->{'OUTPUTSKIP'} & 16384) { $skipnotes .= "<li> skipped if in a email"; }
			if ($el->{'OUTPUTSKIP'} & 32768) { $skipnotes .= "<li> skipped if in user interface"; }
			$skipnotes .= "<ul>This element may be skipped under the following conditions:\n$skipnotes</ul>";
			}

		if ($el->{'TYPE'} eq 'CONFIG') {
			## we output *NOTHING for config elements since we already handled them above.
			}
		elsif ($el->{'TYPE'} eq 'OUTPUT') {
			## we can ignore 'OUTPUT' elements 
			$out .= "$skipnotes";
			}
		else {
			## 
			$out .= "<li> $el->{'ID'} $el->{'TYPE'} $el->{'HELPER'}<br>$skipnotes";
			}
		}
		
	return($out);
	}


## utility methods (should have named these better)
sub format { return($_[0]->getFormat()); }

##
## returns an arrayref of DIVS
##
sub divs {
	my ($self) = @_;

	my $ref = undef;
	my $i = 0;
	if (defined $self->{'_DIVS'}) {
		$i = scalar(@{$self->{'_DIVS'}});
		}

	if ($i==0) { $ref = undef; }
	elsif ($i>0) {
		$ref = $self->{'_DIVS'};
		}
	
	return($ref);	
	}




##
## NOTE: we need to have an explicit destructor since 
##		Perl does not free nested hashrefs gracefully.
sub DESTROY {
	my $self = $_[0];

	my $i = 0;
	# print STDERR "destroying $self->{'_ID'} $self->{'_FORMAT'} for user=$self->{'_USERNAME'}\n";

	## clean up elements
	if (ref($self->{'_ELEMENTS'}) eq 'ARRAY') {
		$i = scalar(@{$self->{'_ELEMENTS'}});
		while (--$i>=0) {
			foreach my $k (keys %{$self->{'_ELEMENTS'}->[$i]}) {
				delete $self->{'_ELEMENTS'}->[$i]->{$k};
				}
			delete $self->{'_ELEMENTS'}->[$i];
			}
		}
	delete $self->{'_ELEMENTS'};
	## at this point, all _ELEMENTS are gone!

	$i = 0;
	if (defined $self->{'_DIVS'}) {
		$i = scalar(@{$self->{'_DIVS'}});
		}

	while (--$i>=0) {
		my $i2 = scalar(@{$self->{'_DIVS'}->[$i]->{'_ELEMENTS'}});
		while (--$i2>=0) {
			foreach my $k (keys %{$self->{'_DIVS'}->[$i]->{'_ELEMENTS'}->[$i2]}) {
				delete $self->{'_DIVS'}->[$i]->{'_ELEMENTS'}->[$i2]->{$k};
				}
			}
		foreach my $k (keys %{$self->{'_DIVS'}->[$i]}) {
			delete $self->{'_DIVS'}->[$i]->{$k};
			}
		delete $self->{'_DIVS'}->[$i];
		}
	## at this point all _DIVS are gone

	## flush lists.
	if ((defined $self->{'_LISTS'}) && (ref($self->{'_LISTS'}) eq 'ARRAY')) {

		$i = scalar(@{$self->{'_LISTS'}});
		while (--$i>=0) {
			my $i2 = scalar(@{$self->{'_LISTS'}->[$i]->{'_OPTS'}});
			while (--$i2>=0) {
				delete $self->{'_LISTS'}->[$i]->{'_OPTS'}->[$i2];
				}
			foreach my $k (keys %{$self->{'_LISTS'}->[$i]}) {
				delete $self->{'_LISTS'}->[$i]->{$k};
				}
			delete $self->{'_LISTS'}->[$i];
			}
		}

	return();
	}



sub docId { my ($self) = @_; return($self->{'_ID'}); }
sub docid { my ($self) = @_; return($self->{'_ID'}); }
sub getFormat { 
	if ($_[0]->{'_FORMAT'} eq 'ZEMAIL') {
		## we always use EMAIL rather than ZEMAIL these days.
		$_[0]->{'_FORMAT'} = 'EMAIL'; 
		}
	return($_[0]->{'_FORMAT'}); 
	}



##
## so this setting lets a toxml item record if it's already return and THEREFORE assumes that somebody is already
##	processing it's elements, bad decisions are made when a toxml object is passed to an element which then tries to
##	run the same TOXML elements again -- it causes a nasty recursion loop. 
## the original code avoided this by not passing $toxml (and not passing $SITE::SREF) to its children on a recurisve run
##		of course there's numerous reasons why that is a horrible idea .. so this seemed like a good alternative.
##	effectively BLOCK_RECURSION 
##
sub BLOCK_RECURSION {
	if ($_[1]) { $_[0]{'_BLOCK_RECURSION'} = $_[1]; }
	return($_[0]->{'_BLOCK_RECURSION'});
	}

%TOXML::CACHE = ();

##
## FORMAT should be one of the following:
##		LAYOUT, WRAPPER, WIZARD, CHANNEL, CUSTOM
##	ID should be the id of the item you want to load. 
##		Anything which references a USER ACCOUNT should have a leading ~.
## options can be any of the following
##		REF => a reference to a compiled TOXML (used primarily for importing old data)
##		MID => the mid in focus (if we are working with user data)
##		USERNAME => the username in focus (if we are working with user data)
##		FS => flow style (required for defaulting)
##
## note: the following variables are always stored
##		_USERNAME - whichver user this was instantiated for
##		_MID	- whichever mid this was instantiated for
##		_SYSTEM - a true/false value indicating if it's a system wide template
##
sub new {
	my ($class, $FORMAT, $DOCID, %options) = @_;

	if (($FORMAT eq '') || ($DOCID eq '')) {
		warn Carp::confess("Missing one or more required parameters FORMAT[$FORMAT] DOCID[$DOCID] to TOXML->new()");
		}

	if (($FORMAT eq 'PAGE') || ($FORMAT eq 'PRODUCT') || ($FORMAT eq 'NEWSLETTER')) {
		$FORMAT = 'LAYOUT';
		}

	## NOTE: blank docid's are alright for LAYOUTS, but not for anything else! -- the line below is BAD!
	# if ($DOCID eq '') { return(undef); }

	# print STDERR "new TOXML: $FORMAT, $DOCID\n";
	my $PERSONAL = 0;
	if (index($DOCID,'~')>=0) { $PERSONAL++; }
	elsif (index($DOCID,'*')>=0) { $PERSONAL++; }	

	if ($FORMAT eq 'DEFINITION') {
		$DOCID =~ s/[^A-Z0-9a-z\-\_\.]+//gso;	# definitions allow periods.
		$DOCID = lc($DOCID);
		}
	else {
		$DOCID =~ s/[^A-Z0-9a-z\-\_]+//ogs;		# strip out unwanted characters
		}


	my $self = {};

	$self->{'_BLOCK_RECURSION'} = 0;

	if ($options{'REF'}) { 
		$self = $options{'REF'}; 
		}
	if (defined $options{'USERNAME'}) {
		$self->{'_USERNAME'} = $options{'USERNAME'};
		if (not defined $options{'MID'}) { $options{'MID'} = &ZOOVY::resolve_mid($options{'USERNAME'}); }
		$self->{'_MID'} = $options{'MID'};
		}
	else {
		$self->{'_MID'} = 0;
		}

	## an override dataref that is used before all other data sources
	if ($FORMAT eq 'HTMLWIZ') { $FORMAT = 'WIZARD'; }

	# my $NEED_TO_SAVE = 0;

	my $filepath = undef;
	my $cachefile = undef;

	if ($options{'REF'}) {
		}
	elsif ($DOCID eq '') {
		## CODE TO LOAD DEFAULTS (ONLY APPLIES TO LAYOUTS)
		if ($FORMAT ne 'LAYOUT') {
			}
		elsif (($DOCID eq '') && (not defined $options{'FS'})) { 
			warn 'Flow style not set, and no flow id specified.';
			return(undef); 
			}
		elsif ($DOCID eq '') {
			warn 'DOCID not specified .. this line should never be reached';
			}
		else {
			}
		}

	my $cache = int($options{'cache'});

	if ($options{'REF'}) {} 		## already loaded.. skip.
	elsif ($DOCID eq '') { 
		warn 'new called without docid being set on type['.$DOCID.']'; 
		}
	elsif ($PERSONAL) {
		if ($FORMAT eq 'EMAIL') { $FORMAT = 'ZEMAIL'; }

		$filepath = &ZOOVY::resolve_userpath($self->{'_USERNAME'}).'/TOXML/'.$FORMAT.'+'.lc($DOCID);
		$cachefile = &ZOOVY::cachefile($self->{'_USERNAME'},'TOXML+'.$FORMAT.'+'.lc($DOCID).'.bin');

		my $MEMKEY = Digest::MD5::md5_base64($filepath);	
		my $memd = &ZOOVY::getMemd($self->{'_USERNAME'});
		my ($ctime_nfs) = $memd->get($MEMKEY);
		
		## print STDERR "$$ FILEPATH [$filepath] CTIME_NFS:$ctime_nfs $self->{'_USERNAME'}\n";
		
		if ($ctime_nfs > 0) {
			# print STDERR "GOT MECACHE CTIME: $ctime_nfs ON FILE $filepath\n";
			}
		elsif (-f "$filepath.xml") {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$filepath.xml");
			## warn "$$ HAD TO LOAD CTIME for $filepath.xml $MEMKEY=>[$ctime]\n";
			$ctime = 1234;
			$memd->set($MEMKEY, [ $ctime ]);
			$ctime_nfs = $ctime;
			}
		else {
			$ctime_nfs = -1;
			}
		
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($cachefile);
		if ($ctime_nfs > $ctime) {
			## local copy is older than timestamp.
			## load from server, but save a copy
			require File::Copy;
			File::Copy::copy("$filepath.bin",$cachefile);
			}

		$options{'REF'} = ($self) = eval { retrieve $cachefile };
		}
	#####################################################
	## 		W R A P P E R S    (website wrappers)
	elsif ($FORMAT eq 'WRAPPER') {
		$filepath = "/httpd/static/wrappers/$DOCID/main";
		}
	#####################################################
	## 		D A T A -- W I Z A R D S    (auction templates + personal definitions)
	elsif ($FORMAT eq 'WIZARD') {
		$filepath = "/httpd/static/wizards/$DOCID/main";
		}
	#####################################################
	## 		L A Y O U T S    (flows)
	elsif (($FORMAT eq 'LAYOUT') ) {
		## NOTE: for user types, they all have the same SUBTYPE of '*'
		$filepath = "/httpd/static/layouts/$DOCID/main"; 
		}
	elsif (($FORMAT eq 'EMAIL') || ($FORMAT eq 'ZEMAIL')) {
		$filepath = "/httpd/static/emails/$DOCID/main";
		}
	else {
		warn "Requested unknown TOXML format $FORMAT\n";
		}

	##
	## SANITY: at this point either $cachefile or $filepath should be set!
	##
	if ($options{'REF'}) {
		} 		## already loaded.. skip.
	elsif ($filepath eq '') {
		}
	#elsif (($cache>1) && ($cachefile ne '')) {
	#	## note: cache=1 means load from nfs, but save a copy
	#	# print STDERR "LOADED TRANSPARENT CACHE: $cachefile\n";
	#	$self = eval { retrieve $cachefile; }
	#	}
	#elsif (($cache<0) && ($cachefile ne '')) {
	#	## publisher file
	#	# print STDERR "LOADED PUBLISHER CACHE: $cachefile\n";
	#	if (-f $cachefile) {
	#		$self = YAML::Syck::LoadFile($cachefile);
	#		}
	#	}
	elsif (-f "$filepath.bin") {
		# print STDERR "LOADED NFS TOXML: $filepath.bin\n";

		($self) = eval { retrieve $filepath.'.bin'; };

		if ($@) {
			print STDERR "CORRUPT FILE: $filepath.bin\n";
			# &ZOOVY::confess($self->{'_USERNAME'},"corrupt bin $filepath.bin\n",justkidding=>1);
 			#if (-f "$filepath.xml") {
		   #   # print STDERR "LOADED NFS TOXML: $filepath.xml\n";
		   #   require TOXML::COMPILE;
		   #   open F, "<$filepath.xml"; $/ = undef; my $xml = <F>; close F; $/ = "\n";
		   #   $self = TOXML::COMPILE::xmlToRef($xml);
			#	close F;
			#	if (scalar(keys %{$self})>0) {
			#		Storable::nstore($self,"$filepath.bin");
			#		}
			#	}	
			}

		if (not defined $self) {}
		elsif ($PERSONAL>0) {
			$self->{'_LOADED'}=time(); 
			if ($cache==1) { Storable::nstore $self, $cachefile; }
			}
		}
	elsif ( -f "$filepath.xml") {
		&ZOOVY::confess($options{'_USERNAME'},"INVALID TOXML: $filepath",justkidding=>1);
		}
	#elsif (-f "$filepath.xml") { 
	#	# print STDERR "LOADED NFS TOXML: $filepath.xml\n";
	#	require TOXML::COMPILE;
	#	open F, "<$filepath.xml"; $/ = undef; my $xml = <F>; close F; $/ = "\n";
	#	$self = TOXML::COMPILE::xmlToRef($xml);

	#	print STDERR "PERSONAL: [$PERSONAL]\n";
	#	if (not defined $self) { 
	#		warn "Could not load $filepath.xml"; 
	#		}
	#	elsif ($PERSONAL>0) { 	
	#		## we should only try and create .xml files for personal types.
	#		$self->{'_LOADED'}=time(); $NEED_TO_SAVE++; 
	#		}
	#	elsif ($PERSONAL==-1) {		
	#		$self->{'_SYSTEM'}++;
	#		bless $self, 'TOXML';
	#		## $self->MaSTerSaVE('preserve'=>1);
	#		}
	#	
	#	}
	else {
		if (&ZOOVY::servername() eq 'dev') {
			warn("Could not find file $filepath");
			}
		}

	if (not defined $self) { 
		warn "TOXML Could not load FORMAT=[$FORMAT] DOCID=[$DOCID]\n";
		return(undef); 
		}

	if (ref($self) ne 'TOXML') {
		bless $self, 'TOXML';
		}


	## reset ID so it's properly denoted the type it is.
	if (defined $options{'USERNAME'}) {
		$self->{'_USERNAME'} = $options{'USERNAME'};
		if (not defined $options{'MID'}) { $options{'MID'} = &ZOOVY::resolve_mid($options{'USERNAME'}); }
		$self->{'_MID'} = $options{'MID'};
		}
	else {
		$self->{'_MID'} = 0;
		}

	
	## NOTE: the _SYSTEM variable in the toxml file determines where variables like %wrapper_url% are sent to.
	$self->{'_SYSTEM'} = 0;
	if ($PERSONAL>0) {}
	else {
		$self->{'_SYSTEM'} = 1;
		}

	$self->{'_ID'} = (($self->{'_SYSTEM'}==0)?'~':'').$DOCID;
	$self->{'_FORMAT'} = $FORMAT;

	#if ($NEED_TO_SAVE) { 
	#	$self->save(); 
	#	}

	return($self);
	}

##
## this is run each time a TOXML file is saved (MaSTerSave or regular)
##		it is responsible for creating all files, building any indexes, cheat sheets, and 
##		EVENTUALLY pre-compiling the SPECL syntax into a non-interpreted version (e.g. via evals)
##		which would then run very very very fast.
##
sub compile {
	my ($self) = @_;

	my ($configel) = $self->findElements('CONFIG');	# fetch the first CONFIG element out of the document.
	my $format = $self->getFormat();
	if (not defined $configel) {
		}
	$self->{'_CONFIG'} = $configel;

	if (($format eq 'WRAPPER') && ($configel->{'CSS'} ne '')) {
		require TOXML::CSS;
		$configel->{'%CSSVARS'} = TOXML::CSS::css2cssvar($configel->{'CSS'});
		}

	}


## if doctype='WRAPPER'
##		loads 
sub initConfig {
	my ($self,$SITE) = @_;

	if (ref($SITE) ne 'SITE') {
		Carp::croak("Dont' call TOXML::initConfig without a valid SITE object");
		}

	if ((defined $SITE::CONFIG) && ($SITE::CONFIG->{'USERNAME'} eq $SITE->username())) { 
		return($SITE::CONFIG);
		}
	$SITE::CONFIG = {};

	my ($configel) = $self->findElements('CONFIG');	# fetch the first CONFIG element out of the document.
	if ((not defined $configel) && ($self->getFormat eq 'WRAPPER')) {
		$configel = { 'ID'=>'default_not_set', 'THEME'=>'', SITEBUTTONS=>'' };
		}

	if (defined $configel) {
		require TOXML::RENDER;
		$TOXML::RENDER::render_element{'CONFIG'}->($configel,$self,$SITE);
		# print STDERR Dumper($SITE::CONFIG);
		}
	undef $configel;
	return($SITE::CONFIG);	
	}


##
## this returns:
##		~docid?V=<version>&PROJECT=<project>
##
sub docuri {
	my ($self) = @_;

	my ($configel) = $self->findElements('CONFIG');	# fetch the first CONFIG element out of the document.
	if (not defined $configel->{'V'}) { $configel->{'V'} = 0; }
	if (not defined $configel->{'PROJECT'}) { $configel->{'PROJECT'} = 0; }
	if (not defined $configel->{'FOLDER'}) { $configel->{'FOLDER'} = ''; }

	return($self->docid()."?FOLDER=$configel->{'FOLDER'}&V=$configel->{'V'}&PROJECT=$configel->{'PROJECT'}");
	}


sub nuke { 
	my ($self) = @_; return($self->filehandler('NUKE')); 
	}


sub save { 
	my ($self, %options) = @_;

	if ($self->{'_USERNAME'} ne '') {
		## 
		if (not defined $options{'LUSER'}) {
			$options{'LUSER'} = '?';
			}
		if (not defined $options{'ACTION'}) {
			$options{'ACTION'} = 'SAVE';
			}

		require TOXML::ANNOTATE;
		TOXML::ANNOTATE::add_note($self->{'_USERNAME'},$self->getFormat(),$self->docId(),$options{'LUSER'},$options{'ACTION'},%options);
		}

	return($self->filehandler('SAVE')); 
	}


##
## a useful little function for updating the master file after we change elements or whatever.
##
sub MaSTerSaVE {
	my ($self) = @_;

	delete $self->{'_USERNAME'};
	delete $self->{'_MID'};
	if ($self->{'_SYSTEM'} != 1) { die("not a system file"); }

	my $DOCID = $self->{'_ID'};

	my $xmlfile = '';
	my $binfile = '';
	if ($self->{'_FORMAT'} eq 'LAYOUT') {
		# /httpd/static/layouts/$FILE.bin and $FILE.xml	
		$binfile = "/httpd/static/layouts/$DOCID/main.bin";
		$xmlfile = "/httpd/static/layouts/$DOCID/main.xml";
		}
	elsif ($self->{'_FORMAT'} eq 'WRAPPER') {
		# /httpd/static/layouts/$FILE.bin and $FILE.xml	
		$self->compile();
		$binfile = "/httpd/static/wrappers/$DOCID/main.bin";
		$xmlfile = "/httpd/static/wrappers/$DOCID/main.xml";
		}
	elsif ($self->{'_FORMAT'} eq 'WIZARD') {
		# /httpd/static/layouts/$FILE.bin and $FILE.xml	
		$self->compile();
		$binfile = "/httpd/static/wizards/$DOCID/main.bin";
		$xmlfile = "/httpd/static/wizards/$DOCID/main.xml";
		}
	elsif (($self->{'_FORMAT'} eq 'EMAIL') || ($self->{'_FORMAT'} eq 'ZEMAIL')) {
		# /httpd/static/layouts/$FILE.bin and $FILE.xml	
		$self->compile();
		$binfile = "/httpd/static/emails/$DOCID/main.bin";
		$xmlfile = "/httpd/static/emails/$DOCID/main.xml";
		}
#	elsif ($self->{'_FORMAT'} eq 'ZEMAIL') {
#		# /httpd/static/layouts/$FILE.bin and $FILE.xml	
#		$self->compile();
#		mkdir("/httpd/static/zemails/$DOCID");
#		chmod(0777,"/httpd/static/zemails/$DOCID");
#		chown($ZOOVY::EUID,$ZOOVY::EGID,"/httpd/static/zemails/$DOCID");
#		$binfile = "/httpd/static/zemails/$DOCID/main.bin";
#		$xmlfile = "/httpd/static/zemails/$DOCID/main.xml";
#		}
#	elsif ($self->{'_FORMAT'} eq 'ORDER') {
#		# /httpd/static/layouts/$FILE.bin and $FILE.xml	
#		$self->compile();
#		$binfile = "/httpd/static/orders/$DOCID/main.bin";
#		$xmlfile = "/httpd/static/orders/$DOCID/main.xml";
#		}

	if ($xmlfile ne '') { 
		print STDERR "TOXML->MaSTerSaVE Wrote: $xmlfile\n";
		open F, ">$xmlfile"; print F $self->as_xml();  close F; chmod 0666, $xmlfile; chown $ZOOVY::EUID,$ZOOVY::EGID, $xmlfile; 
		}

	if ($binfile ne '') { 
		print STDERR "TOXML->MaSTerSaVE Wrote: $binfile\n";
		Storable::nstore $self, $binfile; 
		chmod 0666, $binfile; chown $ZOOVY::EUID,$ZOOVY::EGID, $binfile; 
		}
	}

##
##	ACTION:
## 	SAVE: stores the item, updates the database -- USER SPECIFIC ONES ONLY
##		NUKE: deletes all files.
##
## NOTE: to update a master template file, try MaSTerSaVE
##

sub filehandler {
	my ($self,$ACTION) = @_;

	my $ok = 1;
	if ($self->{'_FORMAT'} eq 'DEFINITION') {}
	elsif (($ok) && ($self->{'_MID'}<=0)) { 
		warn 'Uh-oh, MID not set on TOXML object before calling store.'; $ok = 0; 
		}
	elsif (($ok) && ($self->{'_USERNAME'} eq '')) { 
		warn 'Uh-oh, USERNAME not set on TOXML object before calling store.'; $ok = 0; 
		}

	my $ID = $self->{'_ID'};
	if (not $ok) {}
	elsif (substr($ID,0,1) eq '*') { $ID = substr($ID,1); $ID =~ s/[^\w\-\_]+//gos; }
	elsif (substr($ID,0,1) eq '~') { $ID = substr($ID,1); $ID =~ s/[^\w\-\_]+//gos; }
	elsif ($self->{'_FORMAT'} eq 'DEFINITION') {}
	else {
		warn "Uh-oh, TOXML ID of $ID does not appear to be a correctly formatted id should contain ~ or *"; $ok = 0;
		}


	if ($self->{'_FORMAT'} eq 'EMAIL') {
		$self->{'_FORMAT'} = 'ZEMAIL';
		}
	if (not $ok) {}
	elsif ((
			($self->{'_FORMAT'} eq 'LAYOUT') || 
			($self->{'_FORMAT'} eq 'WRAPPER') || 
			($self->{'_FORMAT'} eq 'DEFINITION') ||
			($self->{'_FORMAT'} eq 'WIZARD') ||
			($self->{'_FORMAT'} eq 'EMAIL') ||
			($self->{'_FORMAT'} eq 'ZEMAIL') ||
			($self->{'_FORMAT'} eq 'ORDER') ||
			($self->{'_FORMAT'} eq 'INCLUDE')
			) && (($ACTION eq 'NUKE') || ($ACTION eq 'SAVE'))) {
		############################################
		## WRAPPERS
		$self->compile();

		if ($self->{'_FORMAT'} eq 'EMAIL') { 
			$self->{'_FORMAT'} = 'ZEMAIL';
			}

		$ID = lc($ID);	# all files are ALWAYS lowercase
		my $FILENAME = uc($self->{'_FORMAT'}).'+'.$ID;		
		my $path = &ZOOVY::resolve_userpath($self->{'_USERNAME'}).'/TOXML';

		if ($self->{'_FORMAT'} eq 'DEFINITION') {
			if ($self->{'_MID'}==0) { $path = "/httpd/static/definitions"; }
			$FILENAME = $ID;			
			}

		
		unlink "$path/$FILENAME.xml";
		unlink "$path/$FILENAME.bin";		

		if ($ACTION eq 'NUKE') { 
			unlink "$path/TOXML/$FILENAME.txt"; 
			unlink "$path/TOXML/$FILENAME.gif"; 
			}	# nuke deletes images too

		if ($ACTION eq 'SAVE') {
			mkdir $path;
			chmod 00777, $path;

			# unlink "$path/$ID.zhtml";
			my ($YYYYMMDDHHMMSS) = &ZTOOLKIT::pretty_date(time(),3);
			rename("$path/$FILENAME.xml","$path/$FILENAME-$YYYYMMDDHHMMSS.xml");
			unlink "$path/$FILENAME.bin";
	
			Storable::nstore $self, "$path/$FILENAME.bin";
			chmod 0666, "$path/$FILENAME.bin";
			open F, ">$path/$FILENAME.xml";
			print F $self->as_xml();
			close F;

			chmod 00666, "$path/$FILENAME.xml";
			
			my $TS = time();
			my ($FORMAT,$DOCID,$USERNAME) = ($self->{'_FORMAT'},$self->{'_DOCID'},$self->{'_USERNAME'});
			my ($memd) = &ZOOVY::getMemd($self->{'_USERNAME'});
			my $filepath = &ZOOVY::resolve_userpath($self->{'_USERNAME'}).'/TOXML/'.$FORMAT.'+'.lc($DOCID);
			my $MEMKEY = Digest::MD5::md5_base64($filepath);	
			$memd->delete("$MEMKEY");
			## print STDERR "**SAVE** FILEPATH [$path/$FILENAME] CTIME:$TS\n";

			unlink &ZOOVY::cachefile($USERNAME,"TOXML+$FILENAME.bin");
			# &ZOOVY::touched($self->{'_USERNAME'},1);
			}
		}
	else {
		warn "I do not understand how to save this TOXML object FORMAT[$self->{'_FORMAT'}].";
		}	

	return(0);
	}

#mysql> desc TOXML;
#+-------------+------------------------------------------------------+------+-----+---------+----------------+
#| Field       | Type                                                 | Null | Key | Default | Extra          |
#+-------------+------------------------------------------------------+------+-----+---------+----------------+
#| ID          | int(11)                                              |      | PRI | NULL    | auto_increment |
#| MID         | int(10) unsigned                                     |      |     | 0       |                |
#| FORMAT      | enum('LAYOUT','WRAPPER','WIZARD','CUSTOM','CHANNEL') |      |     | LAYOUT  |                |
#| SUBTYPE     | char(1)                                              |      |     |         |                |
#| DIGEST      | varchar(32)                                          |      |     |         |                |
#| UPDATED_GMT | int(10) unsigned                                     |      |     | 0       |                |
#| TEMPLATE    | varchar(60)                                          |      |     |         |                |
#+-------------+------------------------------------------------------+------+-----+---------+----------------+
#7 rows in set (0.02 sec)


##
##
##
##
sub as_xml {
	my ($self) = @_;

	
	## returns a strict (or eventually possibly loose) XML document.
	require ZTOOLKIT;
	my $out = '';
	foreach my $ls (@{$self->{'_LISTS'}}) {
		## stuff like LIST ID= etc.
		my $optionsxml = "\n".join("\n",&ZTOOLKIT::arrayref_to_xmlish_list($ls->{'_OPTS'},tag=>'OPT',lowercase=>0,content_raw=>0));
		$ls->{'**optionsxml**'} = $optionsxml;
		$out .= &ZTOOLKIT::arrayref_to_xmlish_list([ $ls ],content_attrib=>'**optionsxml**',tag=>'LIST',lowercase=>0,content_raw=>1);
		delete $ls->{'**optionsxml**'};
		}

	
	## NOTE: each div is a { _ID=>'xxx', _ELEMENTS=>'' }
	##		so we just append a blank div to the bottom with a pointer to $self->
	##		(so it thinks its processing a div when its really doing root level stuff)
	foreach my $div (@{$self->{'_DIVS'}},{ _ID=>'', _ELEMENTS=>$self->{'_ELEMENTS'} }) {
		my $content = '';
		my $elementsref = $div->{'_ELEMENTS'};
		my $DIVID = $div->{'ID'};

		if ($DIVID ne '') { 
			$out .= "\n\n<!-- ******* -->\n<DIV ";
			foreach my $k (keys %{$div}) {
				next if (substr($k,0,1) eq '_'); 	# skip _ELEMENTS tag
				$out .= " $k=\"".&ZOOVY::incode($div->{$k})."\" ";
				}
			$out .= ">\n"; 
			}
		else { $out .= "\n\n<!-- ******* -->\n"; }

		foreach my $el (@{$elementsref}) {
			my $content = '';
			my %as_attribs = ();		# the elements < 100 characters in length which can be saved as attribs
			# use Data::Dumper; print Dumper($el);
			delete $el->{'ELEMENT'};		# remove the ELEMENT="ELEMENT" tags

			foreach my $k (keys %{$el}) {
				if (substr($k,0,1) eq '%') {
					## don't export %CSSVARS
					}
				elsif (($el->{$k} =~ /[\<\>\n]+/o) || (length($el->{$k})>100)) {
					$content .= "<$k><![CDATA[$el->{$k}]]></$k>\n";
					}
				else {
					$as_attribs{$k} = $el->{$k};
					}
			}	
			if ($content ne '') { $as_attribs{'content'} = $content; }
			## specialized since it doesn't encoded contents

			$out .= join("\n",&ZTOOLKIT::arrayref_to_xmlish_list([\%as_attribs],tag=>'ELEMENT','content_attrib'=>'content',lowercase=>0,content_raw=>1));
			
			delete $el->{'content'};
			}
		if ($DIVID ne '') { $out .= "</DIV>\n\n\n"; }
		}

	$out = qq~<TEMPLATE ID=\"$self->{'_ID'}\" FORMAT=\"$self->{'_FORMAT'}\">\n$out\n</TEMPLATE>~;
	return($out);
	}


##
## this outputs the "loose" format.
##		mode 0: loose html w/CDATA
##		mode 1: is plugin mode! all data is attributes of elements (no CDATA)
sub as_html {
	my ($self, $mode) = @_;

	if (not defined $mode) { $mode = 0; }

	my $out = '';
	$out .= "<!-- Loose HTML created ".&ZTOOLKIT::pretty_date(time(),1)." -->\n";

	my %CONFIG = ();
	my @configs = $self->findElements('CONFIG');
	if ((scalar @configs)>0) {
		foreach my $el (reverse @configs) {
			foreach my $k (keys %{$el}) {
				$CONFIG{$k} = $el->{$k};
				}
			}
		}
	$CONFIG{'TYPE'} = 'CONFIG';
	$CONFIG{'FORMAT'} = $self->{'_FORMAT'};
	$CONFIG{'ID'} = $self->{'_ID'};
	$CONFIG{'V'} = $self->{'_V'};

	if ((defined $self->{'_LISTS'}) && (scalar(@{$self->{'_LISTS'}})>0)) {
		$out .= "\n<!-- WARNING: This file originally contained LISTS and cannot be edited in HTML (use strict XML) .. saving this file in HTML may cause corruption. -->\n";
		}

	if ((defined $self->{'DIVS'}) && (scalar(@{$self->{'_DIVS'}})>0)) {
		$out .= "\n<!-- WARNING: This file originally contained embedded DIVs and cannot be edited in HTML (use strict XML) .. saving this file format in HTML may cause corruption. -->\n";
		}

	
	my $did_config = 0;
	foreach my $el (\%CONFIG, @{$self->{'_ELEMENTS'}}) {
		if (($el->{'TYPE'} eq 'CONFIG') && ($did_config)) {}
		elsif (($el->{'TYPE'} eq 'OUTPUT') && (not defined $el->{'OUTPUTSKIP'}) && ($el->{'DIV'} eq '')) {
			## preserve attribute DIV for EMAILBODY
			$out .= $el->{'HTML'};
			}
		else {
			if ($el->{'TYPE'} eq 'CONFIG') { $did_config++; }
			$out .= "<ELEMENT TYPE=\"$el->{'TYPE'}\" ";
			my $middle = '';		
			my %didit = ();		# attributes we've already done.
			foreach my $k ('ID','TYPE','SUB','DATA','LOAD','PRETEXT','POSTTEXT',sort keys %{$el}) {
				if ($k eq 'TYPE') {}
				elsif ($didit{$k}) {}	# already did this
				elsif (substr($k,0,1) eq '%') {} 	# removes %CSSVARS
				elsif (not defined $el->{$k}) {}	 # asking for an attribute we don't have.
				elsif ((($el->{$k} =~ /[\<\>\n]+/o) || (length($el->{$k})>100)) && ($mode==0)) {
					$middle .= "<$k><![CDATA[$el->{$k}]]></$k>\n";
					}
				elsif (($mode == 1) && ($k eq 'HTML')) {
					$middle = $el->{$k};
					}
				else {
					$out .= ' '.$k.'="'.&ZTOOLKIT::encode_latin1($el->{$k}).'"';
					}
				$didit{$k}++;
				}
			$out .= ">".(($middle ne '')?"\n".$middle."\n":'')."</ELEMENT>\n";
			}
		}	
	if ($mode == 1) { $out = "<?ZOOVY_DW_PLUGIN V=\"1\"?>".$out; }

	return($out);
	}


##
## returns an element by ID
##
sub fetchElement{
	my ($self, $ID, $DIV) = @_;
	
	my $RESULT = undef;
	# foreach my $el (@{$self->{'_ELEMENTS'}}) {
	my $divref = $self->getElements($DIV);
	if (defined $divref) {
		foreach my $el (@{$divref}) {
			next if ($el->{'ID'} ne $ID);
			$RESULT = $el;
			}
		}
	return($RESULT);
	}

##
## returns all the elements as an arrayref
##		parameters: $DIVID (which DIVID to load the elements from)
##		
##	note: 
##		a special DIVID of "@BATCH" returns all fields which are available in batch mode.
##		a special DIVID of "@PROFILE" returns all fields which are available in profile mode.
##
sub getElements { 
	my ($self,$DIVID) = @_;


	if ((not defined $DIVID) || ($DIVID eq '')) { return($_[0]->{'_ELEMENTS'});  }
	elsif (($DIVID eq '@PROFILE') || ($DIVID eq '@BATCH')) {
		my @ar = ();
		foreach my $el (@{$_[0]->{'_ELEMENTS'}}) {
			## Skip: TYPE= FORMAT, BUTTON, HIDDEN, READONLY, META, BLANK
			next if ($el->{'DATA'} eq '');
			next if ($el->{'PROMPT'} eq '');
			my ($ns,$attr) = split(/\:/,lc($el->{'DATA'}));
			if ($ns eq 'merchant') { $ns = 'profile'; }

			next if (($DIVID eq '@PROFILE') && ($ns ne 'profile'));
			next if (($DIVID eq '@BATCH') && ($ns ne 'product') && ($ns ne 'channel') && ($ns ne 'sku') && 
					($el->{'TYPE'} ne 'FORMAT') && ($el->{'TYPE'} ne 'OUTPUT') && 
					($el->{'TYPE'} ne 'BUTTON') && ($el->{'TYPE'} ne 'DISPLAY') && ($el->{'TYPE'} ne 'HIDDEN') );
			push @ar, $el;
			}

		return(\@ar);
		}

	my $result = undef;
	foreach my $divref (@{$_[0]->{'_DIVS'}}) {
		if (uc($divref->{'ID'}) eq $DIVID) {
			$result = $divref->{'_ELEMENTS'};
			}
		}

	return($result);
	}

## this is NOT div compatible.. use getElements instead
sub elements { 
	return($_[0]->{'_ELEMENTS'}); 
	}


sub getFlexEdit {
	my ($self) = @_;

	require PRODUCT::FLEXEDIT;

	my @FE = ();
	foreach my $el (@{$self->getElements('@BATCH')}) {
		next if ($el->{'READONLY'});		# these aren't editable

		my $id = lc($el->{'DATA'});
		next if ($id !~ /^product\:(.*?)$/);
		my $fe = { id=>$1, title=>$el->{'PROMPT'}, type=>lc($el->{'TYPE'}) };
		
		if (defined $PRODUCT::FLEXEDIT::fields{ $fe->{'id'} }) {
			my %tmp = %{$PRODUCT::FLEXEDIT::fields{ $fe->{'id'} }};
			$tmp{'id'} = $fe->{'id'};
			$fe = \%tmp;
			}

		foreach my $k (keys %{$el}) {
			next if ($k eq 'ID');
			next if ($k eq 'PROMPT');
			next if ($k eq 'TYPE');
			$fe->{lc($k)} = $el->{$k};
			}
		push @FE, $fe;
		}
	return(\@FE);
	}


##
## returns a list - formatted as an arrayref (sorted)
##		{ VALUE=> PROMPT=> }
sub getList {
	my ($self,$LISTID) = @_;

	# print STDERR "LIST: $LISTID\n";
	$LISTID = uc($LISTID);
#	print STDERR "LISTID: $LISTID\n";
	##
	## OVERRIDES - eBAY
	##
	my ($MARKET,$DEFINITION) = split(/\./,lc($self->{'_ID'}),2);
	$MARKET =~ s/[^\w\@]+//gs;	# sometimes there is a * or something.. e.g. *blah
#	print STDERR "MARKET[$MARKET] LIST:[$LISTID]\n";
#	if ((($MARKET eq 'ebay') || ($MARKET eq 'ebaymotors') || ($MARKET eq 'ebaystore') || ($MARKET eq 'ebaystores')) && ($LISTID eq 'STORECAT')) {
#		require EBAY2;
#		my $list = &EBAY2::fetch_storecats($self->{'_USERNAME'});
#		my @RESULT = ();
#		my $count = 0;
#		push @RESULT, { 'T'=>'Not Selected', V=>'' };
#		foreach my $kv (@{$list}) {
#			my ($k,$v) = split(/,/,$kv,2);
#			push @RESULT, { 'T'=>$v, 'V'=>$k };
#			$count++;
#			}
#		if ($count>1) { 
#			return(\@RESULT); 
#			}
#		}
	if ($LISTID eq '@SYSTEM.DOMAINS') {
		my @RESULT = ();
		push @RESULT, { T=>$self->{'_USERNAME'}."\@zoovy.com", V=>$self->{'_USERNAME'}."\@zoovy.com" };
		return(\@RESULT);
		}
	elsif ($LISTID eq '@SYSTEM.SEARCHCATALOGS') {
		my @RESULT = ();
		require SEARCH;
		my $catalogsref = &SEARCH::list_catalogs($self->{'_USERNAME'});
		foreach my $ref (values %{$catalogsref}) {
			push @RESULT, { 'T'=>$ref->{'CATALOG'}, 'V'=>$ref->{'CATALOG'} };
			}
		return(\@RESULT);
		}


	##
	## NOTE: eventually we could let the user upload their own custom overrides.
	##			possibly even build a tool to let the customize the lists.
	##
	my $RESULT = undef;
	foreach my $listref (@{$self->{'_LISTS'}}) {
		next unless (uc($listref->{'ID'}) eq $LISTID);
		$RESULT = $listref->{'_OPTS'};		
		}

	return($RESULT);
	}

##
## getListOptByAttrib
##		note: $KEY can be a regular expression
##		future thinking: eventually we can probably build quicker lookup tables and selectively load 
##			large lists, this would allow us to optimize this function at a later date.
##		returns: an arrayref of matching opt nodes.
##			e.g.
##				[ { V=>'', T=>'' }, { V=>'', T=>'' } ]
##			note: at this time sort order is preserved, but that behavior is NOT guarnteed
##
sub getListOptByAttrib {
	my ($self,$LISTID,$ATTRIB,$KEY) = @_;

	my @results = ();
	my $listarref = $self->getList($LISTID);

	# print STDERR Dumper($listref);

	if (not defined $listarref) { warn "Called toxml->getListOptByAttrib for List[$LISTID] failed (does not exist)"; }
	elsif (scalar(@{$listarref})==0) { warn "List[$LISTID] did not appear to have any _OPTS"; }
	elsif (ref($KEY) eq 'Regexp') {
		foreach my $opt (@{$listarref}) {
			next unless ($opt->{$ATTRIB} =~ $KEY);	
			push @results, $opt;
			}
		}
	elsif (ref($KEY) eq '') {	# scalar
		foreach my $opt (@{$listarref}) {
			next unless ($opt->{$ATTRIB} eq $KEY);
			push @results, $opt;
			}
		}
	return(\@results);	
	}


##
## returns an ARRAY of elements matching a given type
##		note: DOES NOT SEARCH DIVS, only elements on the parent.
##
##	TYPE examples: CONFIG, TEXTBOX, etc.
##
sub getElementsByType { return($_[0]->findElements(@_)); }
sub findElements {
	my ($self,$TYPE) = @_;

	my @ar = ();
	if (defined $self->{'_ELEMENTS'}) {
		foreach my $el (@{$self->{'_ELEMENTS'}}) {
			next if ($el->{'TYPE'} ne $TYPE);
			push @ar, $el;
			}	
		}

	return(@ar);
	}


sub getElementById {
	my ($self,$ID) = @_;

	my @ar = ();
	if (defined $self->{'_ELEMENTS'}) {
		foreach my $el (@{$self->{'_ELEMENTS'}}) {
			next if ($el->{'ID'} ne $ID);
			push @ar, $el;
			}	
		}

	return(@ar);	
	}

##
## This function is used by the following areas:
##		/backend/lib/PAGE/AJAX.pm
##			renderProduct( SKU=> )
##		/backend/lib/OVERSTOCK/LISTING.pm
##			LISTING::create( USERNAME=>, SKU=>, PROFILE=>, MARKET=>, UUID=>, CHANNEL=>, nsref=>$nsref, sref=>$dataref )
##		/backend/lib/OVERSTOCK/API.pm
##			API::assemble( USERNAME, SKU, PROFILE, UUID, MARKET, CHANNEL, nsref=>, $sref=>$dataref)
##		/backend/lib/EBAY/CREATE.pm
##			CREATE::doit2( USERNAME, SKU, PROFILE, MARKET, UUID, CHANNEL, nsref, sref=>)
##		/backend/lib/CUSTOMER/NEWSLETTER.pm
##			PG=>,USERNAME=>
##		/backend/lib/TOXML/EMAIL.pm
##			USERNAME,PROFILE,DIV=>$MSG,PG=>$MSG,nsref=>$nsref
##		/backend/lib/TOXML/EMAIL.pm
##			USERNAME,PROFILE,nsref=>$nsref
##
##
## returns HTML for a particular TOXML object based on optional parameters passed in.
##		OPTIONSTR=> - used in configurator, etc. a string of KEY=VALUE for each option (for text VALUE is the text, for other it's value id)
## 	SKU=>the sku of the item in focus (if one is available)
##		PROFILE - the name of the profile e.g. 'DEFAULT' that merchant properties should be loaded from
##		DATAREF=> a hashref keyed by 
##		DOMAIN=>sdomain in focus
##		ORDER=>order object we're working with.
##
##	note: dataref, and SKU are really required for product pages!?!? (hmm, maybe not)
##
## hmm.. so if we pass something in on OPTIONS it should override the SREF (but we should backup the SREF first)
##		we really really really need to do some data handling cleanup in here.
##
## possible SREF (session reference) variables;
##		_PG, _ID, _SKU, _PID, _FS, 
##		_ROOTCAT		
##
##
## sref variables:
##		+secure = 1/0 (for http/https) 
##
sub render {
	my ($self,%options) = @_;

	my $SITE = $options{'*SITE'};
	if (not defined $SITE) {
		warn Carp::confess("*SITE is a required parameter for TOXML->render()");
		}
	elsif (ref($SITE) ne 'SITE') {
		warn Carp::confess("*SITE must be a valid SITE object");
		}

	if (defined $options{'*CART2'}) {
		## note: *CART2 is compatible with SITE->new reference
		$SITE->{'*CART2'} = $options{'*CART2'};
		}

	if (defined $options{'*P'}) {
		$SITE->{'*P'} = $options{'*P'};
		}

	if (defined $options{'SKU'}) { 
		$SITE->{'_PID'} = $options{'SKU'};
		$SITE->{'_SKU'} = $options{'SKU'};

		if (not defined $options{'*P'}) {
			$SITE->{'*P'} = PRODUCT->new($options{'USERNAME'}, $SITE->{'_SKU'});
			}
		}	

	$SITE->layout( $self->{'_ID'} );
	if (defined $options{'PG'}) { die(); } # $SITE->pageid( $options{'PG'} ); }

	## THIS FUCKING GHETTO HACK. TO FIX NEWSLETTERS. IF THIS IS SET, THEN WE'RE PROBABLY RUNNING
	## IN A WEBSITE
	if (ref($SITE) eq 'SITE') {
		}

#	use Data::Dumper;
	if (($self->{'_FORMAT'} eq 'ZEMAIL') || ($self->{'_FORMAT'} eq 'EMAIL')) {
		$self->initConfig($SITE);
		$SITE->URLENGINE()->set(toxml=>$self);
#		print STDERR Dumper($self,$SITE->URLENGINE(),$SITE::CONFIG); 
		}
	elsif ($self->{'_FORMAT'} eq 'WIZARD') {
		$SITE->URLENGINE()->set(toxml=>$self);
		}
	elsif ($self->{'_FORMAT'} eq 'NEWSLETTER') {
		$self->initConfig($SITE);
		$SITE->URLENGINE()->set(toxml=>$self);
#		print STDERR Dumper($self,$SITE->URLENGINE(),$SITE::CONFIG); 
		}
#	elsif ($self->{'_FORMAT'} eq 'ORDER') {
#		$self->initConfig();
#		}
	elsif ($self->{'_FORMAT'} eq 'LAYOUT') {
		## $SITE::SREF->{'_FS'} = $self->{'_SUBTYPE'}; -- this should not be used anywhere!
		$SITE->URLENGINE()->set(wrapper=>$SITE->wrapper());
		if ($SITE->URLENGINE()->wrapper() ne '') {
			## apparently called from website builder
			warn "toxml->render attempting to load load wrapper ".$SITE->URLENGINE()->wrapper()."\n";
			my ($toxml) = TOXML->new('WRAPPER',$SITE->URLENGINE()->wrapper(),USERNAME=>$SITE->username());
			if (defined $toxml) {
				$toxml->initConfig($SITE);
				}	
			}
		}

	# $SITE->{'_PG'} = $SITE::PG;		# don't set this and newsletters won't work
	# print STDERR "[TOXML] ".Dumper($SREF);

	my $out = undef;
	if ($SITE->div()) { $options{'DIV'} = $SITE->div(); }

	require TOXML::RENDER;
	($out) = &TOXML::RENDER::render_page(\%options,$self,$SITE);

	return($out);
	}








1;