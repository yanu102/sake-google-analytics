# README

## DESCRIPTION

bacchusのsake_idに対する画像を表示する

## SYNOPSIS

    $ carton install
    $ carton exec perl app.pl deamon


アプリと同じディレクトリに`app.conf`を設置してください。
中身はこんな感じで


    {
        profile_id           => "***",
        client_id            => "***",
        client_secret        => "***",
        refresh_access_token => "***"
    };

`client_id`,`client_secret`はアプリの登録を行って取得してください。

`refresh_access_token`は以下で取得してください。

    $ perl -MNet::Google::Analytics::OAuth2 -e 'Net::Google::Analytics::OAuth2->new(client_id => "***", client_secret => "***")->interactive;'

出力されたトークンをメモしてください。

保存したファイルは`./public/images/`に保存されます。
現段階ではダウンロードボタンは無いので、各自でコピーしてください。

