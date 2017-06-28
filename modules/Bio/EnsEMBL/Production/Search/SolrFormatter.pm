
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Production::Search::SolrFormatter;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use Bio::EnsEMBL::Production::Search::JSONReformatter;

use JSON;
use Carp;
use File::Slurp;

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );
	$self->{log} = get_logger();
	return $self;
}

sub log {
	my ($self) = @_;
	return $self->{log};
}

sub reformat_genes {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($gene)          = @_;
			my $transcripts     = [];
			my $transcripts_ver = [];
			my $peptides        = [];
			my $peptides_ver    = [];
			my $exons           = {};
			my $xrefs           = {};
			my $hr              = [];
			_add_xrefs( $gene, 'Gene', $xrefs, $hr );

			for my $transcript ( @{ $gene->{transcripts} } ) {
				_add_xrefs( $transcript, 'Transcript', $xrefs, $hr );
				push @$transcripts,     $transcript->{id};
				push @$transcripts_ver, _id_ver($transcript);
				if ( defined $transcript->{translations} ) {
					for my $translation ( @{ $transcript->{translations} } ) {
						_add_xrefs( $translation, 'Translation', $xrefs, $hr );
						push @$peptides,     $translation->{id};
						push @$peptides_ver, _id_ver($translation);
					}
				}
				for my $exon ( @{ $transcript->{exons} } ) {
					$exons->{ $exon->{id} }++;
				}
			}

			return { %{ _base( $genome, $type, 'Gene' ) },
					 id                => $gene->{id},
					 id_ver            => _id_ver($gene),
					 name              => $gene->{name},
					 description       => $gene->{description},
					 _hr               => $hr,
					 xrefs             => join( ' ', keys %$xrefs ),
					 name_synonym      => $gene->{synonyms} || [],
					 transcript_count  => scalar(@$transcripts),
					 transcript        => $transcripts,
					 transcript_ver    => $transcripts_ver,
					 translation_count => scalar(@$peptides),
					 peptide           => $peptides,
					 peptide_ver       => $peptides_ver,
					 exon_count        => scalar( keys %$exons ),
					 exon              => [ keys %$exons ],
					 location          => sprintf( "%s:%d-%d:%d",
									   $gene->{seq_region_name}, $gene->{start},
									   $gene->{end}, $gene->{strand} ),
					 source => $gene->{analysis},
					 domain_url =>
					   sprintf( "%s/Gene/Summary?g=%s&amp;db=%s",
								$genome->{organism}->{name},
								$gene->{id}, $type ) };
		} );
	return;
} ## end sub reformat_genes

sub reformat_transcripts {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;
	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($gene) = @_;
			my $transcripts = [];
			for my $transcript ( @{ $gene->{transcripts} } ) {

				my $peptides     = [];
				my $peptides_ver = [];
				my $exons        = {};
				my $xrefs        = {};
				my $hr           = [];
				my $pfs          = [];

				_add_xrefs( $transcript, 'Transcript', $xrefs, $hr );
				if ( defined $transcript->{translations} ) {

					for my $translation ( @{ $transcript->{translations} } ) {
						_add_xrefs( $translation, 'Translation', $xrefs, $hr );
						push @$peptides,     $translation->{id};
						push @$peptides_ver, _id_ver($translation);
						my $interpro = {};
						for my $pf ( @{ $translation->{protein_features} } ) {
							push @$pfs, $pf->{name};
							if ( defined $pf->{interpro_ac} ) {
								push @{ $interpro->{ $pf->{interpro_ac} } },
								  $pf->{name};
							}
						}
						while ( my ( $ac, $ids ) = each %$interpro ) {
							push @$hr,
							  sprintf(
"Interpro domain %s with %d records from signature databases (%s) is found on Translation %s",
								$ac, scalar(@$ids), join( ', ', @$ids ),
								$translation->{id} );
							push @$pfs, $ac;
						}

					}
				} ## end if ( defined $transcript...)
				for my $exon ( @{ $transcript->{exons} } ) {
					$exons->{ $exon->{id} }++;
				}
				if ( defined $transcript->{supporting_evidence} ) {
					for my $evidence ( @{ $transcript->{supporting_evidence} } )
					{
						push @$hr,
						  sprintf(
"%s (%s) is used as supporting evidence for transcript %s",
							$evidence->{id}, $evidence->{db_display_name},
							$transcript->{id} );
					}
				}

				push @$transcripts, {
					%{ _base( $genome, $type, 'Transcript' ) },
					id                => $transcript->{id},
					id_ver            => _id_ver($transcript),
					name              => $transcript->{name},
					description       => $transcript->{description},
					_hr               => $hr,
					xrefs             => join( ' ', keys %$xrefs ),
					name_synonym      => $transcript->{synonyms} || [],
					translation_count => scalar(@$peptides),
					peptide           => $peptides,
					peptide_ver       => $peptides_ver,
					prot_domain       => $pfs,
					exon_count        => scalar( keys %$exons ),
					exon              => [ keys %$exons ],
					location          => sprintf( "%s:%d-%d:%d",
						   $transcript->{seq_region_name}, $transcript->{start},
						   $transcript->{end}, $transcript->{strand} ),
					source => $gene->{analysis},
					domain_url =>
					  sprintf( "%s/Transcript/Summary?g=%s&amp;db=%s",
							   $genome->{organism}->{name}, $transcript->{id},
							   $type ) };

			} ## end for my $transcript ( @{...})
			return $transcripts;
		} );
	return;
} ## end sub reformat_transcripts

sub reformat_ids {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;

	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($id) = @_;

			my $desc = sprintf( "Ensembl %s %s is no longer in the database",
								ucfirst( $id->{type} ), $id->{id} );
			my $deprecated_id_c =
			  _array_nonempty( $id->{deprecated_mappings} ) ?
			  scalar( @{ $id->{deprecated_mappings} } ) :
			  0;
			my $current_id_c =
			  _array_nonempty( $id->{current_mappings} ) ?
			  scalar( @{ $id->{current_mappings} } ) :
			  0;

			my $dep_txt  = '';
			my $curr_txt = '';
			if ( $deprecated_id_c > 0 ) {
				$dep_txt =
				  $deprecated_id_c > 1 ?
				  "$deprecated_id_c deprecated identifiers" :
				  "$deprecated_id_c deprecated identifier";
			}
			if ( $current_id_c > 0 ) {
				my $example_id = $id->{current_mappings}->[0];
				$curr_txt =
				  $current_id_c > 1 ? "$current_id_c current identifiers" :
				                      "$current_id_c current identifier";
				$curr_txt .= $example_id ? " (e.g. $example_id)" : '';
			}
			if ( $current_id_c > 0 && $deprecated_id_c > 0 ) {
				$desc .= " and has been mapped to $curr_txt and $dep_txt";
			}
			elsif ( $current_id_c > 0 && $deprecated_id_c == 0 ) {
				$desc .= " and has been mapped to $curr_txt";
			}
			elsif ( $current_id_c == 0 && $deprecated_id_c > 0 ) {
				$desc .= " and has been mapped to $dep_txt";
			}
			else {
				$desc .= ' and has not been mapped to any newer identifiers.';
			}
			return { %{ _base( $genome, $type, ucfirst( $id->{type} ) ) },
					 id          => $id->{id},
					 description => $desc,
					 domain_url =>
					   sprintf( "%s/%s/?g=%s&amp;db=%s",
								$genome->{organism}->{name},
								ucfirst( $id->{type} ),
								$id->{id},
								$type ) };
		} );

	return;
} ## end sub reformat_ids

sub reformat_gene_families {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub reformat_sequences {
	my ( $self, $infile, $outfile, $genome, $type ) = @_;

	$type ||= 'core';
	reformat_json(
		$infile, $outfile,
		sub {
			my ($seq) = @_;
			my $desc = sprintf('%s %s (length %d bp)',ucfirst($seq->{type}),$seq->{id},$seq->{length});
			if(defined $seq->{parent}) {
				$desc = sprintf("%s is mapped to %s %s", $desc, $seq->{parent_type}, $seq->{parent});
			}
			if(_array_nonempty($seq->{synonyms})) {
				$desc .= '. It has synonyms of '.join(', ',@{$seq->{synonyms}}).'.';
			}
			return { %{ _base( $genome, $type, 'Sequence' ) },
					 id          => $seq->{id},
					 description => $desc,
					 domain_url =>
					   sprintf( "%s/Location/View?r=%s:%d-%d&amp;db=%s",
								$genome->{organism}->{name},
								$seq->{id},
								1,
								$seq->{length},
								$type ) };
		} );

	return;
}

sub reformat_markers {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub reformat_variants {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub reformat_phenotypes {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub reformat_regulatory_features {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub reformat_probes {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub reformat_probesets {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub _id_ver {
	my ($o) = @_;
	return $o->{id} . ( defined $o->{version} ? ".$o->{version}" : "" );
}

sub _base {
	my ( $genome, $db_type, $obj_type ) = @_;
	return {
		ref_boost        => _ref_boost($genome),
		db_boost         => _db_boost($db_type),
		website          => _website($genome),
		feature_type     => $obj_type,
		species          => $genome->{organism}{name},
		species_name     => $genome->{organism}{display_name},
		reference_strain => (
			defined $genome->{is_reference} && $genome->{is_reference} eq 'true'
		  ) ? 1 : 0,
		database_type => $db_type };
}

sub _ref_boost {
	my ($genome) = @_;
	return $genome->{is_reference} ? 10 : 1;
}

sub _db_boost {
	my ($type) = @_;
	return $type eq 'core' ? 40 : undef;
}

my $sites = { Ensembl         => "http://www.ensembl.org/",
			  EnsemblBacteria => "http://bacteria.ensembl.org/",
			  EnsemblProtists => "http://protists.ensembl.org/",
			  EnsemblFungi    => "http://fungi.ensembl.org/",
			  EnsemblPlants   => "http://plants.ensembl.org/",
			  EnsemblMetazoa  => "http://metazoa.ensembl.org/", };

sub _website {
	my ($genome) = @_;
	return $sites->{ $genome->{division} };
}

sub _hr {
	my ( $obj, $type, $xref ) = @_;
# <field name="_hr">R-HSA-1643685 (Reactome record; description: Disease&#44;) is an external reference matched to Translation ENSP00000360644</field>
	my $d = $xref->{display_id};
	if ( defined $xref->{description} ) {
		$d .= ' record; description: ' . $xref->{description};
	}
	my $s = sprintf( '%s (%s) is an external reference matched to %s %s',
					 $xref->{display_id}, $d, $type, $obj->{id} );
	if ( defined $xref->{synonyms} && scalar( @{ $xref->{synonyms} } ) > 0 ) {
		$s .= ", with synonym(s) of " . join( ', ', @{ $xref->{synonyms} } );
	}
	return $s;
}

sub _add_xrefs {
# xrefs is a hash to support listing all unique identifiers for a record that can then be emitted as a string
	my ( $obj, $type, $xrefs, $hr ) = @_;
	for my $xref ( @{ $obj->{xrefs} } ) {
		# skip xrefs where the ID is the same as the stable ID or display xref
		next if ( $xref->{primary_id} eq $obj->{id} );
		next if ( defined $obj->{name} && $xref->{display_id} eq $obj->{name} );
		$xrefs->{ $xref->{primary_id} }++;
		$xrefs->{ $xref->{display_id} }++;
		$xrefs->{ $xref->{description} }++ if defined $xref->{description};
		if ( defined $xref->{synonyms} ) {
			for my $syn ( @{ $xref->{synonyms} } ) {
				$xrefs->{$syn}++;
			}
		}
		push @$hr, _hr( $obj, $type, $xref );
	}
	return;
}

sub _array_nonempty {
	my ($ref) = @_;
	return defined $ref && scalar(@$ref) > 0;
}

1;
