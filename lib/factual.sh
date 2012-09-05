#!/bin/bash

# Low-level functions
factual-say() {
  while (( $# )); do
    echo -e >&2 "$1"
    shift
  done
}

factual-load-key() {
  if [[ -r ~/.factualrc ]]; then
    mode=$(stat -c %a ~/.factualrc)
    if [[ "$mode" == "${mode%00}" ]]; then
      factual-say "~/.factualrc is accessible by group and/or others." \
                  "You can remove this warning by changing permissions:" \
                  "$ chmod 0600 ~/.factualrc"
    fi

    oauth_consumer_key="$(cut -f 1 ~/.factualrc)"
    oauth_consumer_secret="$(cut -f 2 ~/.factualrc)"
  else
    factual-say "Your credentials are not yet stored in ~/.factualrc." \
                "To use this driver, you'll need an API key, available free " \
                "from http://www.factual.com/api-keys/request." \
                "" \
                "When you have the OAuth info, paste it in below:" \
                ""
    read "OAuth key: " oauth_consumer_key
    read "OAuth secret: " oauth_consumer_secret

    if echo -e "$oauth_consumer_key\t$oauth_consumer_secret" > ~/.factualrc; then
      chmod 0600 ~/.factualrc
      factual-say "Credentials saved in ~/.factualrc."
    else
      factual-say "Could not write ~/.factualrc"
      return 1
    fi
  fi

  oauth_signature_method="HMAC-SHA1"
  oauth_version="1.0"
}

factual-oauth-header() {
  local method="$1"
  local url="$2"
  shift 2

  OAuth_authorization_header \
    Authorization \
    '' \
    '' \
    '' \
    "$method" \
    "$url" \
    "$@"
}

factual-request() {
  local method="$1"
  local url="http://$factual_hostname$2"
  shift 2

  local oauth_header="$(factual-oauth-header 'GET' "$url" "$@")"
  local querystring=

  while (( $# )); do
    querystring="$querystring&$1"
    shift
  done

  url="$url?${querystring:1}"

  [[ -z "$factual_verbose" ]] || factual-say "request URL is $url"
  local result="$(curl -s $factual_verbose -H "$oauth_header" "$url")"
  if tr ',' '\n' <<< "$result" | grep '"status":"ok"' >& /dev/null; then
    echo "$result"
  else
    factual-say "\033[1;31merror requesting $url\033[0;0m"
    echo "$result"
    return 1
  fi
}

factual-check-dependency() {
  echo -ne "checking for $1... \033[1;32m"
  if ! which $1 | tr -d '\n'; then
    echo -e "\033[1;31mnot found\033[0;0m"
    return 1
  else
    echo -e "\033[0;0m"
  fi
}

# Actions
factual-usage() {
cat >&2 <<EOF
Factual driver version $FACTUAL_DRIVER_VERSION
Copyright (c) 2012, Factual

Setup:
  $0 --check   (this will install your OAuth credentials)

Queries:
  $0 [--fetch] table-name
    [-q|--query "query"]
    [-l|--limit n]
    [-f|--filter filter-json]
  $0 --schema table-name
  $0 --examples
EOF
  return 0
}

factual-check-dependencies() {
  factual-check-dependency curl &&
  factual-check-dependency openssl &&
  factual-check-dependency base64 || return $?

  echo -n "issuing test query... "
  if factual-request GET /t/places "q=starbucks" "limit=0" > /dev/null; then
    echo -e "\033[1;32mthe query worked!\033[0;0m"
  else
    echo -e "\033[1;31mfailed\033[0;0m"
    [[ -z "$factual_verbose" ]] &&
      echo -e "Try \033[1;33m$0 --verbose --check\033[0;0m to see what went wrong."
    return 1
  fi
}

factual-fetch() {
  local params=()
  local table_name="$1"
  shift

  while (( $# )); do
    option="$1"
    shift

    case "$option" in
      -q|--query) params[${#params[@]}]="$(OAuth_param q "$1")"; shift ;;
      -l|--limit) params[${#params[@]}]="$(OAuth_param limit "$1")"; shift ;;
      -f|--filter) params[${#params[@]}]="$(OAuth_param filter "$1")"; shift ;;
      *)
        factual-say "unknown fetch option $option" \
                    "fetch accepts --query, --limit, and --filter"
        return 1
    esac
  done

  factual-request GET /t/$table_name ${params[@]}
}

factual-main() {
  if [[ $# == 0 ||
        $1 == '--usage' ||
        $1 == '-?' ||
        $1 == '--help' ||
        $1 == '-h' ]]; then
    factual-usage
    return 0
  fi

  local action=fetch
  factual-load-key || return $?

  while :; do
    if [[ "$1" == "${1##-}" ]]; then
      # We're done parsing global options once we see the first bareword.
      break
    fi

    local option=$1
    shift
    case $option in
      -v|--verbose) factual_verbose=-v ;;

      --check)  action=check-dependencies; break ;;
      --fetch)  action=fetch;              break ;;
      --schema) action=schema;             break ;;
      *)
        factual-say "unknown action $1 (use --help for available actions)"
        return 1
    esac
  done

  factual-$action "$@"
}

factual_verbose=
factual_hostname=api.v3.factual.com

factual-main "$@"
