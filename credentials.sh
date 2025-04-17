#!/bin/bash

# 暗号化ファイルパスとマスターキーファイルパスなどを環境変数設定ファイルから読み込む
source ./env.sh

# 暗号化オプション  
# -aes-256-cbc: AES暗号を使用  
# -pbkdf2: より安全なキー派生関数を使用  
# -iter 10000: ブルートフォース攻撃耐性    
OPENSSL_ENC_OPTS="-aes-256-cbc -pbkdf2 -iter 10000 -salt"
OPENSSL_DEC_OPTS="-aes-256-cbc -pbkdf2 -iter 10000"



# 一時ファイルを作成（カレントディレクトリに./tmpフォルダを使用）
create_temp_file() {
    # tmpディレクトリが存在しなければ作成
    if [[ ! -d "./tmp" ]]; then
        mkdir -p "./tmp"
    fi
    
    # ランダムな文字列を生成（シェルスクリプトの可搬性のためにsedとhead/tailを使用）
    local random_str=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 10)
    local timestamp=$(date +%s)
    local temp_file="./tmp/tmp.${timestamp}_${random_str}"
    
    touch "$temp_file"
    echo "$temp_file"
}

# YAMLファイルから値を取得するためのyqコマンドが必要
# yqがインストールされているか確認
check_yq() {
    if ! command -v yq &> /dev/null; then
        echo "エラー: yqコマンドが見つかりません" >&2
        echo "yqをインストールしてください: https://github.com/mikefarah/yq" >&2
        return 1
    fi
}

# 初期化されたYAMLファイルを作成
create_initial_yaml() {
    echo "# 認証情報" > "$1"
}

# 認証情報の追加・更新（YAMLパス形式）
add_credential() {
    local yaml_path="$1"
    local value="$2"
    
    check_yq || return 1
    
    # 既存のファイルがあるかチェック
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        # 一時ファイルに復号化
        local temp_file=$(create_temp_file)
        decrypt_credentials > "$temp_file"
        
        # 一時ファイルが存在するか確認
        if [[ ! -f "$temp_file" ]]; then
            echo "エラー: 一時ファイルの作成に失敗しました" >&2
            return 1
        fi
        
        # YAMLパスを使用して値を設定
        yq "$yaml_path = \"$value\"" -i "$temp_file"
        
        # 再暗号化（セキュリティ強化オプション使用）
        openssl enc $OPENSSL_ENC_OPTS -in "$temp_file" -out "$CREDENTIALS_FILE" -pass file:"$MASTER_KEY_FILE"
        rm -f "$temp_file"
    else
        # 新規作成
        local temp_file=$(create_temp_file)
        create_initial_yaml "$temp_file"
        
        # 一時ファイルが存在するか確認
        if [[ ! -f "$temp_file" ]]; then
            echo "エラー: 一時ファイルの作成に失敗しました" >&2
            return 1
        fi
        
        # YAMLパスを使用して値を設定
        yq "$yaml_path = \"$value\"" -i "$temp_file"
        
        # 暗号化（セキュリティ強化オプション使用）
        openssl enc $OPENSSL_ENC_OPTS -in "$temp_file" -out "$CREDENTIALS_FILE" -pass file:"$MASTER_KEY_FILE"
        rm -f "$temp_file"
    fi
    
    echo "認証情報 '$yaml_path' を保存しました"
}

# 複数の認証情報を一度に追加（YAMLファイルから）
import_credentials() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        echo "エラー: インポートするYAMLファイルが存在しません: $yaml_file" >&2
        return 1
    fi
    
    # 既存のファイルがあるかチェック
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        # 一時ファイルに復号化
        local temp_file=$(create_temp_file)
        decrypt_credentials > "$temp_file"
        
        # 一時ファイルが存在するか確認
        if [[ ! -f "$temp_file" ]]; then
            echo "エラー: 一時ファイルの作成に失敗しました" >&2
            return 1
        fi
        
        # YAMLファイルをマージ
        local merge_file="./tmp/merge_$(basename "$temp_file")"
        yq '. * load("'"$yaml_file"'")' "$temp_file" > "$merge_file"
        
        # マージファイルが存在し、サイズが0より大きいことを確認
        if [[ ! -s "$merge_file" ]]; then
            echo "エラー: YAMLファイルのマージに失敗しました" >&2
            rm -f "$temp_file" "$merge_file"
            return 1
        fi
        
        mv "$merge_file" "$temp_file"
        
        # 再暗号化（セキュリティ強化オプション使用）
        openssl enc $OPENSSL_ENC_OPTS -in "$temp_file" -out "$CREDENTIALS_FILE" -pass file:"$MASTER_KEY_FILE"
        rm -f "$temp_file"
    else
        # 新規作成（そのままインポート）
        openssl enc $OPENSSL_ENC_OPTS -in "$yaml_file" -out "$CREDENTIALS_FILE" -pass file:"$MASTER_KEY_FILE"
    fi
    
    echo "YAMLファイルから認証情報をインポートしました"
}

# 認証情報を取得（YAMLパス形式）
get_credential() {
    local yaml_path="$1"
    
    check_yq || return 1
    
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "エラー: 認証情報ファイルが存在しません" >&2
        return 1
    fi
    
    # 一時ファイルに復号化
    local temp_file=$(create_temp_file)
    decrypt_credentials > "$temp_file"
    
    # 一時ファイルが存在するか確認
    if [[ ! -f "$temp_file" ]]; then
        echo "エラー: 一時ファイルの作成に失敗しました" >&2
        return 1
    fi
    
    # YAMLパスを使用して値を取得
    yq "$yaml_path" "$temp_file"
    
    rm -f "$temp_file"
}

# 全ての認証情報を表示
list_credentials() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "エラー: 認証情報ファイルが存在しません" >&2
        return 1
    fi
    
    decrypt_credentials
}

# 認証情報を削除（YAMLパス形式）
delete_credential() {
    local yaml_path="$1"
    
    check_yq || return 1
    
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "エラー: 認証情報ファイルが存在しません" >&2
        return 1
    fi
    
    # 一時ファイルに復号化
    local temp_file=$(create_temp_file)
    decrypt_credentials > "$temp_file"
    
    # 一時ファイルが存在するか確認
    if [[ ! -f "$temp_file" ]]; then
        echo "エラー: 一時ファイルの作成に失敗しました" >&2
        return 1
    fi
    
    # パスが存在するか確認
    local check_value=$(yq "$yaml_path" "$temp_file")
    if [[ "$check_value" == "null" ]]; then
        echo "エラー: パス '$yaml_path' が見つかりません" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # YAMLパスを使用して値を削除
    yq "del($yaml_path)" -i "$temp_file"
    
    # 再暗号化（セキュリティ強化オプション使用）
    openssl enc $OPENSSL_ENC_OPTS -in "$temp_file" -out "$CREDENTIALS_FILE" -pass file:"$MASTER_KEY_FILE"
    rm -f "$temp_file"
    
    echo "認証情報 '$yaml_path' を削除しました"
}

# 認証情報ファイルを復号化
decrypt_credentials() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "エラー: 認証情報ファイルが存在しません" >&2
        return 1
    fi
    
    if [[ ! -f "$MASTER_KEY_FILE" ]]; then
        echo "エラー: マスターキーファイルが存在しません" >&2
        return 1
    fi
    
    openssl enc $OPENSSL_DEC_OPTS -d -in "$CREDENTIALS_FILE" -pass file:"$MASTER_KEY_FILE"
}

# クリーンアップ関数 - スクリプト終了時に呼び出す
cleanup() {
    # tmpディレクトリ内の一時ファイルを削除
    if [[ -d "./tmp" ]]; then
        find "./tmp" -name "tmp.*" -type f -mmin +60 -delete 2>/dev/null
    fi
}

# スクリプト終了時にクリーンアップを実行
trap cleanup EXIT

# 認証情報をエクスポート（復号化してファイルに保存）
export_credentials() {
    local output_file="$1"
    
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "エラー: 認証情報ファイルが存在しません" >&2
        return 1
    fi
    
    # 出力ファイルの親ディレクトリが存在するか確認
    local output_dir=$(dirname "$output_file")
    if [[ ! -d "$output_dir" ]]; then
        echo "エラー: 出力ディレクトリが存在しません: $output_dir" >&2
        return 1
    fi
    
    # ファイルに書き込めるか確認
    if ! touch "$output_file" 2>/dev/null; then
        echo "エラー: 出力ファイルに書き込めません: $output_file" >&2
        return 1
    fi
    
    # 復号化してファイルに保存
    decrypt_credentials > "$output_file"
    
    # 出力ファイルのパーミッションを制限
    chmod 600 "$output_file"
    
    echo "認証情報を '$output_file' にエクスポートしました"
    echo "警告: このファイルには機密情報が含まれています。適切に保護してください。"
}

# マスターキーを初期化
initialize_master_key() {
    if [[ -f "$MASTER_KEY_FILE" ]]; then
        echo "警告: マスターキーが既に存在します。上書きしますか？ [y/N]"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "初期化をキャンセルしました"
            return 1
        fi
    fi
    
    # 32バイトのランダムキーを生成
    openssl rand -hex 32 > "$MASTER_KEY_FILE"
    chmod 600 "$MASTER_KEY_FILE"
    
    echo "マスターキーを初期化しました: $MASTER_KEY_FILE"
    echo "警告: マスターキーは安全に保管してください。紛失すると認証情報を復元できなくなります。"
}

# 認証情報のフィールド要素情報を取得
info_elements() {
    local yaml_path="$1"
    
    check_yq || return 1
    
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "エラー: 認証情報ファイルが存在しません" >&2
        return 1
    fi
    
    # 一時ファイルに復号化
    local temp_file=$(create_temp_file)
    decrypt_credentials > "$temp_file"
    
    # 一時ファイルが存在するか確認
    if [[ ! -f "$temp_file" ]]; then
        echo "エラー: 一時ファイルの作成に失敗しました" >&2
        return 1
    fi
    
    # 要素の型を判断 - 正しい構文を使用
    local element_type
    element_type=$(yq "$yaml_path | type" "$temp_file" 2>/dev/null)
    local yq_status=$?
    
    if [[ $yq_status -ne 0 ]]; then
        echo "エラー: YAMLパスの解析に失敗しました: '$yaml_path'" >&2
        echo "正しいYAMLパス構文を使用してください。" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # YAMLタグに基づいて処理
    if [[ "$element_type" == "!!seq" ]]; then
        # 配列（シーケンス）の場合は要素数のみ表示
        local array_length
        array_length=$(yq "$yaml_path | length" "$temp_file" 2>/dev/null)
        
        echo "タイプ: 配列"
        echo "要素数: $array_length"
        
    elif [[ "$element_type" == "!!map" ]]; then
        # マップ/オブジェクトの場合はキー一覧のみ表示
        local keys
        keys=$(yq "$yaml_path | keys" "$temp_file" 2>/dev/null)
        local key_count
        key_count=$(yq "$yaml_path | keys | length" "$temp_file" 2>/dev/null)
        
        echo "タイプ: マップ/オブジェクト"
        echo "キー数: $key_count"
        
        if [[ $key_count -gt 0 ]]; then
            echo "キー一覧:"
            yq "$yaml_path | keys | .[]" "$temp_file" 2>/dev/null
        fi
        
    elif [[ "$element_type" == "!!null" ]]; then
        # 存在しない場合
        echo "エラー: パス '$yaml_path' が見つかりません" >&2
        rm -f "$temp_file"
        return 1
        
    elif [[ "$element_type" == "!!str" || "$element_type" == "!!int" || "$element_type" == "!!float" || "$element_type" == "!!bool" ]]; then
        # スカラー値の場合
        local value
        value=$(yq "$yaml_path" "$temp_file" 2>/dev/null)
        
        echo "タイプ: 値"
        echo "値: $value"
        
    else
        # その他の型
        local value
        value=$(yq "$yaml_path" "$temp_file" 2>/dev/null)
        
        echo "タイプ: 値"
        echo "値: $value"
    fi
    
    rm -f "$temp_file"
    return 0
}

# 使用例
if [[ "$1" == "init" ]]; then
    initialize_master_key
elif [[ "$1" == "add" && -n "$2" && -n "$3" ]]; then
    add_credential "$2" "$3"
elif [[ "$1" == "import" && -n "$2" ]]; then
    import_credentials "$2"
elif [[ "$1" == "export" && -n "$2" ]]; then
    export_credentials "$2"
elif [[ "$1" == "get" && -n "$2" ]]; then
    get_credential "$2"
elif [[ "$1" == "info" && -n "$2" ]]; then
    # 指定したフィールドの詳細情報を取得
    info_elements "$2"
elif [[ "$1" == "list" ]]; then
    list_credentials
elif [[ "$1" == "all" ]]; then
    # 暗号化されたファイルを復号して全内容を標準出力
    decrypt_credentials
elif [[ "$1" == "delete" && -n "$2" ]]; then
    delete_credential "$2"
else
    echo "使用方法:"
    echo "  $0 init                         # マスターキーを初期化"
    echo "  $0 add 'PATH.TO.KEY' VALUE      # 認証情報を追加または更新（YAMLパス形式）"
    echo "  $0 import YAML_FILE             # YAMLファイルから認証情報をインポート"
    echo "  $0 export OUTPUT_FILE           # 認証情報をYAMLファイルにエクスポート"
    echo "  $0 get 'PATH.TO.KEY'            # 認証情報を取得（YAMLパス形式）"
    echo "  $0 info 'PATH.TO.FIELD'         # 指定したフィールドの型と詳細情報を取得"
    echo "  $0 list                         # すべての認証情報を表示"
    echo "  $0 all                          # 暗号化されたファイルを復号して全内容を表示"
    echo "  $0 delete 'PATH.TO.KEY'         # 認証情報を削除（YAMLパス形式）"
    echo ""
    echo "YAMLパスの例:"
    echo "  '.customer_1.service_1.keys.for_get_user'  # 単一の値にアクセス"
    echo "  '.Customers'                     # 配列またはマップの情報を取得"
    echo "  '.Customers[0].name'             # 配列の特定要素のプロパティにアクセス"
fi