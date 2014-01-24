=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Production::GeneCount;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Production::StatsGenerator/;


sub get_attrib_codes {
  my ($self) = @_;
  my @attrib_codes = ('coding_cnt', 'pseudogene_cnt', 'snoncoding_cnt', 'lnoncoding_cnt');
  my %biotypes;
  foreach my $code (@attrib_codes) {
    my ($group) = $code =~ /(\w+)\_cnt/;
    my $biotypes = $self->get_biotype_group($group);
    $biotypes{$code} = $biotypes;
  }
  return %biotypes;
}

sub get_alt_attrib_codes {
  my ($self) = @_;
  my @alt_attrib_codes = ('coding_acnt', 'pseudogene_acnt', 'snoncoding_acnt', 'lnoncoding_acnt');
  my %biotypes;
  foreach my $alt_code (@alt_attrib_codes) {
    my ($group) = $alt_code =~ /(\w+)\_acnt/;
    my $biotypes = $self->get_biotype_group($group);
    $biotypes{$alt_code} = $biotypes;
  }
  return %biotypes;
}

sub get_total {
  my ($self) = @_;
  my $species = $self->param('species');
  my $total = scalar(@{ Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'gene')->fetch_all });
  return $total;
}

sub get_ref_length {
  my ($self) = @_;
  my $species = $self->param('species');
  my @slices = @{ Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice')->fetch_all('toplevel') };
  my $ref_length = 0;
  foreach my $slice (@slices) {
    $ref_length += $slice->length();
  }
  return $ref_length;
}

sub get_total_length {
  my ($self) = @_;
  my $species = $self->param('species');
  my @slices = @{ Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice')->fetch_all('seqlevel') };
  my $total_length = 0;
  foreach my $slice (@slices) {
    $total_length += $slice->length();
  }
  return $total_length;
}

sub get_slices {
  my ($self, $species) = @_;
  my @slices;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $sa = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice');
  my $helper = $dba->dbc()->sql_helper();
  my $sql = q{
    SELECT DISTINCT seq_region_id FROM gene 
join seq_region using (seq_region_id)
join coord_system cs using (coord_system_id)
    WHERE cs.species_id=? AND seq_region_id NOT IN 
    (SELECT seq_region_id 
    FROM seq_region_attrib sa, attrib_type at
    WHERE at.attrib_type_id = sa.attrib_type_id
    AND at.code= "non_ref") };
  my @ids = @{ $helper->execute_simple(-SQL => $sql, -PARAMS=>[$dba->species_id()]) };
  foreach my $id(@ids) {
    push @slices, $sa->fetch_by_seq_region_id($id);
  }
  return \@slices;
}

sub get_all_slices {
  my ($self, $species) = @_;
  my @slices;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $sa = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice');
  my $helper = $dba->dbc()->sql_helper();
  my $sql = q{
    SELECT DISTINCT seq_region_id FROM gene join seq_region using (seq_region_id) join coord_system using (coord_system_id) where species_id=? };
  my @ids = @{ $helper->execute_simple(-SQL => $sql, -PARAMS=>[$dba->species_id()]) };
  foreach my $id(@ids) {
    push @slices, $sa->fetch_by_seq_region_id($id);
  }
  return \@slices;
}


sub get_feature_count {
  my ($self, $slice, $key, $biotypes) = @_;
  my $species = $self->param('species');
  my $ga = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'gene');
  return $ga->count_all_by_Slice($slice, $biotypes);
}


1;

