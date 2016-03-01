package SurveyMonkey::API;

use LWP::UserAgent;
use JSON;

my $json = new JSON();

sub new {
  my ( $class, $domain, $api_key, $token ) = @_;
  return bless(
    {
      domain  => $domain,
      api_key => $api_key,
      token   => $token,
    },
    $class
  );
}

sub _api {
  my ( $self, $api_method, $arguments ) = @_;

  my $server_endpoint = $self->_construct_endpoint("/v2/surveys/$api_method");

  my $req = HTTP::Request->new( POST => $server_endpoint );
  $req->header( 'content-type'  => 'application/json' );
  $req->header( 'Authorization' => "bearer $self->{token}" );

  $req->content($json->encode($arguments));

  my $ua = LWP::UserAgent->new;

  my $resp = $ua->request($req);
  if ( $resp->is_success ) {
    my $response = $json->decode($resp->decoded_content);
    die "Error occured while consuming survey monkey API: $response->{errmsg}" unless ($response->{status} == 0);
    return $response->{data}; 
  }
  else {
    die 'HTTP POST error: ' . $resp->code . ' ' . $resp->message . "\n";
  }
}

sub survey_details {
  my ( $self, $survey_id ) = @_;
  
  my $arguments = {
    survey_id => $survey_id
  };

  my $data = $self->_api( 'get_survey_details', $arguments );

  my $questions = {};
  
  my $pages = $data->{pages};
  foreach my $page (@$pages) {
    foreach my $question ( @{ $page->{questions} } ) {
      $questions->{ $question->{question_id} } = $question;
    }
  }

  return $questions;
}

sub response_ids_between_timestamps {
  my ($self, $survey_id, $start_modified_date, $end_modified_date) = @_;
  my $arguments = {
    survey_id => $survey_id,
  };
  
  $arguments->{start_modified_date} = $start_modified_date if defined $start_modified_date;
  $arguments->{end_modified_date} = $end_modified_date if defined $end_modified_date;
  
  my $data = $self->_api( 'get_respondent_list', $arguments );
  return [ map { $_->{respondent_id} } @{$data->{respondents}} ];
}

sub response_details {
  my ($self, $survey_id, $respondent_ids) = @_;
  my $arguments = {
    respondent_ids => $respondent_ids,
    survey_id => $survey_id,
  };
  
  my $data = $self->_api('get_responses', $arguments);
  return $data;
}

sub _construct_endpoint {
  my ( $self, $URI ) = @_;
  return "$self->{domain}$URI?api_key=$self->{api_key}";
}

1;
