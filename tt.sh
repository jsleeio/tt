#!/bin/bash

_top_dir="$HOME/tt"
_title_file=".tt_title"
_date_file=".tt_date"
_done=".tt_done"

_die() {
  echo "tt: fatal: $*" > /dev/stderr
  exit 1
}

_init() {
  if ! [ -d "$_top_dir" ] ; then
    mkdir -p "$_top_dir" || _die "_init failed"
  fi
}

_id() {
  echo "$$.$USER.$(date +%s).$RANDOM.$*" | openssl sha -sha256 | cut -b 1-6
}

_enter_current_or_arg() {
  local dir
  if [ -n "$1" ] ; then
    dir="$_top_dir/$1"
  else
    if [ -n "$TTID" ] ; then
      dir="$_top_dir/$TTID"
    else
      _die "not in a bucket and no bucket specified"
    fi
  fi
  cd "$dir" || _die "can't chdir: $dir"
}

_home() {
  _enter_current_or_arg "$1"
  pwd
}

_title() {
  _enter_current_or_arg "$1"
  local title
  read -r title < "$_title_file"
  echo "$title"
}

_date() {
  _enter_current_or_arg "$1"
  local date
  read -r date < "$_date_file"
  echo "$date"
}

_done() {
  _enter_current_or_arg "$1"
  touch "$_done"
}

_keep() {
  _enter_current_or_arg "$1"
  rm -f "$_done"
}

_shell() {
  _enter_current_or_arg "$1"
  export TTID="$1"
  export HISTFILE="$_top_dir/$1/.history"
  shift
  local _c
  if [ -n "$1" ] ; then
    local _c="-c"
  fi
  exec "$SHELL" $_c "$@"
}

_exec() {
  _enter_current_or_arg "$1"
  export TTID="$1"
  shift
  exec "$@"
}

_finder() {
  _enter_current_or_arg "$1"
  open .
}

_gc() {
  cd "$_top_dir" || die "can't chdir: $_top_dir"
  _ls | awk '$3 == "Y" { print $2 }' | while read -r id ; do
    rm -vrf "$id"
  done
}

_findercomment() {
  (
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0">'
    echo "<string>$*</string>"
    echo '</plist>'
  ) \
    | plutil -convert binary1 -o - - \
    | xxd -ps -
}

_new() {
  local id dir
  id="$(_id "$@")"
  dir="$_top_dir/$id"
  mkdir -p "$dir" || _die "_new failed: $dir"
  echo "$*" > "$dir/$_title_file"
  xattr -wx "com.apple.metadata:kMDItemFinderComment" "$(_findercomment "$*")" "$dir"
  date +%F > "$dir/$_date_file"
  _shell "$id"
}

_ls() {
  local tab a 'done' id title date
  tab="$(printf '\t')"
  a='[a-f0-9]'
  (
    printf 'DATE\tID\tDONE\tTITLE\n' ;
    find "$_top_dir" -type d -maxdepth 1 -mindepth 1 -name "$a$a$a$a$a$a" | \
      while read -r dir ; do
        id="$(basename "$dir")"
        title="$(_title "$id")"
        date="$(_date "$id")"
        done="N"
        if [ -f "$_top_dir/$id/$_done" ] ; then
          done="Y"
        fi
        printf '%s\t%s\t%s\t%s\n' "$date" "$id" "$done" "$title"
      done | sort -n 
  ) | column -ts "${tab}"
}

_help() {
  printf 'usage: create a new bucket\n\n'
  printf '\ttt new "title for new bucket"\n\n'
  printf 'usage: list buckets\n\n'
  printf '\ttt ls\n\n'
  printf 'usage: get bucket metadata. Current bucket, if no ID specified.\n\n'
  printf '\ttt (title|date|home) [id]\n\n'
  printf 'usage: do something with a bucket. Current bucket, if no ID specified.\n\n'
  printf '\ttt (finder|shell|done|exec) [id]\n\n'
  printf 'usage: garbage-collect all "done" buckets\n\n'
  printf '\ttt gc\n'
}

_init


case "$1" in
  new|finder|shell|ls|'done'|keep|gc|title|date|'exec'|home)
    cmd="$1"
    shift
    "_${cmd}" "$@"
  ;;
  version)
    echo 'tt 2.0'
    exit 0
  ;;
  help)
    _help
  ;;
  *)
    _help
    exit 1
  ;;
esac
