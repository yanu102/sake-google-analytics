use strict;
use warnings;
use Carp;
use Amazon::S3;
use GASake;
use Mojolicious::Lite;
use Path::Tiny;
use Smart::Comments;

my $ga_sake_ids;
my $ga;
my $s3;
my $bucket;
my $config;

get q{/} => sub {
    my $c = shift;

    _bucket();
} => 'index';

any '/sakeids' => sub {
    my $c = shift;

    _bucket();
    my @sake_ids = map { $_->{key} } @{ $bucket->list->{keys} };

    my $start_id = 1;
    my $end_id   = 10;
    if ( $c->param('start_id') ) {
        $start_id = $c->param('start_id');
    }
    if ( $c->param('end_id') ) {
        $end_id = $c->param('end_id');
    }
    my $sorted_sake_ids =
      [ sort { $a <=> $b } grep { $start_id <= $_ && $_ <= $end_id } map { $_ + 0 } grep { /\d+/msx } @sake_ids ];

    return $c->render(
        sorted_sake_ids => $sorted_sake_ids,
        start_id        => $start_id,
        end_id          => $end_id,
    );
};

get '/gasakeids' => sub {
    my $c = shift;

    my $sorted_ga_sake_ids = [];
    if ( $ga_sake_ids && 0 < scalar keys %{$ga_sake_ids} ) {
        $sorted_ga_sake_ids = [ sort { $a <=> $b } map { $_ + 0 } keys %{$ga_sake_ids} ];
    }

    return $c->render(
        sorted_ga_sake_ids => $sorted_ga_sake_ids,
        start_date_default => '2015-04-04',
        end_date_default   => '2015-05-20'
    );
};

post '/gasakeids' => sub {
    my $c = shift;

    if ( !$ga ) {
        if ( !$config ) {
            $config = plugin 'Config';
        }
        $ga                         = GASake->new;
        $ga->{profile_id}           = $config->{profile_id};
        $ga->{client_id}            = $config->{client_id};
        $ga->{client_secret}        = $config->{client_secret};
        $ga->{refresh_access_token} = $config->{refresh_access_token};
        $ga->{request}              = {
            start_date => '2015-04-04',
            end_date   => '2015-05-21',
            dimensions => 'ga:eventLabel',
            metrics    => 'ga:totalEvents,ga:uniqueEvents',
            sort       => '-ga:totalEvents',
            filters    => 'ga:eventCategory==Review'
        };
    }

    my $new_start_date = $c->param('start_date');
    my $new_end_date   = $c->param('end_date');
    if ( $ga->{request}->{start_date} eq $new_start_date && $ga->{request}->{end_date} eq $new_end_date ) {
        return $c->redirect_to('gasakeids');
    }
    if ($new_start_date) {
        $ga->{request}->{start_date} = $new_start_date;
    }
    if ($new_end_date) {
        $ga->{request}->{end_date} = $new_end_date;
    }

    $ga_sake_ids = { map { $_ => 1 } grep { /^\d+$/msx } $ga->reviewed_sake_ids };

    return $c->redirect_to('gasakeids');
};

get '/sake/(:id)' => sub {
    my $c = shift;

    my $redirect_from = 'sake/' . $c->param('id');

    $c->flash( redirect_from => $redirect_from );

    return $c->render( template => 'uploadimage', id => $c->param('id') );
};

get '/sake/(:id)/photo' => sub {
    my $c = shift;

    my $id = $c->param('id');

    _bucket();
    if ( $bucket->head_key($id) ) {
        my $object = $bucket->get_key($id);
        return $c->render( data => $object->{value}, format => $object->{content_type} =~ /\/(.+)$/msx );
    }
    else {
        return $c->render( data => path('no-image.png')->slurp, format => 'png', status => '404' );
    }
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
      unless my $image = $c->param('sake_image');
    return $c->redirect_to($redirect_to)
      unless my $id = $c->param('sake_id');

    _bucket();
    $bucket->add_key( $id, $image->{asset}->slurp, { content_type => $image->{headers}->content_type } )
      or croak $s3->err . ':' . $s3->errstr;

    return $c->redirect_to($redirect_to);
};

get '/uploadimage' => sub {
    my $c = shift;

    my $id = $c->param('sake_id') ? $c->param('sake_id') : q{};

    $c->flash( redirect_from => 'uploadimage' );

    return $c->render( id => $id );
};

# Not found (404)
get '/missing' => sub { shift->render( template => 'does_not_exist' ) };

# Exception (500)
get 'dies' => sub { croak 'Intentional error' };

sub _bucket {
    if ( !$bucket ) {
        if ( !$s3 ) {
            ### s3 is not exist
            if ( !$config ) {
                ### config is not exist
                $config = plugin 'Config';
            }
            $s3 = Amazon::S3->new(
                {
                    aws_access_key_id     => $config->{aws_access_key_id},
                    aws_secret_access_key => $config->{aws_secret_access_key},
                    retry                 => 1
                }
            );
        }
        $bucket = $s3->bucket('bacchus-images');
    }
    return;
}

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
  <head><title>Bacchus Image Uploader</title></head>
  <body>
    <h1>Hello Bacchus Image Uploader</h1>
    <ul>
      <li>
        %= link_to 'GoogleAnalyticsのレビューされた酒IDを取得する' => 'gasakeids'
      </li>
      <li>
        %= link_to '登録されている酒IDを取得する' => 'sakeids'
      </li>
      <li>
        %= link_to '酒の画像をアップロードする' => 'uploadimage'
      </li>
    </ul>
  </body>
</html>

@@ sakeids.html.ep
<!DOCTYPE html>
<html>
  <head><title>登録されている酒ID</title></head>
  <body>
    <p>登録されている酒IDを取得する</p>
    <p>
      %= link_to 'Index' => '/'
    </p>
    <div>
      %= form_for sakeids => begin
        %= label_for start_id => 'start_id'
        %= text_field start_id => $start_id
        %= label_for end_id => 'end_id'
        %= text_field end_id => $end_id
        %= submit_button '酒IDを表示する'
      %= end
    </div>
    <p>IDが <%= $start_id %> 〜 <%= $end_id %> の画像</p>
    <p>表示IDの合計件数:<%= scalar(@$sorted_sake_ids) %></p>
    % if (0 < scalar(@$sorted_sake_ids)) {
    <table>
      <tr>
        <td>ID</td>
        <td>画像</td>
        <td>アップローダー</td>
      </tr>
      % for my $id (@$sorted_sake_ids) {
      <tr>
        <td>
          <%= $id %>
        </td>
        <td>
          %= image "/sake/$id/photo", height => '200'
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
    % } else {
    <p>IDが <%= $start_id %> 〜 <%= $end_id %> の画像はありません。</p>
    % }
  </body>
</html>

@@ gasakeids.html.ep
<!DOCTYPE html>
<html>
  <head><title>GA経由レビューされた酒ID</title></head>
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
    % if (0 < scalar(@$sorted_ga_sake_ids)) {
    <p>レビューIDの合計件数:<%= scalar(@$sorted_ga_sake_ids) %></p>
    <table>
      <tr>
        <td>ID</td>
        <td>画像</td>
        <td>アップローダー</td>
      </tr>
      % for my $id (@$sorted_ga_sake_ids) {
      <tr>
        <td>
          <%= $id %>
        </td>
        <td>
          %= image "/sake/$id/photo", height => '200'
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

@@ uploadimage.html.ep
<!DOCTYPE html>
<html>
  <head><title>お酒画像アップローダー</title></head>
  <body>
    <p>お酒の画像をアップロードするよ</p>
    <p>
      %= link_to 'Index' => '/'
    </p>
    % if ($id) {
      %= image "/sake/$id/photo", height => '200'
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
