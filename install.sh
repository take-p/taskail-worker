#!/bin/sh
# Taskail ワーカーのインストーラー。
#
#   curl -fsSL https://raw.githubusercontent.com/take-p/taskail-worker/main/install.sh | sh
#
# GitHub Releases から自分のプラットフォーム向けの tar.gz を落とし、SHA256 を確かめて置く。
#
# **sh（POSIX）で書く。** ラズパイの /bin/sh は dash で、bash 前提の書き方が刺さる。
# 変数展開を必ず ${} で囲むのもそのため —— dash は `$var（` のような並びで
# 全角文字のバイトを変数名に食い込ませ、set -u と組んで意味不明な失敗になる（実際になった）。
set -eu

# **配布先は本体とは別の public リポジトリ。** 本体は private なので、
# raw も Releases も認証なしでは 404 になり `curl | sh` が成り立たない。
# 公開するのは配布物と取得手順だけで、ソースは向こうに置かない。
# **このファイルの正はこちら側**で、リリースのたびに公開リポジトリへ写す
# （docs/worker-setup.md の「配布物をつくる」）。
REPO="take-p/taskail-worker"
# 既定は sudo の要らない場所。PATH に無ければ最後に案内する
INSTALL_DIR="${TASKAIL_INSTALL_DIR:-${HOME}/.local/bin}"
# 既定は最新。TASKAIL_VERSION=worker-v0.1.0 のように固定もできる
VERSION="${TASKAIL_VERSION:-latest}"

die() {
    echo "エラー: ${1}" >&2
    exit 1
}

detect_target() {
    os="$(uname -s)"
    machine="$(uname -m)"

    case "${os}" in
        Darwin)
            # SEA は darwin-x64 を見ていない。Intel Mac はここで止める
            [ "${machine}" = "arm64" ] || die "Intel Mac 向けのバイナリはありません（Apple Silicon のみ）"
            echo "darwin-arm64"
            ;;
        Linux)
            case "${machine}" in
                aarch64 | arm64) echo "linux-arm64" ;;
                x86_64) echo "linux-x64" ;;
                *) die "対応していない CPU です: ${machine}" ;;
            esac
            ;;
        *) die "対応していない OS です: ${os}" ;;
    esac
}

# sha256 を取るコマンドは環境で名前が違う（macOS は shasum、Linux は sha256sum）
sha256_of() {
    if command -v sha256sum > /dev/null 2>&1; then
        sha256sum "${1}" | cut -d' ' -f1
    elif command -v shasum > /dev/null 2>&1; then
        shasum -a 256 "${1}" | cut -d' ' -f1
    else
        die "sha256sum も shasum も見つかりません"
    fi
}

# 置いただけで満足しない。**動かないなら、その場で言う**
# （node の Linux ビルドは libatomic を要求するが、slim な環境には入っていない）
smoke_test() {
    out="$("${INSTALL_DIR}/taskail-worker" 2>&1 || true)"
    case "${out}" in
        *"shared libraries"*)
            echo >&2
            echo "置きましたが、起動できませんでした:" >&2
            echo "  ${out}" >&2
            case "${out}" in
                *libatomic*)
                    echo "Debian / Ubuntu / Raspberry Pi OS なら: sudo apt install libatomic1" >&2
                    ;;
            esac
            exit 1
            ;;
    esac
}

main() {
    command -v curl > /dev/null 2>&1 || die "curl が要ります"
    command -v tar > /dev/null 2>&1 || die "tar が要ります"

    target="$(detect_target)"
    if [ "${VERSION}" = "latest" ]; then
        base="https://github.com/${REPO}/releases/latest/download"
    else
        base="https://github.com/${REPO}/releases/download/${VERSION}"
    fi

    tmp="$(mktemp -d)"
    # 途中で失敗しても散らかさない
    trap 'rm -rf "${tmp}"' EXIT

    archive="taskail-worker-${target}.tar.gz"
    echo "Taskail ワーカー (${target}) を取得しています..."
    curl -fsSL "${base}/${archive}" -o "${tmp}/${archive}" || die "${base}/${archive} を取得できませんでした"
    curl -fsSL "${base}/SHA256SUMS" -o "${tmp}/SHA256SUMS" || die "SHA256SUMS を取得できませんでした"

    # **検証は飛ばさない。** ここを緩めると、配布経路が丸ごと信用できなくなる
    expected="$(grep " ${archive}\$" "${tmp}/SHA256SUMS" | cut -d' ' -f1)"
    [ -n "${expected}" ] || die "SHA256SUMS に ${archive} がありません"
    actual="$(sha256_of "${tmp}/${archive}")"
    [ "${expected}" = "${actual}" ] || die "SHA256 が一致しません（期待 ${expected} / 実際 ${actual}）"

    tar -xzf "${tmp}/${archive}" -C "${tmp}"
    mkdir -p "${INSTALL_DIR}"
    # 起動中のワーカーを差し替えると Text file busy になるので、一度どかしてから置く
    rm -f "${INSTALL_DIR}/taskail-worker"
    mv "${tmp}/taskail-worker" "${INSTALL_DIR}/taskail-worker"
    chmod 755 "${INSTALL_DIR}/taskail-worker"

    smoke_test

    echo "${INSTALL_DIR}/taskail-worker に入れました。"
    case ":${PATH}:" in
        *":${INSTALL_DIR}:"*) ;;
        *) echo "※ ${INSTALL_DIR} が PATH にありません。シェルの設定に追加してください。" ;;
    esac
    echo
    echo "次にやること:"
    echo "  1. claude が入っていて、サブスクでログイン済みであること"
    echo "  2. taskail-worker login    （Taskail にログインする）"
    echo "  3. ~/.taskail/config.json を書く（docs/worker-setup.md を参照）"
    echo "  4. taskail-worker start"
}

main
