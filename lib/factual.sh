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

factual-fetch-usage() {
    factual-say \
        "usage: $0 [--fetch] table-name [options]" \
        "where [options] is one or more of:" \
        "  -q|--query 'text'    full-text search over results" \
        "  -f|--filters 'json'  Mongo-style JSON object for result filtering" \
        "  -g|--geo 'json'      Mongo-style JSON object for geo filtering" \
        "  -c|--count           include count of all rows matching the query" \
        "  -l|--limit n         maximum number of rows to return" \
        "  -o|--offset n        start index of rows (useful for paging)" \
        "  -s|--sort column:asc|desc" \
        "  -S|--select fields|* which fields to select (defaults to all)" \
        "" \
        "See http://developer.factual.com/display/docs/Core+API+-+Read for more" \
        "details about these options." \
        "" \
        "For example:" \
        "  $0 --fetch places -q starbucks --limit 10 --sort name:asc"
}

factual-fetch() {
  local params=()
  local table_name="$1"
  shift

  while (( $# )); do
    option="$1"
    shift

    case "$option" in
      -q|--query)   params[${#params[@]}]="$(OAuth_param q "$1")"; shift ;;
      -f|--filters) params[${#params[@]}]="$(OAuth_param filters "$1")"; shift ;;
      -g|--geo)     params[${#params[@]}]="$(OAuth_param geo "$1")"; shift ;;
      -c|--count)   params[${#params[@]}]="$(OAuth_param include_count true)" ;;
      -l|--limit)   params[${#params[@]}]="$(OAuth_param limit "$1")"; shift ;;
      -o|--offset)  params[${#params[@]}]="$(OAuth_param offset "$1")"; shift ;;
      -s|--sort)    params[${#params[@]}]="$(OAuth_param sort "$1")"; shift ;;
      -S|--select)  params[${#params[@]}]="$(OAuth_param select "$1")"; shift ;;

      *)
        factual-say "\033[1;31mnknown fetch option $option\033[0;0m"
        factual-fetch-usage
        return 1
    esac
  done

  factual-request GET /t/$table_name ${params[@]}
}

factual-facets-usage() {
  echo "TODO: write a Facets usage function"
}

factual-facets() {
  if (( $# < 2 )); then
    factual-say "\033[1;31mfacets requires at least two options\033[0;0m"
    factual-facets-usage
    return 1
  fi

  local params=()
  local table_name="$1"
  local selected_fields="$2"
  shift 2

  while (( $# )); do
    option="$1"
    shift

    case "$option" in
      -f|--filters)   params[${#params[@]}]="$(OAuth_param filters "$1")"; shift ;;
      -g|--geo)       params[${#params[@]}]="$(OAuth_param geo "$1")"; shift ;;
      -c|--count)     params[${#params[@]}]="$(OAuth_param include_count true)" ;;
      -l|--limit)     params[${#params[@]}]="$(OAuth_param limit "$1")"; shift ;;
      -m|--min-count) params[${#params[@]}]="$(OAuth_param min_count "$1")"; shift ;;
      -q|--query)     params[${#params[@]}]="$(OAuth_param q "$1")"; shift ;;

      *)
        factual-say "\033[1;31munknown facets option $option\033[0;0m"
        factual-facets-usage
        return 1
    esac
  done

  factual-request GET /t/$table_name/facets "select=$selected_fields" ${params[@]}
}

factual-resolve-usage() {
  factual-say \
      "usage: $0 --resolve name1 value1 [name2 value2 ...]" \
      "See http://developer.factual.com/display/docs/Places+API+-+Resolve for" \
      "more information about the Resolve API." \
      "" \
      "For example:" \
      "  $0 --resolve name 'McDonalds' address '10451 Santa Monica Blvd'"
}

factual-resolve() {
  if (( $# % 2 )); then
    factual-say "\033[1;31mresolve must have an even number of arguments\033[0;0m"
    factual-resolve-usage
    return 1
  fi

  local values_json=
  while (( $# )); do
    if (( $# % 2 )); then
      values_json="$values_json\"$(echo "$1" | sed 's/"/\\"/g')\""
    else
      values_json="$values_json,\"$1\":"
    fi
    shift
  done

  factual-request GET /places/resolve "$(OAuth_param values "{${values_json:1}}")"
}

factual-schema() {
  if (( $# )); then
    factual-say \
        "\033[1;31musage: $0 --schema table-name\033[0;0m" \
        "For example:" \
        "  $0 --schema restaurants-us"
    return 1
  fi

  local table_name="$1"
  factual-request GET /t/$table_name/schema
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

      --check)   action=check-dependencies; break ;;
      --fetch)   action=fetch;              break ;;
      --facets)  action=facets;             break ;;
      --resolve) action=resolve;            break ;;
      --schema)  action=schema;             break ;;

      *)
        factual-say "unknown action $option (use --help for available actions)"
        return 1
    esac
  done

  factual-$action "$@"
}

factual_verbose=
factual_hostname=api.v3.factual.com

factual-main "$@"
