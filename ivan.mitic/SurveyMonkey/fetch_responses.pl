use File::Basename;

use SurveyMonkey::ETL;

use constant SM_SURVEY_ID => '72923841'; #72923841, 72986931
use constant FETCH_DATETIME_PATH => dirname($0) . '/last_fetch_timestamp';

my $bx_datetime_formatter = DateTime::Format::Strptime->new(
  pattern => '%Y-%m-%d %H:%M:%S',
  on_error => 'croak',
);

sub _get_last_fetch_datetime {
  return undef unless (-f FETCH_DATETIME_PATH);
  
  local $/ = undef;
  open FILE, FETCH_DATETIME_PATH or die "Couldn't open file: '" . FETCH_DATETIME_PATH . "' $!";
  binmode FILE;
  my $string = <FILE>;
  close FILE;
  
  $bx_datetime_formatter->parse_datetime($string);
  
  return $string;
}

sub _save_last_fetch_datetime {
  my ($datetime_string) = @_;
  
  open(my $fh, '>', FETCH_DATETIME_PATH) or die "Could not open file '" . FETCH_DATETIME_PATH . "' $!";
  print $fh $datetime_string;
  close $fh;
}

my $interval_start = _get_last_fetch_datetime;

my $interval_end_object = DateTime->now;
$interval_end_object->set_formatter($bx_datetime_formatter);
my $interval_end = "$interval_end_object";


my $sm_etl = new SurveyMonkey::ETL(SM_SURVEY_ID, $bx_datetime_formatter);

my $new_responses = $sm_etl->extract_between_timestamps($interval_start, $interval_end);

use Data::Dumper;
print Dumper $new_responses;

_save_last_fetch_datetime($interval_end);


1;