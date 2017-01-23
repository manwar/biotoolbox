package Bio::ToolBox::parser::gff;

our $VERSION = '1.44';

=head1 NAME

Bio::ToolBox::parser::gff - parse GFF3, GTF, and GFF files 

=head1 DESCRIPTION

This module parses a GFF file into SeqFeature objects. It natively 
handles GFF3, GTF, and general GFF files. 

For both GFF3 and GTF files, fully nested gene models, typically 
gene => transcript => (exon, CDS, etc), may be built using the appropriate 
attribute tags. For GFF3 files, these include ID and Parent tags; for GTF 
these include gene_id and transcript_id tags. 

For GFF3 files, any feature without a Parent tag is assumed to be a 
parent. Children features referencing a parent feature that has not been 
loaded are considered orphans. Orphans are attempted to be re-associated 
with missing parents after the file is completely parsed. Any orphans left 
may be collected. Files with orphans are considered poorly formatted or 
incomplete and should be fixed. Multiple parentage, for example exons 
shared between different transcripts of the same gene, are fully supported.

Embedded Fasta sequences are ignored, as are most comment and pragma lines.

The SeqFeature objects that are returned are L<Bio::ToolBox::SeqFeature> 
objects. Refer to that documentation for more information.

=head1 SYNOPSIS

  use Bio::ToolBox::parser::gff;
  my $filename = 'file.gff3';
  
  my $parser = Bio::ToolBox::parser::gff->new($filename) or 
  	die "unable to open gff file!\n";
  
  while (my $feature = $parser->next_top_feature() ) {
	# each $feature is a SeqFeature object
	my @children = $feature->get_SeqFeatures();
  }

=head1 METHODS

=head2 Initializing the parser. 

=over 4

=item new()

Initialize a new gff parser object. Pass a single value (a GFF file name) 
to open a file. Alternatively, pass an array of key value pairs to control 
how the file is parsed. Options include the following.

=over 4

=item file

Provide a GFF file name to be parsed. It should have a gff, gtf, or gff3 file 
extension. The file may be gzip compressed. 

=item version

Specify the version. Normally this is not needed, as version can be determined 
either from the file extension (in the case of gtf and gff3) or from the 
##gff-version pragma at the top of the file. Acceptable values include 1, 2, 
2.5 (gtf), or 3.

=item skip 

Pass an anonymous array of primary_tag values to be skipped from the GFF file 
when parsing into SeqFeature objects. For example, some subfeatures can be skipped 
for expediency when they known in advance not to be needed. See skip() below.

=item class

Pass the name of a L<Bio::SeqFeatureI> compliant class that will be used to 
create the SeqFeature objects. The default is to use L<Bio::ToolBox::SeqFeature>.

=item simplify

Pass a boolean value to simplify the SeqFeature objects parsed from the GFF 
file and ignore extraneous attributes.

=back

=back

=head2 Parser behavior

These are additional class methods that control the parsing behavior of a 
new object. Unpredictable behavior may occur if you implement these in the 
midst of parsing a file.

=over 4

=item open_file($file)

Pass the name of a GFF file to be parsed. The file may optionally be gzipped 
(.gz extension). Do not open a new file when one has already opened a file. 
Create a new object for a new file, or concatenate the GFF files.

=item fh()

=item fh($filehandle)

This method returns the IO::File object of the opened GFF file. A new 
file may be parsed by passing an opened IO::File or other object that 
inherits IO::Handle methods.  

=item version

Set or get the GFF version of the current file. Acceptable values include 1, 2, 
2.5 (gtf), or 3.

=item skip(@types)

Pass an array of primary_tag values that should be skipped during 
parsing. This can simplify and speed up parsing if certain types of subfeatures 
are known in advance not to be needed. Only exact matches are allowed. 
Best if this method is called prior to file parsing. This method also returns 
a list of the primary_tag values to be skipped. Examples include

=over 4

=item * CDS

=item * five_prime_UTR

=item * three_prime_UTR

=item * start_codon

=item * stop_codon

=back

=item simplify(1)

Pass a boolean true value to simplify the attributes of GFF3 and GTF files 
that may have considerable numbers of tags, e.g. Ensembl files. Only 
essential information, including name, ID, and parentage, is retained. 
Useful if you're trying to quickly parse annotation files for basic 
information.

=back

=head2 Feature retrieval

The following methods parse the GFF file lines into SeqFeature objects. 
It is best if methods are not mixed; unexpected results may occur. 

=over 4

=item next_feature()

This method will return a SeqFeature object representation of 
the next feature in the file. Parent - child relationships are NOT 
assembled. This is best used with simple GFF files with no hierarchies 
present. This may be used in a while loop until the end of the file 
is reached. Pragmas are ignored and comment lines and sequence are 
automatically skipped. 

=item next_top_feature()

This method will return a top level parent SeqFeature object 
assembled with child features as sub-features. For example, a gene 
object with mRNA subfeatures, which in turn may have exon and/or CDS 
subfeatures. Child features are assembled based on the existence of 
proper Parent attributes in child features. If no Parent attributes are 
included in the GFF file, then this will behave as next_feature().

Child features (those containing a Parent attribute) 
are associated with the parent feature. A warning will be issued about lost 
children (orphans). Shared subfeatures, for example exons common to 
multiple transcripts, are associated properly with each parent. An opportunity 
to rescue orphans is available using the orphans() method.

Note that subfeatures may not necessarily be in ascending genomic order 
when associated with the feature, depending on their order in the GFF3 
file and whether shared subfeatures are present or not. When calling 
subfeatures in your program, you may want to sort the subfeatures. For 
example
  
  my @subfeatures = map { $_->[0] }
                    sort { $a->[1] <=> $b->[1] }
                    map { [$_, $_->start] }
                    $parent->get_SeqFeatures;

=item top_features()

This method will return an array of the top (parent) features defined in 
the GFF file. This is similar to the next_top_feature() method except that 
all features are returned at once. 

=back

=head2 Other methods

Additional methods for working with the parser object and the parsed 
SeqFeature objects.

=over 4

=item parse_file

Parses the file into memory.  

=item find_gene

Pass a gene name, or an array of key = values (name, display_name, 
ID, primary_ID, and/or coordinate information), that can be used 
to find a gene already loaded into memory. Only really successful if the 
entire file is loaded into memory. Genes with a matching name are 
confirmed by a matching ID or overlapping coordinates, if available. 
Otherwise the first match is returned.

=item orphans

This method will return an array of orphan SeqFeature objects that indicated 
they had a parent but said parent could not be found. Typically, this is an 
indication of an incomplete or malformed GFF3 file. Nevertheless, it might 
be a good idea to check this after retrieving all top features.

=item comments

This method will return an array of the comment or pragma lines that may have 
been in the parsed file. These may or may not be useful.

=item from_gff_string($string)

This method will parse a GFF, GTF, or GFF3 formatted string or line of text 
and return a SeqFeature object.

=item unescape($text)

This method will unescape special characters in a text string. Certain 
characters, including ";" and "=", are reserved for GFF3 formatting and 
are not allowed, thus requiring them to be escaped.

=item seq_ids

Returns an array or array reference of the names of the chromosomes or 
reference sequences present in the file. These may be defined by GFF3 
sequence-region pragmas or inferred from the features.

=item seq_id_lengths

Returns a hash reference to the chromosomes or reference sequences and 
their corresponding lengths. In this case, the length is either defined 
by the sequence-region pragma or inferred by the greatest end position of 
the top features.

=back

=cut

use strict;
use Carp qw(carp cluck croak);
use Bio::ToolBox::Data::file; # only for opening file handles
our $SFCLASS = 'Bio::ToolBox::SeqFeature'; # alternative to Bio::SeqFeature::Lite
eval "require $SFCLASS" or croak $@;

our $GTF_simple_ids = qr/gene_id|transcript_id|gene_name|transcript_name|gene_source|transcript_biotype/;
our $GFF3_simple_ids = qr/ID|Name|Parent/;

1;

sub new {
	my $class = shift;
	my $self = {
		'fh'            => undef,
		'top_features'  => [],
		'orphans'       => [],
		'duplicate_ids' => {},
		'skip_types'    => {},
		'gene2seqf'     => {},
		'eof'           => 0,
		'version'       => undef,
		'comments'      => [],
		'seq_ids'       => {},
		'simplify'      => 0,
	};
	bless $self, $class;
	
	# check for options
	if (@_) {
		if (scalar @_ == 1) {
			$self->open_file($_[0]);
		}
		else {
			my %options = @_;
			if (exists $options{skip}) {
				my @s = @{ $options{skip} };
				$self->skip(@s);
			}
			if (exists $options{simplify}) {
				$self->simplify( $options{simplify} );
			}
			if (exists $options{version}) {
				$self->version($options{version});
			}
			if (exists $options{file} or $options{table}) {
				$options{file} ||= $options{table};
				$self->open_file( $options{file} );
			}
			if (exists $options{class}) {
				my $class = $options{class};
				if (eval "require $class; 1") {
					$SFCLASS = $class;
				}
				else {
					croak $@;
				}
			}
		}
	}
	
	# done
	return $self;
}

sub skip {
	my $self = shift;
	foreach (@_) {
		$self->{skip_types}->{$_} = undef;
	}
	my @skips = keys %{ $self->{skip_types} };
	return wantarray ? @skips : \@skips;
}

sub simplify {
	my $self = shift;
	if (defined $_[0]) {
		$self->{simplify} = shift;
	}
	return $self->{simplify};
}

sub version {
	my $self = shift;
	my $v = shift;
	if (defined $v and $v =~ /^(?:1|2|2\.5|3)$/) {
		if (defined $self->{version} and $self->{version} ne $v) {
			warn sprintf(" GFF version information (extension, pragma, etc) mismatch! compare %s with %s! using %s\n", 
				$self->{version}, $v, $v);
		}
		$self->{version} = $v;
	}
	return $self->{version};
}

sub open_file {
	my $self = shift;
	
	# check file
	my $filename = shift;
	unless ($filename) {
		cluck("no file name passed!\n");
		return;
	}
	
	# check extension
	if ($filename =~ /\.gtf(?:\.gz)?$/i) {
		$self->version(2.5);
	}
	elsif ($filename =~ /\.gff3(?:\.gz)?$/i) {
		$self->version(3);
	}
	elsif ($filename =~ /\.gff(?:\.gz)?$/i) {
		# could be anything
		# do not set in preference of gff pragma
	}
	else {
		carp("file doesn't look like a GFF file!\n");
		return;
	}
	
	
	# Open filehandle object 
	my $fh = Bio::ToolBox::Data::file->open_to_read_fh($filename) or
		croak " cannot open file '$filename'!\n";
	
	# check gff version pragma
	my $first = $fh->getline;
	if ($first =~ /^##gff\-version\s+(\d\.?\d?)\s*$/i) {
		# override any version that may have been inferred from the extension
		# based on the assumption that this pragma is correct
		$self->version($1);
	}
	else {
		# no pragma, reopen the file
		$fh->close;
		$fh = Bio::ToolBox::Data::file->open_to_read_fh($filename);
	}
	$self->fh($fh);
	return 1;
}

sub fh {
	my $self = shift;
	if (@_) {
		$self->{'fh'} = shift;
	}
	return $self->{'fh'};
}

sub next_feature {
	my $self = shift;
	
	# check that we have an open filehandle
	unless ($self->fh) {
		croak("no GFF file loaded to parse!");
	}
	return if $self->{'eof'};
	
	# look for the next feature line
	while (my $line = $self->fh->getline) {
		
		chomp $line;
		
		# skip any comment and pragma lines that we might encounter
		if ($line =~ /^##gff\-version\s+(\d\.?\d?)\s*$/i) {
			# override any version that may have been inferred from the extension
			# based on the assumption that this pragma is correct
			$self->version($1);
			next;
		}
		elsif ($line =~ /^###$/) {
			# GFF3 subfeature close directive, we no longer pay attention to 
			# these, although we should.....
			next;
		}
		elsif ($line =~ /^##sequence\-region/i) {
			# sequence region pragma
			my ($pragma, $seq_id, $start, $stop) = split /\s+/, $line;
			if (defined $seq_id and $start =~ /^\d+$/ and $stop =~ /^\d+$/) {
				# we're actually only concerned with the stop coordinate
				$self->{seq_ids}{$seq_id} = $stop;
			}
			else {
				warn "malformed sequence-region pragma! $line\n";
			}
			next;
		}
		elsif ($line =~ /^#/) {
			# either a pragma or a comment line, may be useful
			push @{$self->{comments}}, $line;
			next;
		}
		elsif ($line =~ /^$/) {
			# an empty line
			next;
		}
		elsif ($line =~ /^>/) {
			# fasta header line, skip
			next;
		}
		elsif ($line =~ /^[agctn]+$/i) {
			# fasta sequence, skip
			next;
		}
		
		# line must be a GFF feature
		# generate the SeqFeature object for this GFF line and return it
		my $feature = $self->from_gff_string($line);
		next unless $feature;
		next if $feature eq 'skipped';
		return $feature;
	}
	
	# presumably reached the end of the file
	$self->{'eof'} = 1;
	return;
}

sub next_top_feature {
	my $self = shift;
	# check that we have an open filehandle
	unless ($self->fh) {
		croak("no GFF3 file loaded to parse!");
	}
	unless ($self->{'eof'}) {
		$self->parse_file;
	}
	return shift @{ $self->{top_features} };
}

sub top_features {
	my $self = shift;
	unless ($self->{'eof'}) {
		$self->parse_file;
	}
	my @features = @{ $self->{top_features} };
	return wantarray ? @features : \@features;
}

*parse_table = \&parse_file;

sub parse_file {
	my $self = shift;
	# check that we have an open filehandle
	unless ($self->fh) {
		croak("no file loaded to parse!");
	}
	return 1 if $self->{'eof'};
	
	# Each line will be processed into a SeqFeature object, and then checked 
	# for parentage. Child objects with a Parent tag will be appropriately 
	# associated with its parent, or put into an orphanage. Any orphans 
	# left will be checked a final time for parents; if a parent can't be 
	# found, it will be lost. Features without a parent are assumed to be 
	# top-level features.
	
	# a loaded hash to check for unique feature IDs and to find parents
	my %loaded;
	
	printf "  Parsing %s format file....\n", 
		$self->version eq '3' ? 'GFF3' : 
		$self->version eq '2.5' ? 'GTF' : 'GFF';
	TOP_FEATURE_LOOP:
	while (my $feature = $self->next_feature) {
		
		### Process the feature
		# check the ID
		my $id = $feature->primary_id;
		if ($id) {
			# this ID should be unique in the GFF file
			# and all parents must have IDs
			# complain if it isn't
			if (exists $loaded{$id}) {
				# record how many times we've seen this
				$self->{duplicate_ids}{$id}++ unless 
					$feature->primary_tag eq 'CDS'; # Ensembl CDS recycle IDs
				
				# check to see if this is child feature
				unless ($feature->has_tag('Parent')) {
					# without a parent, this must be an orphan, or a malformed GFF3 file
					# anyway, keep this as an orphan
					$self->_add_orphan($feature);
					next TOP_FEATURE_LOOP;
				}
			} 
			else {
				$loaded{$id} = $feature;
			}
		}
		# if the feature didn't have an ID, we'll just assume it is
		# a child of another feature, otherwise it may get lost
		
		# look for parents and children
		if ($feature->has_tag('Parent')) {
			# must be a child
			# there may be more than one parent, per the GFF3 specification
			foreach my $parent ( $feature->get_tag_values('Parent') ) {
				if (exists $loaded{$parent}) {
					# we've seen this id
					# associate the child with the parent
					$loaded{$parent}->add_SeqFeature($feature);
					
					# check boundaries - especially important for gtf when gene may 
					# not be defined. won't hurt otherwise.
					if ($feature->start < $loaded{$parent}->start) {
						$loaded{$parent}->start( $feature->start );
					}
					if ($feature->end > $loaded{$parent}->end) {
						$loaded{$parent}->end( $feature->end );
					}
				}
				elsif ($self->version == 2.5) {
					# gene parents likely not specified in the file, so must infer
					
					if ($feature->primary_tag =~ /gene/i) {
						# I assume we're good here
					}
					elsif ($feature->primary_tag =~ /rna|transcript/i) {
						# we need to make the gene parent
						my $gene = $self->_make_gene_parent($feature);
						$loaded{ $gene->primary_id } = $gene;
						$gene->add_SeqFeature($feature);
						push @{ $self->{top_features} }, $gene;
					}
					else {
						# we need to make both the gene and transcript parents
						my $gene = $self->_make_gene_parent($feature);
						$loaded{ $gene->primary_id } = $gene;
						push @{ $self->{top_features} }, $gene;
						my $transcript = $self->_make_rna_parent($feature);
						$loaded{ $transcript->primary_id } = $transcript;
						$transcript->add_SeqFeature($feature);
						$gene->add_SeqFeature($transcript);
					}
				}
				else {
					# can't find the parent, maybe not loaded yet?
					# put 'em in the orphanage
					$self->_add_orphan($feature);
				}
			}
		}
		else {
			# must be a parent
			push @{ $self->{top_features} }, $feature;
		}
	}
	# Finished loading the GFF lines
	
	# check for orphans
	if (scalar @{ $self->{orphans} }) {
		
		my @reunited; # list of indices to delete after reuniting orphan with parent
		
		# go through the list of orphans
		for (my $i = 0; $i < scalar @{ $self->{orphans} }; $i++) {
			my $orphan = $self->{orphans}->[$i];
			my $success = 0;
			
			# find the parent
			foreach my $parent ($orphan->get_tag_values('Parent') ) {
				if (exists $loaded{$parent}) {
					# we have loaded the parent
					# associate each orphan feature with the parent
					$loaded{$parent}->add_SeqFeature($orphan);
					$success++;
				}
			}
			# delete the orphan from the array if it found it's long lost parent
			push @reunited, $i if $success;
		}
		
		# clean up the orphanage
		while (@reunited) {
			my $i = pop @reunited;
			splice(@{ $self->{orphans} }, $i, 1);
		}
		
		# report
		if (scalar @{ $self->{orphans} }) {
			carp " " . scalar @{ $self->{orphans} } . " features could not be " . 
				"associated with reported parents!\n";
		}
	}
	
	# report on duplicate IDs
	if (keys %{ $self->{duplicate_ids} }) {
		print " The GFF file has errors: the following IDs were duplicated: " . 
			join(', ', keys %{ $self->{duplicate_ids} }) . "\n";
	}
	
	# build gene2seqf and seq_id hashes 
	foreach (@{ $self->{top_features} }) {
		my $name = lc $_->display_name;
		if (exists $self->{gene2seqf}->{$name}) {
			push @{ $self->{gene2seqf}->{$name} }, $_;
		}
		else {
			$self->{gene2seqf}->{$name} = [$_];
		}
		my $s = $_->seq_id;
		unless (exists $self->{seq_ids}{$s}) {
			$self->{seq_ids}{$s} = 1;
		}
		$self->{seq_ids}{$s} = $_->end if $_->end > $self->{seq_ids}{$s};
	}
	
	return 1;
}


sub _make_gene_parent {
	# for generating GTF gene parent features
	my ($self, $feature) = @_;
	my $gene = $SFCLASS->new(
		-seq_id         => $feature->seq_id,
		-start          => $feature->start,
		-end            => $feature->end,
		-strand         => $feature->strand,
		-source         => $feature->source,
		-primary_tag    => 'gene',
	);
	
	if ($feature->has_tag('gene_id')) {
		$gene->primary_id(($feature->get_tag_values('gene_id')));
	}
	elsif ($feature->has_tag('gene_name')) {
		$gene->primary_id(($feature->get_tag_values('gene_name')));
	}
	else {
		$gene->primary_id(($feature->get_tag_values('Parent')));
	}
	
	if ($feature->has_tag('gene_name')) {
		$gene->display_name(($feature->get_tag_values('gene_name')));
	}
	elsif ($feature->has_tag('gene_id')) {
		$gene->display_name(($feature->get_tag_values('gene_id')));
	}
	else {
		$gene->display_name(($feature->get_tag_values('Parent')));
	}
	return $gene;
}


sub _make_rna_parent {
	# for generating GTF transcript parent features
	my ($self, $feature) = @_;
	my $rna = $SFCLASS->new(
		-seq_id         => $feature->seq_id,
		-start          => $feature->start,
		-end            => $feature->end,
		-strand         => $feature->strand,
		-source         => $feature->source,
		-primary_tag    => 'transcript', # probably mRNA, but since we don't know
	);
	if ($feature->has_tag('transcript_id')) {
		$rna->primary_id(($feature->get_tag_values('transcript_id')));
	}
	elsif ($feature->has_tag('transcript_name')) {
		$rna->primary_id(($feature->get_tag_values('transcript_name')));
	}
	else {
		$rna->display_id(($feature->get_tag_values('Parent')));
	}
	
	if ($feature->has_tag('transcript_name')) {
		$rna->display_name(($feature->get_tag_values('transcript_name')));
	}
	elsif ($feature->has_tag('transcript_id')) {
		$rna->display_name(($feature->get_tag_values('transcript_id')));
	}
	else {
		$rna->display_name(($feature->get_tag_values('Parent')));
	}
	return $rna;
}


sub find_gene {
	my $self = shift;
	
	# get the name and coordinates from arguments
	my ($name, $id, $chrom, $start, $end, $strand);
	if (scalar @_ == 0) {
		carp "must provide information to find_gene method!";
		return;
	}
	elsif (scalar @_ == 1) {
		$name = $_[0];
	}
	else {
		my %opt = @_;
		$name  = $opt{name} || $opt{display_name} || undef;
		$id    = $opt{id} || $opt{primary_id} || undef;
		$chrom = $opt{chrom} || $opt{seq_id} || undef;
		$start = $opt{start} || undef;
		$end   = $opt{stop} || $opt{end} || undef;
		$strand = $opt{strand} || 0;
	}
	unless ($name) {
		carp "name is required for find_gene!";
		return;
	}
	
	# check if a gene with this name exists
	if (exists $self->{gene2seqf}->{lc $name} ) {
		# we found a matching gene
		
		# pull out the gene seqfeature(s) array reference
		# there may be more than one gene
		my $genes = $self->{gene2seqf}->{ lc $name };
		
		# go through a series of checks to find the appropriate 
		if ($id) {
			foreach my $g (@$genes) {
				if ($g->primary_id eq $id) {
					return $g;
				}
			}
			return; # none of these matched despite having an ID
		}
		if ($chrom and $start and $end) {
			foreach my $g (@$genes) {
				if ( 
					# overlap method borrowed from Bio::RangeI
					($g->strand == $strand) and not (
						$g->start > $end or 
						$g->end < $start
					)
				) {
					# gene and transcript overlap on the same strand
					# we found the intersecting gene
					return $g;
				}
			}
			return; # none of these matched despite having coordinate info
		}
		if (scalar @$genes == 1) {
			# going on trust here that this is the one
			return $genes->[0];
		}
		elsif (scalar @$genes > 1) {
			carp "more than one gene named $name found!";
			return $genes->[0];
		}
		
		# nothing suitable found
		return;
	}
}


sub from_gff_string {
	my ($self, $string) = @_;
	
	# check string
	chomp $string;
	unless ($string) {
		cluck("must pass a string!\n");
		return;
	}
	my @fields = split('\t', $string);
	if (scalar @fields != 9) {
		warn "line does not have 9 columns!";
		return;
	}
	
	# check the primary_tag
	if (exists $self->{skip_types}{$fields[2]}) {
		return 'skipped';
	}
	
	# parse appropriately
	if ($self->version eq '3') {
		return $self->_gff3_to_seqf(@fields);
	}
	elsif ($self->version eq '2.5') {
		return $self->_gtf_to_seqf(@fields);
	}
	else {
		# generic gff1 or gff2 format or poorly defined gff3 or gtf file
		# hope for the best!
		my $feature = $self->_gff_to_seqf(@fields);
		
		# process groups
		# we have no uniform method of combining features, so we'll leave the tags 
		# as is and hope for the best
		foreach my $g (split(/\s*;\s*/, $fields[8])) {
			my ($tag, $value) = split /\s+/, $g;
			next unless ($tag and $value);
			$feature->add_tag_value($tag, $value);
		}
		return $feature;
	}
}


sub _gff3_to_seqf {
	my $self = shift;
	my $group = $_[8];
	my $feature = $self->_gff_to_seqf(@_);
	
	# process groups
	foreach my $g (split(/\s*;\s*/, $group)) {
		my ($tag, $value) = split /=/, $g;
		$tag = $self->unescape($tag);
		next if ($self->{simplify} and not $tag =~ $GFF3_simple_ids);
		my @values = map { $self->unescape($_) } split(/,/, $value);
		
		# determine the appropriate attribute based on tag name
		if ($tag eq 'Name') {
			$feature->display_name($values[0]);
		}
		elsif ($tag eq 'ID') {
			$feature->primary_id($values[0]);
		}
		else {
			foreach (@values) {
				$feature->add_tag_value($tag, $_);
			}
		}
	}
	
	return $feature;
}


sub _gtf_to_seqf {
	my $self = shift;
	my $group = $_[8];
	my $feature = $self->_gff_to_seqf(@_);
	
	# process groups
	my %attributes;
	my ($transcript_id, $transcript_name, $gene_id, $gene_name);
	foreach my $g (split('; ', $group)) { # supposed to be "; " as delimiter
		my ($tag, $value, @bits) = split ' ', $g;
		next if ($self->{simplify} and not $tag =~ $GTF_simple_ids);
		if (@bits) {
			# value had spaces in it!
			foreach (@bits) {$value .= " $_"}
		}
		$value =~ s/[";]//g; # remove the flanking double quotes, assume no internal quotes
		if ($tag eq 'transcript_id') {
			$transcript_id = $value;
		}
		elsif ($tag eq 'transcript_name') {
			$transcript_name = $value;
		}
		elsif ($tag eq 'gene_id') {
			$gene_id = $value;
		}
		elsif ($tag eq 'gene_name') {
			$gene_name = $value;
		}
		else {
			$attributes{$tag} = $value;
		}
	}
	
	## Change some Ensembl tags
	# sometimes Ensembl GTFs use the source tag as the biotype, instead of a the real source
	my $original_source = $feature->source; # keep this for later
	if (exists $attributes{'gene_source'}) {
		$feature->source($attributes{'gene_source'});
		delete $attributes{'gene_source'} if $self->{simplify};
	}
	
	# convert some tags into GFF3-like conventions
	if ($feature->primary_tag =~ /gene/i) {
		$feature->primary_id($gene_id);
		$feature->display_name($gene_name);
	}
	elsif ($feature->primary_tag =~ /transcript|rna/i) {
		$feature->primary_id($transcript_id);
		$feature->display_name($transcript_name);
		$feature->add_tag_value('Parent', $gene_id) if $gene_id;
		
		# update primary_tag to follow BioPerl/BioToolBox/GFF3/traditional conventions
		# primarily to handle some Ensembl GTF file formats
		if ($feature->primary_tag =~ /^transcript$/i) {
			# generic transcript type, see if we can make it more specific
			if (exists $attributes{'transcript_biotype'}) {
				if ($attributes{'transcript_biotype'} =~ /protein_coding/i) {
					$feature->primary_tag('mRNA');
				}
				elsif ($attributes{'transcript_biotype'} =~ /rna/i) {
					# looks like an rna type
					$feature->primary_tag($attributes{'transcript_biotype'});
				}
				delete $attributes{'transcript_biotype'} if $self->{simplify};
			}
			elsif (exists $attributes{'gene_biotype'}) {
				if ($attributes{'gene_biotype'} =~ /protein_coding/i) {
					$feature->primary_tag('mRNA');
				}
				elsif ($attributes{'gene_biotype'} =~ /rna/i) {
					# looks like an rna type
					$feature->primary_tag($attributes{'gene_biotype'});
				}
				delete $attributes{'gene_biotype'} if $self->{simplify};
			}
			elsif ($original_source =~ /protein_coding/i) {
				$feature->primary_tag('mRNA');
			}
			elsif ($original_source =~ /rna|antisense|transcript|nonsense_mediated/i) {
				$feature->primary_tag($original_source);
			}
		}
	}
	else {
		# other features are assumed to be transcript children
		# not required to set a primary_id
		if ($transcript_id) {
			$feature->add_tag_value('Parent', $transcript_id);
		}	
	}
	
	# add remaining attributes to the feature
	foreach my $key (keys %attributes) {
		$feature->add_tag_value($key, $attributes{$key});
	}
	
	return $feature;
}


sub _gff_to_seqf {
	my $self = shift;
	
	# generate the basic SeqFeature
	my $feature = $SFCLASS->new(
		-seq_id         => $_[0],
		-start          => $_[3],
		-end            => $_[4],
	);
	
	# add more attributes
	if ($_[2] ne '.') {
		$feature->primary_tag($_[2]);
	}
	if ($_[1] ne '.') {
		$feature->source($_[1]);
	}
	if ($_[5] ne '.') {
		$feature->score($_[5]);
	}
	if ($_[7] =~ /^[012]$/) {
		$feature->phase($_[7]);
	}
	
	# add strand
	if ($_[6] eq '+') {
		$feature->strand(1);
	}
	elsif ($_[6] eq '-') {
		$feature->strand(-1);
	}
	else {
		$feature->strand(0);
	}
	
	# finished
	return $feature;
}


sub unescape {
  # Borrowed unashamedly from bioperl Bio::Tools::GFF
  # which in turn was borrowed from Bio::DB::GFF
  
  my $self = shift;
  
  my $v = shift;
  $v =~ tr/+/ /;
  $v =~ s/%([0-9a-fA-F]{2})/chr hex($1)/ge;
  return $v;
}


sub _add_orphan {
	my ($self, $feature) = @_;
	push @{ $self->{orphans} }, $feature;
	return 1;
}


sub orphans {
	my $self = shift;
	my @orphans;
	foreach (@{ $self->{orphans} }) {
		push @orphans, $_;
	}
	return wantarray ? @orphans : \@orphans;
}


sub comments {
	my $self = shift;
	my @comments;
	foreach (@{ $self->{comments} }) {
		push @comments, $_;
	}
	return wantarray ? @comments : \@comments;
}


sub seq_ids {
	my $self = shift;
	my @s = keys %{$self->{seq_ids}};
	return wantarray ? @s : \@s;
}


sub seq_id_lengths {
	my $self = shift;
	return $self->{seq_ids};
}

__END__

=head1 AUTHOR

 Timothy J. Parnell, PhD
 Dept of Oncological Sciences
 Huntsman Cancer Institute
 University of Utah
 Salt Lake City, UT, 84112

This package is free software; you can redistribute it and/or modify
it under the terms of the Artistic License 2.0.  

