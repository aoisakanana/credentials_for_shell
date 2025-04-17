# 環境構築用
source ./env.sh
echo $SUDO_PASSWORD | sudo -S snap install yq # yamlを読むのに使います
echo $SUDO_PASSWORD | chmod +x $PROJECT_ROOT/credentials.sh # 実行権限付与  
$PROJECT_ROOT/credentials.sh init # master.keyを新規に作成します。すでに存在する場合は上書き可否を確認します  