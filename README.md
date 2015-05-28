# README

## DESCRIPTION

bacchusのsake_idに対する画像を表示する

## SYNOPSIS

    $ carton install
    $ carton exec perl app.pl deamon


アプリと同じディレクトリに`google_analytics_config.json`を設置してください。
中身はこんな感じで


    {
        "profile_id": "***",
        "client_id": "***",
        "client_secret": "***",
        "refresh_access_token": "***"
    }


保存したファイルは`./public/images/`に保存されます。
現段階ではダウンロードボタンは無いので、各自でコピーしてください。

