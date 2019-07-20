# backup_guide_page_for_zendesk
Zendesk Guideの記事をローカルにバックアップするRubyスクリプトです。

## 概要
スクリプトを実行すると、ZendeskGuideの記事（HTML）をローカルに保存します。
下記のようなファイルが作成されます。

* ヘルプページの記事一覧（HTML）
* ヘルプページの記事一覧（CSV）
* 記事（HTML）：　ヘルプページのバックアップファイルを作成する, ヘルプページのバックアップファイルを作成する ...

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
  
## 実行手順

1. config.yaml を編集する

```
domain: https://your_domain.zendesk.com/
account: user_support@street-academy.com
token: Qeibjt3ZNiFL5SrnmcET28USNTIQx6Kix7kFm2GZ
```
