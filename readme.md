# 依存関係  

yq コマンド ver4.30 以上

## ファイル構成  

credentials.sh - 認証機能を提供します。
.master.key - 暗号化/復号化に使用するマスターキー（プライベートに保管）  
.credentials.yml.enc - 暗号化された認証情報ファイル（YAML形式）
env.sh.sample - 環境変数の設定例です

build.sh - 環境構築簡略用です。Ubuntu向けなのでRHELなどでは適宜修正してください    

## セキュリティモデル  

このシステムは以下のセキュリティモデルに基づいています：  

### 機密の保管  

APIキーなどの機密情報は .credentials.yml.enc ファイルに暗号化された状態で保存されます  

### 暗号化・複合化  

暗号化/復号化には .master.key ファイルに保存された秘密鍵を使用します  
OpenSSL AES-256-CBCを使用して強力な暗号化を提供します  

## 初期セットアップ  

必要に応じてbuild.shに実行権限を付与します。  
env.sh.sampleを参考に、 env.sh を作成して変数を設定します。  

credentials.sh ファイルをプロジェクトのルートディレクトリにコピーします。  
build.sh を実行します。中身はUbuntu向けなので、RHELなどではdnfなどに置き換えて実行してください。    

git管理する場合は、.gitignore ファイルに以下を追加して、機密ファイルをバージョン管理から除外します：

.master.key

### YAMLファイルのインポート  

既存のYAMLファイルをインポートするには：
bash# 例: 初期設定としてYAMLファイルをインポート

```shell
cat > initial_config.yml << EOF
customer_1:
  name: "お客様1"
  service_1:
    name: "サービスコンテナ1"
    keys:
      for_get_user: "KEY!21AKJ97283"
      for_create_note: "KEY#29128JAS0"
customer_2:
  name: "お客様2"
  service_1:
    name: "サービスコンテナ1"
    keys:
      for_get_user: "KEY@9873ALSKD"
      for_create_note: "KEY%2398ASDLK"
EOF
```

```shell
$PROJECT_ROOT/credentials.sh import initial_config.yml
rm initial_config.yml  # 安全のため元ファイルを削除
```

### 使用方法  

認証情報の追加・更新（YAMLパス形式）
```
$PROJECT_ROOT/credentials.sh add ".Customers[0].Services[0].keys[0].key" "NEW_API_KEY"
```

#### 新しい顧客を追加  

```shell
$PROJECT_ROOT/credentials.sh add '.Customers[2].name' "お客様3"
$PROJECT_ROOT/credentials.sh add '.Customers[2].Service[0].name' "サービスコンテナ1"
$PROJECT_ROOT/credentials.sh add '.Customers[2].Service[0].keys[0].name' "for_get_users"
$PROJECT_ROOT/credentials.sh add '.Customers[2].Service[0].keys[0].key' "GET_USERS_KEY"
```

#### あるフィールドの取得  
```shell
$PROJECT_ROOT/credentials.sh get '.Customers[0].Service[0].name'
```
