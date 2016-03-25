package SurveyMonkey::ETL;

use DateTime::Format::Strptime;

use SurveyMonkey::API;

use constant SM_DOMAIN => 'https://api.surveymonkey.net';
use constant SM_BX_API_KEY => '';
use constant SM_BX_TOKEN => '';

use constant QUESTION_TRANSFORMER_MAP => {
  open_ended => _transform_open_ended,
  single_choice => _transform_single_choice,
  datetime => _transform_datetime,
  matrix => _ok_to_skip,
  multiple_choice => _transform_multiple_choice,
};

my $api = new SurveyMonkey::API(SM_DOMAIN, SM_BX_API_KEY, SM_BX_TOKEN);
my $parser = DateTime::Format::Strptime->new(
  pattern => '%m/%d/%Y',
  on_error => 'croak',
);

my $export_datetime_formatter = undef; 

 sub new {
  my ($class, $survey_id, $wanted_datetime_formatter) = @_;
  
  $export_datetime_formatter = $wanted_datetime_formatter;
  
  return bless ({
    survey_id => $survey_id,
    survey_details => undef,
  }, $class);
}

sub _survey_details {
  my ($self, $timestamp) = @_;
  unless (defined $self->{survey_details}){
    $self->{survey_details} = $api->survey_details($self->{survey_id});
  }
  return $self->{survey_details};
}

sub extract_between_timestamps {
  my ($self, $start, $end) = @_;
  
  my $new_response_ids = $api->response_ids_between_timestamps($self->{survey_id}, $start, $end);
  unless ( @$new_response_ids ){
    return []
  }
  
  my $responses = {};
  
  my $response_details = $api->response_details($self->{survey_id}, $new_response_ids);
  
  foreach my $raw_response (@$response_details) {
    my $response = {};
    
    foreach my $question (@{$raw_response->{questions}}){
      my $question_details = $self->_survey_details->{$question->{question_id}};
      my $transformer = QUESTION_TRANSFORMER_MAP->{$question_details->{type}->{family}};
      die "Question family not supported: $question_details->{type}->{family}" unless (defined $transformer);
      $response->{$question_details->{question_id}} = &$transformer($question, $question_details);
    }
    
    $responses->{$raw_response->{respondent_id}} = $response;
  }
  
  return $responses;
}

sub _transform_open_ended {
  my ($question, $question_details) = @_;
  
  my $answer = _prepare_answer_hashref($question_details);  
  $answer->{answer_text} = $question->{answers}[0]->{text};
     
  return $answer;
}

sub _transform_datetime {
  my ($question, $question_details) = @_;
  
  my $dt_object = $parser->parse_datetime($question->{answers}[0]->{text});
  $dt_object->set_formatter($export_datetime_formatter);
  
  my $answer = _prepare_answer_hashref($question_details);
  $answer->{answer_text} = "$dt_object";
     
  return $answer;
}

sub _transform_single_choice {
  my ($question, $question_details) = @_;
  
  my $answer_id = $question->{answers}[0]->{row};
  my ($anwser_hashref) = grep {$_->{answer_id} eq $answer_id} @{$question_details->{answers}};
  
  my $answer = _prepare_answer_hashref($question_details);
  $answer->{answer_text} = $anwser_hashref->{text};
  
  return $answer;
}

sub _transform_multiple_choice {
  my ($question, $question_details) = @_;
  
  my @answer_hashref_list = ();
  
  foreach my $checked_answer (@{$question->{answers}}){
    my $answer_id = $checked_answer->{row};
    
    @answer_hashref_list = (@answer_hashref_list, map {$_->{text}} grep { $_->{answer_id} eq $answer_id} @{$question_details->{answers}});
  }
  
  my $answer = _prepare_answer_hashref($question_details);
  $answer->{answer_text} = join('; ', @answer_hashref_list);
  
  return $answer;
}

sub _ok_to_skip {
  my ($question, $question_details) = @_;
  _log ("Skipping answer to question of type: $question_details->{type}->{family}");
  
  my $answer = _prepare_answer_hashref($question_details);
  $answer->{comment} = "Question of type '$question_details->{type}->{family}' skipped by ETL";
  
  return $answer;
}

sub _log {
  my ($message) = @_;
  print "$message\n";
}

sub _prepare_answer_hashref {
  my ($question_details) = @_;
  return {
    id => $question_details->{question_id},
    question_text => $question_details->{heading},   
  }
}

1;
