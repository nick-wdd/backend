package LUSER;

use Data::Dumper;
use POSIX;
use URI::Escape::XS;
use lib "/backend/lib";
require DBINFO;
require ZOOVY;
require ZTOOLKIT;
require OAUTH;
use strict;
use Storable;






##
##
##
sub hasACL {
	my ($self,$obj,$perm) = @_;

	my $ACL = $self->{'%ACL'};
	## print STDERR 'has ACL: '.Dumper($ACL,$obj,$perm);
	if (not $ACL) { 
		warn "acl in hasACL is blank (this line should never be reached)\n";
		$ACL = {}; 
		}
	if (not defined $ACL->{$obj}) { 
		return(0);
		}
	elsif ($ACL->{$obj}->{$perm}) {
		return(1);
		}

	return(0);
	}



##
## returns the Level the customer is at.
##
#sub level {
#	return(($_[0]->{'CACHED_FLAGS'} =~ /,L([\d]+),/)?int($1):1);
#	}

##
## checks for L0..L9 flag.. matches against the number and returns true if we're greater than or equal to.
##
#sub is_level {
#	my ($self,$level) = @_;
#	return(($self->{'CACHED_FLAGS'} =~ /,L([\d]+),/)?(int($1)>=$level):0);
#	}

sub is_bpp {
	my ($self,$level) = @_; return(($self->flags() =~ /,BPP,/)?1:0);
	}


##
## 'OBJECT'=>'C|D|R'
##
sub acl_require {
	my ($self, %flags) = @_;
	my @ISSUES = ();
	
	foreach my $object (keys %flags) {
		if (not $self->{'%ACL'}->{$object}) {
			push @ISSUES, "No roles provide access to '$object'";
			}
		else {
			foreach my $perm (@{$flags{$object}}) {
				if ($self->{'%ACL'}->{$object}->{$perm} eq '+') {
					## GOOD TO GO
					}
				else {
					push @ISSUES, "No roles provide $OAUTH::ACL_PRETTY{$perm} to '$object'";
					}
				}
			}
		}	

	return(@ISSUES);
	}


##
## simple shortcut
##
sub is_admin {
	my ($self) = @_;
	
	my $is_admin = (($self->{'IS_ADMIN'} eq 'Y')?1:0);
	if (not $is_admin) {
		if ($self->{'CACHED_FLAGS'} =~ /,_ADMIN,/) { $is_admin |= 1; }
		}
	if ($self->is_support()) { $is_admin |= 2; }
	if (uc($self->luser()) eq 'ADMIN') { return(4); }

	return( $is_admin );
	}

## returns the ACCOUNT record for the current user
sub account { my ($self) = @_; require ACCOUNT; return(ACCOUNT->new($self->username(),$self->luser())); }


##
## use anycommerce rules
##
sub is_anycom {
	my ($self) = @_;
	return( ($self->{'CACHED_FLAGS'} =~ /PKG=ANYONE/)?1:0 );
	}

##
## is zoovy employee?
##
sub is_zoovy { return($_[0]->is_support()) };
sub is_support {
	my ($self) = @_;

	if (uc($self->luser()) eq 'SUPPORT') { return(1); }
	if ($self->luser() =~ /^[Zz][Oo][Oo][Vv][Yy]\//) { return(1); }
	return(0);
	}

##
## AREA:
##		e.g. SETUP.GLOBAL
##		e.g. PRODUCT.SKU
##
## MESSAGE: 
##		Saved Settings
##
##	TYPE:
##		INFO - a non-specific, state setting.
##		SAVE - some type of data was updated/changed
##		ERR - user was displayed an error
##		WARN - user was displayed a warning and/or some type of warning was thrown for account.
##		DENY - user was denied access, and a log notification was recorded.
##
sub log {
	my ($self,$AREA,$MSG,$TYPE) = @_;

	##
	## NOTE: this is also called directly (not from an object) via WEBAPI::userlog
	##

	if ($TYPE eq '') { $TYPE = 'INFO'; }
	my $LUSER = $self->{'LUSER'};
	if ((not defined $LUSER) || ($LUSER eq '')) { $LUSER = 'ADMIN'; }

	my $yyyymm = POSIX::strftime("%Y%m",localtime(time()));

	my ($logfile) = &ZOOVY::resolve_userpath($self->{'USERNAME'})."/access-$yyyymm.log";
	open F, ">>$logfile";
	my $date = POSIX::strftime("%Y%m%dt%H%M%S",localtime(time()));
	if (ref($MSG) eq 'ARRAY') {
		## pass in an array ref of [msg,type],[msg,type],...
		foreach my $set (@{$MSG}) {
			print F sprintf("%s\t%s\t%s\t%s\t%s\n",$date,$LUSER,$AREA,$set->[0],$set->[1]);		
			}
		}
	else {
		print F sprintf("%s\t%s\t%s\t%s\t%s\n",$date,$LUSER,$AREA,$MSG,$TYPE);
		}
	close F;
	chmod 0666, $logfile;
	}


sub username { my ($self) = @_; return($self->{'USERNAME'}); }
sub luser { my ($self) = @_; return($self->{'LUSERNAME'}); }

##
## returns USERNAME or USERNAME*LOGIN
##
sub login {
	my ($self) = @_;
	
	if (($self->{'LUSER'} eq '') || ($self->{'LUSER'} eq 'ADMIN')) {
		return($self->{'USERNAME'});
		}
	else {
		return($self->{'USERNAME'}.'*'.$self->{'LUSER'});
		}
	
	}

##
## this will check to see if a users password matches the password on file.
##
sub passmatches {
	my ($self,$password) = @_;


	$password = lc($password);		## passwords are case insensitive
	if ($password eq '') { return(0); }		## never return true if password is not set.

	my $MID = int($self->{'MID'});

	my $UID = int($self->{'UID'});

	my $udbh = &DBINFO::db_user_connect($self->username());
	require Digest::MD5;
	my $digest = Digest::MD5::md5_hex($password);
	my $qtDIGEST = $udbh->quote($digest);

	my $pstmt = '';
	if ($self->{'UID'} == 0) {
		$pstmt = "select count(*) from ZUSERS where MID=$MID /* $self->{'USERNAME'} */ and md5(lower(PASSWORD))=$qtDIGEST";
		}
	else {
		$pstmt = "select count(*) from ZUSER_LOGIN where MID=$MID /* $self->{'USERNAME'} */ and UID=$UID and md5(lower(PASSWORD))=$qtDIGEST";
		}
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my ($count) = $sth->fetchrow();
	$sth->finish();

	&DBINFO::db_user_close();
	return($count);
	}

##
## changes the users password
##
sub set_password {
	my ($self,$password) = @_;

	my $udbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = '';
	my $MID = int($self->{'MID'});
	my $UID = int($self->{'UID'});
	my $qtPASS = $udbh->quote($password);
	
	if ($self->{'UID'} == 0) {
		$pstmt = "update ZUSERS set PASSWORD_CHANGED=now(),PASSWORD=$qtPASS where MID=$MID /* $self->{'USERNAME'} */ limit 1";
		}
	else {
		$pstmt = "update ZUSER_LOGIN set PASSWORD_CHANGED=now(),PASSWORD=$qtPASS where MID=$MID and UID=$UID /* $self->{'LUSER'} */";		
		}
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}


##
## naming convention for keys:
##		prodedit.panel (1=open,0=closed)
##
sub set {
	my ($self,$property,$value) = @_;

	if (substr($property,0,1) eq '_') {}	# can't set these properties!
	else {
		my $property = lc($property);
		if (not defined $self->{'dataref'}) { $self->{'dataref'} = {}; }
		if (not defined $value) {
			delete $self->{'dataref'}->{$property}; $self->{'changed'}++; 		# pass an undef to delete a key
			}
		elsif ($self->{'dataref'}->{$property} ne $value) {
			$self->{'dataref'}->{$property} = $value;
			$self->{'changed'}++;
			}

		# print STDERR 'SET: '.Dumper($self->{'dataref'});
		}
	return(0);
	}



sub email {
   my ($self) = @_;

	if ($self->{'HAS_EMAIL'} eq 'Y') {
		$self->{'EMAIL'} = $self->{'LUSER'}.'@'.$self->{'USERNAME'}.'.zoovy.com';
		}

	return($self->{'EMAIL'});
   }


##
## returns a list of all properties that are exportable.
##
sub properties {
	my ($self) = @_;
	my @keys = keys %{$self->{'dataref'}};
	return(@keys);
	}


##
##	
sub get {
	my ($self,$property,$defaultvalue) = @_;

	my $result = undef;
	if (substr($self,0,1) eq '_') {
		## _PROPERTY is a reference to a db property	
		}
	else {
		## whereas anything else is just a reference to a key of data.
		$property = lc($property);
		$result = $self->{'dataref'}->{$property};
		# use Data::Dumper; print STDERR "PROPERTY: $property [$result] ".Dumper($self)."\n";
		}

	if (not defined $result) { $result = $defaultvalue; }

	return($result);
	}

##
##
sub save {
	my ($self) = @_;

	if ($self->{'changed'}) {
		my $udbh = &DBINFO::db_user_connect($self->username());
		my $DATA = &encodeini($self->{'dataref'});

		#if (($self->{'HAS_EMAIL'} eq 'Y') && ($self->{'dataref'}->{'zoovy:email'} eq '')) {
		#	## they have zoovymail enabled AND their email address is blank!
		#	if ($self->{'IS_MASTER'}) { 
		#		$self->{'EMAIL'} = "admin\@".$self->{'USERNAME'}.".zoovy.com";
		#		}
		#	else {
		#		$self->{'EMAIL'} = $self->{'LUSER'}."\@".$self->{'USERNAME'}.".zoovy.com"; 
		#		}
		#	}

		my $LUSER = $self->{'LUSER'};
		if ($LUSER eq 'ADMIN') { $LUSER = undef; }
		if ($LUSER eq 'SUPPORT') { $LUSER = undef; }

		my $qtDATA = $udbh->quote($DATA);
		my $qtPHONE = $udbh->quote( (defined $self->{'dataref'}->{'zoovy:phone'})?$self->{'dataref'}->{'zoovy:phone'}:'');
		my $qtEMAIL = $udbh->quote( (defined $self->{'dataref'}->{'zoovy:email'})?$self->{'dataref'}->{'zoovy:email'}:'');

		my $pstmt = '';
		my ($USERNAME,$MID) = (undef,0);

		if (defined $self->{'USERNAME'}) {
			$USERNAME = $self->{'USERNAME'};
			$USERNAME =~ s/[\W]+//gs;
			$MID = &ZOOVY::resolve_mid($USERNAME);
			}

		my ($memd) = &ZOOVY::getMemd($USERNAME);
		if (defined $memd) {
			$memd->delete("USER:$USERNAME.$LUSER");
			$memd->delete("USER:$USERNAME.$self->{'LUSER'}");
			}

		if (not defined $USERNAME) {
			}
		elsif (defined $LUSER) {
			$pstmt = "update ZUSER_LOGIN set EMAIL=$qtEMAIL,DATA=".$qtDATA." where MID=".$MID." /* $USERNAME */ and LUSER=".$udbh->quote($self->{'LUSER'});
			}
		else {
			$pstmt = "update ZUSERS set EMAIL=$qtEMAIL,PHONE=$qtPHONE,DATA=".$qtDATA." where MID=".$MID." /* $USERNAME */";
			}
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		

		&DBINFO::db_user_close();
		$self->{'changed'}=0;
		}
	}

sub encodeini {
	my ($paramsref) = @_;

	my $txt = "\n";
	foreach my $k (sort keys %{$paramsref}) {
		next if (substr($k,0,1) eq '?');
		$paramsref->{$k} =~ s/[\n\r]+//gs;
		$txt .= "$k=$paramsref->{$k}\n";
		}
	return($txt);
	}

sub decodeini {
	my ($initxt) = @_;

	my %result = ();
	foreach my $line (split(/\n/,$initxt)) {		
		next if ($line eq '');
		my ($k,$v) = split(/=/,$line,2);
		$result{$k} = $v;
		}
	# use Data::Dumper; 
	# print STDERR "DECODE INI: ".Dumper(\%result);
	return(\%result);
	}

sub new {
	warn "LUSER->new no longer supported\n";
	Carp::confess("LUSER->new no longer supported\n");
	}


##
##
sub flags { 
	my ($self) = @_;
	if (not defined $self->{'CACHED_FLAGS'}) {
		my ($globalref) = &ZWEBSITE::fetch_globalref($self->username());
		$self->{'CACHED_FLAGS'} = sprintf(",%s,",$globalref->{'cached_flags'});
		}	
	#elsif (substr($self->{'CACHED_FLAGS'},0,1) ne ',') {		
	#	$self->{'CACHED_FLAGS'} = sprintf(",%s,",$self->{'CACHED_FLAGS'});
	#	}
	print STDERR "FLAGS: $self->{'CACHED_FLAGS'}\n";
	return($self->{'CACHED_FLAGS'}); 
	}

sub mid { return($_[0]->{'MID'}); }
sub prt {
	if (defined $_[1]) { $_[0]->{'PRT'} = $_[1]; }
	return($_[0]->{'PRT'});
	}

sub domainname { my ($self) = shift @_; return($self->domain(@_)); }
sub domain {
	if ($_[1]) { $_[0]->{'DOMAIN'} = $_[1]; }
	return($_[0]->{'DOMAIN'});
	}


sub authinfo {
	my ($self) = @_;

	return( $self->mid(), $self->username(), $self->luser(), $self->flags(), $self->prt(), '');
	}

sub new_oauth {
	my ($class,$USERNAME,$AUTHTOKEN) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $self = undef;
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select * from OAUTH_SESSIONS where MID=$MID and AUTHTOKEN=".$udbh->quote($AUTHTOKEN);
	$self = $udbh->selectrow_hashref($pstmt);
	if (defined $self) {
		$self->{'CACHED_FLAGS'} = sprintf(",%s,",$self->{'CACHED_FLAGS'}); 
		bless $self, 'LUSER';
		}
	&DBINFO::db_user_close();

	if (ref($self) eq 'LUSER') {
		$self->{'%ACL'} = YAML::Syck::Load($self->{'ACL'});
		delete $self->{'ACL'};
		}

	return($self);
	}


sub new_trusted {
	my ($class,$USERNAME,$SUBUSER,$PRT) = @_;

	$SUBUSER = uc($SUBUSER);
	#if ($SUBUSER eq '') { $SUBUSER = 'ADMIN'; }
	#if (($SUBUSER eq 'SUPPORT') || ($SUBUSER eq 'ADMIN') || ($SUBUSER =~ /^ZOOVY\//)) { $SUBUSER = 'ADMIN'; }

	$USERNAME =~ s/[\W]+//gs;  #sanitize username
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $self = undef;

	my $ERROR = undef;
	my $pstmt = '';
	if ($MID<=0) {
		$ERROR = "User: $USERNAME not found";
		}
	elsif ($SUBUSER eq 'ADMIN') {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select DATA,CACHED_FLAGS from ZUSERS where MID=".$MID." /* $USERNAME */";
		print STDERR "$pstmt\n";
		$self = $udbh->selectrow_hashref($pstmt);
		&DBINFO::db_user_close();
		}
	else {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select UID, DATA from ZUSER_LOGIN where MID=".$MID." /* $USERNAME */ and LUSER=".$udbh->quote($SUBUSER);
		print STDERR "$pstmt\n";
		$self = $udbh->selectrow_hashref($pstmt);
		&DBINFO::db_user_close();
		}

	if (not $ERROR) {
		$self->{'MID'} = $MID;
		bless $self, 'LUSER';

		my @MYROLES = ();
		if (($SUBUSER eq 'ADMIN') || ($SUBUSER eq 'SUPPORT') || ($SUBUSER =~ /^ZOOVY\//)) {
			## master login
			$self->{'LUSER'} = $SUBUSER;
			$self->{'UID'} = 0;
			if ($self->{'CACHED_FLAGS'} =~ /,ZM/) { $self->{'HAS_EMAIL'} = 'Y'; }
			push @MYROLES, 'BOSS';
			}
		else {
			## Luser login
			@MYROLES = split(/;/,$self->{'ROLES'});
			}
		$self->{'%ACL'} = &OAUTH::build_myacl($USERNAME,\@MYROLES);

		$self->{'dataref'} = &decodeini($self->{'DATA'});
		delete $self->{'DATA'};
		$self->{'USERNAME'} = $USERNAME;
		$self->{'LUSERNAME'} = $SUBUSER;
		if (defined $PRT) { $self->{'PRT'} = $PRT; }
		$self->{'EMAIL'} = $self->{'dataref'}->{'zoovy:email'};	## note: this is redundant.
		$self->{'PHONE'} = $self->{'dataref'}->{'zoovy:phone'};
		}
	return($self);
	}

sub new_app {
	my ($class,$USERNAME,$APP) = @_;

	my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	$self->{'LUSER'} = "*$APP";
	$self->{'IS_APP'} = 1;

	bless $self, 'LUSER';
	return($self);
	}


1;