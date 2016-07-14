package kmasker::occ;
use Exporter qw(import);
use jellyfish;
use File::Basename;
use kmasker::filehandler;
use POSIX qw/ceil/;
use strict;
use warnings;
our @ISA = qw(Exporter);
our @EXPORT = qw(normalize_occ apply_occ);
our @EXPORT_OK = qw(make_occ normalize_occ apply_occ);


#sub make_index{
#	$file = $_[1]
#	$mer = $_[2]
#	$c = $_[3]
#	$size = $_[4]
#	$threads = $_[5]
#} # Do this step external? # Maybe the workflow implementation from RNA-Seq-Pipeline

sub make_occ{
	my $file=$_[0];
	my $index=$_[1];
	my $mer=$_[2];
	(my $name,my $path,my $suffix) = fileparse($file, qr/\.[^.]*/);
	open(my $fasta, "<", "$file") or die "Can not open $file\n";
	open(my $occ, ">", $path.$name.".occ") or die "Can not write to " . $path.$name.".occ\n";
	my $qmerfile = jellyfish::QueryMerFile->new($index);
	my $seqname="";
	my %seqdata;
	while (read_sequence($fasta, \%seqdata)) {
			print $occ ">".$seqdata{header}."\n";
			#calculate the values for the occ file
			my $overhead = $mer - 1;
			my @values;
			$values[(length($seqdata{seq})-$overhead)..length($seqdata{seq})]=0;
			for (my $i = 0; $i < (length($seqdata{seq})-$overhead); $i++) { #q means query
				#print $i . " : " ;
				#we have to differentiate genome and reads in the future, because reads are canonicalized
				my $kmer = substr($seqdata{seq}, $i, $mer);
				print "$kmer :";
				my $qkmer = jellyfish::MerDNA->new($kmer);
				my $count = $qmerfile->get($qkmer);
				print  " $qkmer : $count \n";
				$values[$i]=$count
			}
			print $occ "@values\n";
	}
	close($fasta);
	close($occ);
}

sub normalize_occ{
	my $file = $_[0];
	my $depth = $_[1];
	my %seqdata;
	(my $name,my $path,my $suffix) = fileparse($file, qr/\.[^.]*/);
	open(my $occ, "<", "$file") or die "Can not open $file\n";
	open(my $occ_norm, ">", $path.$name."_normalized.occ") or die "Can not write to " . $path.$name."_normalized.occ\n";
	if ($depth == 1) {
		print "Nothing to do! Depth was 1. \n";
		return;
	}
	else {
	while (read_occ($occ, \%seqdata)) {
		print $occ_norm ">".$seqdata{header}."\n";
		my @values = split /\s+/ , $seqdata{seq};
		foreach(@values) {
			#print $_ . ": $depth = " . ceil($_/$depth) . "\n" ;
			$_ = ceil($_/$depth);

			}
		print $occ_norm "@values\n";
		}
	}
}

sub apply_occ{
	my $fasta_file = $_[0];
	my $occ_file = $_[1];
	my $rept = $_[2];
	my %seqdata;
	my %occ_data;
	open(my $occ, "<", "$occ_file") or die "Can not open $occ_file\n";
	open(my $fasta, "<", "$fasta_file") or die "Can not open $fasta_file\n";

	(my $name,my $path,my $suffix) = fileparse($fasta_file, qr/\.[^.]*/);
	open(my $freakmaskedFASTA, ">", "$path/freakmasked_RT$rept.$name$suffix") or die "Can not write to " . "$path/freakmasked_RT$rept.$name$suffix\n" ;
	while(read_sequence($fasta, \%seqdata) && read_occ($occ, \%occ_data)) {
		my @sequence = split '', $seqdata{seq};
		my @occvalues = split /\s+/, $occ_data{seq};
		#print $seqdata{header} . " " . $occ_data{header} . "\n";
		#print length($seqdata{seq}) . " " . length($occ_data{seq}) . "\n";
		#for (my $k = 0; $k < scalar(@sequence); $k++) {
		#	print $occvalues[$k];
		#	print " ";
		#	print $sequence[$k];
		#	print "\n";
		#}
		if($seqdata{header} ne $occ_data{header}) {
			print "Warning: Headers in occ and fasta are different! \n";
		}
		if(scalar(@sequence) != scalar(@occvalues)) {
			die "Sorry your occ input has an different length than the fasta file !\n " . scalar(@sequence) . "!=" . scalar(@occvalues) . "\n";
		}
		for (my $i = 0; $i < scalar(@sequence); $i++) {
			if($occvalues[$i] > $rept) {
				#we will mask the sequnce in this part
				$sequence[$i] = "X";
			}
		}
		print $freakmaskedFASTA ">" .$seqdata{header}."\n";
		foreach(@sequence){
			print $freakmaskedFASTA $_;
		}
		print $freakmaskedFASTA "\n";

	}

}

1;