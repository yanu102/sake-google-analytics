use strict;
use warnings;
use lib qw(./lib);
use Carp;
use File::Slurp;
use GASake;
use JSON;
use Mojolicious::Lite;
use Path::Tiny;

my $sake_ids;
my $ga;
my $PROFILE_ID;
my $CLIENT_ID;
my $CLIENT_SECRET;
my $REFRESH_ACCESS_TOKEN;

get q{/} => sub {
    my $c = shift;
} => 'index';

get '/sakeids' => sub {
    my $c = shift;

    if ( !$PROFILE_ID ) {
        init_google_analytics_config();
    }

    my $sorted_sake_ids = [];
    if ( $sake_ids && 0 < scalar keys %{$sake_ids} ) {
        $sorted_sake_ids = [ sort { $a <=> $b } map { $_ + 0 } keys %{$sake_ids} ];
    }

    return $c->render(
        sorted_sake_ids    => $sorted_sake_ids,
        start_date_default => '2015-04-04',
        end_date_default   => '2015-05-20'
    );

} => 'sakeids';

post '/gasakeids' => sub {
    my $c = shift;

    # TODO:30分以上経過したら取得可能にする
    if ( !$ga ) {
        $ga                         = GASake->new;
        $ga->{profile_id}           = $PROFILE_ID;
        $ga->{client_id}            = $CLIENT_ID;
        $ga->{client_secret}        = $CLIENT_SECRET;
        $ga->{refresh_access_token} = $REFRESH_ACCESS_TOKEN;
        $ga->{request}              = {
            start_date => '2015-04-04',
            end_date   => '2015-05-21',
            dimensions => 'ga:eventLabel',
            metrics    => 'ga:totalEvents,ga:uniqueEvents',
            sort       => '-ga:totalEvents',
            filters    => 'ga:eventCategory==Review'
        };
    }

    if ( $c->param('start_date') ) {
        $ga->{request}->{start_date} = $c->param('start_date');
    }
    if ( $c->param('end_date') ) {
        $ga->{request}->{end_date} = $c->param('end_date');
    }

    $sake_ids = { map { $_ => 1 } grep { /^\d+$/msx } $ga->reviewed_sake_ids };

    $c->flash( redirect_from => 'sakeids' );

    return $c->redirect_to('sakeids');
};

get '/sake/(:id)' => sub {
    my $c = shift;

    my $redirect_from = 'sake/' . $c->param('id');

    $c->flash( redirect_from => $redirect_from );

    return $c->render( template => 'sakeimageupload', id => $c->param('id') );
};

get '/sake/(:id)/photo' => sub {
    my $c = shift;

    my $id = $c->param('id');

    my $photo_path = path("public/images/$id.jpg");

    return $c->render( data => $photo_path->slurp, format => 'jpg' );
};

post '/upload' => sub {
    my $c = shift;

    my $redirect_to = q{/};
    if ( $c->flash('redirect_from') ) {
        $redirect_to = $c->flash('redirect_from');
    }

    return $c->render( text => 'File is too big.', status => 200 )
      if $c->req->is_limit_exceeded;

    return $c->redirect_to($redirect_to)
      unless my $sake_image = $c->param('sake_image');
    return $c->redirect_to($redirect_to)
      unless my $sake_id = $c->param('sake_id');

    my $file_path = "public/images/$sake_id.jpg";
    $sake_image->move_to($file_path);

    return $c->redirect_to($redirect_to);
};

get '/sakeimageupload' => sub {
    my $c = shift;

    my $id = $c->param('sake_id') ? $c->param('sake_id') : q{};

    $c->flash( redirect_from => 'sakeimageupload' );

    return $c->render( id => $id );
} => 'sakeimageupload';

# Not found (404)
get '/missing' => sub { shift->render( template => 'does_not_exist' ) };

# Exception (500)
get 'dies' => sub { croak 'Intentional error' };

sub init_google_analytics_config {
    my $config = decode_json read_file('./google_analytics_config.json');

    $PROFILE_ID           = $config->{profile_id};
    $CLIENT_ID            = $config->{client_id};
    $CLIENT_SECRET        = $config->{client_secret};
    $REFRESH_ACCESS_TOKEN = $config->{refresh_access_token};

    return;
}

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
  <head><title>Index</title></head>
  <body>
    <h1>Hello Mojolicious!</h1>
    <ul>
      <li>
        %= link_to 'GoogleAnalyticsのレビューされた酒IDを取得する' => 'sakeids'
      </li>
      <li>
        %= link_to '酒の画像をアップロードする' => 'sakeimageupload'
      </li>
    </ul>
  </body>
</html>

@@ sakeids.html.ep
<!DOCTYPE html>
<html>
  <head><title>酒IDS</title></head>
  <body>
    <p>GoogleAnalyticsからレビューされた酒IDを取得する</p>
    <p>
      %= link_to 'Index' => '/'
    </p>
    <div>
      %= form_for gasakeids => begin
        %= label_for start_date => 'start_date'
        %= text_field start_date => $start_date_default
        %= label_for end_date => 'end_date'
        %= text_field end_date => $end_date_default
        %= submit_button 'GoogleAnalyticsデータ取得'
      %= end
    </div>
    % if (0 < scalar(@$sorted_sake_ids)) {
    <p>レビューIDの合計件数:<%= scalar(@$sorted_sake_ids) %></p>
    <table>
      <tr>
        <td>ID</td>
        <td>画像</td>
        <td>アップローダー</td>
      </tr>
      % for my $id (@$sorted_sake_ids) {
      <tr>
        <td>
          %= link_to $id => "sake/$id/photo", download => "$id.jpg"
        </td>
        <td>
          %= image "/images/$id.jpg"
        </td>
        <td>
          %= form_for upload => (enctype => 'multipart/form-data') => begin
            %= file_field 'sake_image'
            %= hidden_field 'sake_id' => $id
            %= submit_button 'Upload'
          % end
        </td>
      </tr>
      % }
    </table>
    % }
  </body>
</html>

@@ sakeimageupload.html.ep
<!DOCTYPE html>
<html>
  <head><title>お酒画像アップローダー</title></head>
  <body>
    <p>お酒の画像をアップロードするよ</p>
    <p>
      %= link_to 'Index' => '/'
    </p>
    % if ($id) {
      %= image "/images/$id.jpg"
      %= link_to 'ダウンロードする' => "sake/$id/photo", download => "$id.jpg"
    % } else {
      % $id = '';
    % }
    %= form_for upload => (enctype => 'multipart/form-data') => begin
      %= label_for 'sake_id' => 'sake_id'
      %= text_field 'sake_id' => $id
      %= file_field 'sake_image'
      %= hidden_field 'redirect_to' => '/'
      %= submit_button 'Upload'
    % end
  </body>
</html>
