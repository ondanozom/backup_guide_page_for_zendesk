# backup_guide_page_for_zendesk
Zendesk Guideの記事をローカルにバックアップするRubyスクリプトです。

## 概要
スクリプトを実行すると、ZendeskGuideの記事（HTML）をローカルに保存します。
下記のようなファイルが作成されます。

* ヘルプページの記事一覧（HTML）
* ヘルプページの記事一覧（CSV）
* 記事（HTML）：　記事のHTMLファイル

## 必要環境（検証済み環境）
Ruby 2.0 以上
Curl 7.0 以上
※上記以下のVerは未検証です。

## フォルダ/ファイルの説明
/ BackupGuidePages
  / erb　・・・　テンプレート（erb）ファイル
  / exec　・・・　実行ファイル、設定ファイル置き場
  / output　・・・　出力したデータの格納先
  / temp  ・・・　テンポラリファイルの格納先
  
## 初期設定

1. ZendeskにてAPI用のトークンを作成しておきます。
> チャネル > API > 設定 

2. config.yaml を編集する
```
domain: https://your_domain.zendesk.com/
account: yourname@yourdomain.com（管理者権限のアカウント）
token: 1で生成したトークン
```

## 実行手順

1． 実行ファイルをダブルクリックする

Maｃの場合：

/exec/backup_help_pages.command を実行（ダブルクリック）する

Windowsの場合：
```
$ruby backup_guide_pages.rb 
```

