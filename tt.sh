#!/bin/bash

_top_dir="$HOME/tt"
_title_file=".tt_title"
_date_file=".tt_date"
_done=".tt_done"
_tags_dir=".tt_tags"

_die() {
  echo "tt: fatal: $*" > /dev/stderr
  exit 1
}

_is_macos() {
  [ "$(uname -s)" == "Darwin" ]
}

_init() {
  if ! [ -d "$_top_dir" ] ; then
    mkdir -p "$_top_dir" || _die "_init failed"
  fi
}

_id() {
  echo "$$.$USER.$(date +%s).$RANDOM.$*" \
    | openssl sha256 -r -hex \
    | cut -b 1-6
}

_find() {
  # have to be careful here to handle $_top_dir that might have
  # spaces in it. I *think* this approach is relatively safe
  # (can you have null chars in a unix path?)
  find "$_top_dir" -maxdepth 2 -type f -name .tt_title -print0 \
    | while read -d $'\000' titlefile ; do 
        if grep -q "$1" "$titlefile" ; then
          basename "$(dirname "$titlefile")"
        fi
      done
}

_try_id() {
  if [[ "$1" =~ ^:{1}([a-f0-9]{6})$ ]] ; then
    echo "${BASH_REMATCH[1]}"
    true
  else
    false
  fi
}

_enter_current_or_arg() {
  local dir id
  id="$(_try_id "$1" || _try_id "$TTID")"
  if ! [ "$?" == 0 ] ; then
    _die "must be in a bucket shell or specify an ID of the form :abcdef"
  fi
  dir="$_top_dir/$id"
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
  export HISTFILE="$_top_dir/${TTID:1}/.history"
  shift
  local _c
  if [ -n "$1" ] ; then
    local _c="-c"
  fi
  echo -n "$TTID" > "$_top_dir/last"
  exec "$SHELL" $_c "$@"
}

_readlast() {
  local _last=""
  read -r _last < "$_top_dir/last"
  echo "$_last"
}

_last() {
  local _last
  _last=$(_readlast)
  _shell "$_last" "$@"
}

_exec() {
  _enter_current_or_arg "$1"
  export TTID="$1"
  shift
  exec "$@"
}

_finder() {
  _is_macos || _die "this command only makes sense on macOS"
  _enter_current_or_arg "$1"
  open .
}

_gc() {
  cd "$_top_dir" || die "can't chdir: $_top_dir"
  local _last
  _last=$(_readlast | tr -d ':')
  _ls | awk '$3 == "Y" { print $2 }' | while read -r id ; do
    if [ "$id" = "$_last" ] ; then
      echo "gc: not collecting most-recently-used bucket: $id"
      continue
    fi
    rm -vrf "$id"
  done
}

_findercomment() {
  _is_macos || _die "this command only makes sense on macOS"
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
  mkdir -p "$dir/$_tags_dir" || _die "_new failed: $dir"
  echo "$*" > "$dir/$_title_file"
  _is_macos && xattr -wx "com.apple.metadata:kMDItemFinderComment" "$(_findercomment "$*")" "$dir"
  date +%F > "$dir/$_date_file"
  _shell ":$id"
}

_tag() {
  _enter_current_or_arg "$1"
  shift
  mkdir -p "$_tags_dir" || _die "failed creating tags directory: $_tags_dir"
  # FIXME: implement macOS tagging too
  cd "$_tags_dir"       || _die "can't chdir tags directory: $_tags_dir"
  touch -- "$@"
  cd ..
}

_tags() {
  _enter_current_or_arg "$1"
  mkdir -p "$_tags_dir" || _die "failed creating tags directory: $_tags_dir"
  cd "$_tags_dir"       || _die "can't access tags directory: $_tags_dir"
  /bin/ls -1 | sort
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
        read -r title < "$_top_dir/$id/$_title_file"
        read -r date < "$_top_dir/$id/$_date_file"
        done="N"
        if [ -f "$_top_dir/$id/$_done" ] ; then
          done="Y"
        fi
        printf '%s\t%s\t%s\t%s\n' "$date" "$id" "$done" "$title"
      done | sort -n 
  ) | column -ts "${tab}"
}

_newgo() {
  _enter_current_or_arg "$1"
  if [[ $# -gt 1 ]] ; then
    shift
  fi
  local id=""
  if ! id="$(basename "$(pwd)")" ; then
    _die "can't find bucket ID, halp"
  fi
  local name="$1"
  local base=""
  if [[ -z "$name" ]] ; then
    _die "newgo: must supply an unqualified module name"
  fi
  local prefix_file="$_top_dir/newgo-prefix"
  if ! prefix="$(cat "$prefix_file")" ; then
    _die "please put a go module prefix like github.com/jsleeio/tt/go in $prefix_file"
  fi
  mkdir "$name" && cd "$name" || _die "can't create Go module directory, halp"
  go mod init "$(echo "$prefix" | sed 's,/$,,')/$id/$name"
}

_help() {
  printf 'usage: create a new bucket\n'
  printf '\ttt new "title for new bucket"\n\n'
  printf 'usage: list buckets\n'
  printf '\ttt ls\n\n'
  printf 'usage: start a shell in a bucket\n'
  printf '\ttt shell :id\n\n'
  printf 'usage: start a shell in the last-accessed bucket\n'
  printf '\ttt last\n\n'
  printf 'usage: apply tags to a bucket\n'
  printf '\ttt tag :id tag1 [tag2 [..tagN]]\n\n'
  printf 'usage: get bucket metadata. Current bucket, if no ID specified.\n'
  printf '\ttt (title|date|home) [:id]\n\n'
  printf 'usage: garbage-collect all "done" buckets\n'
  printf '\ttt gc\n'
}

_init

if [[ "$#" -lt 1 ]] ; then
  _help
  exit 1
fi

word="$1"
shift

case "$word" in
  completion)
    words='date done exec find finder gc help home keep'
    words="$words last ls new newgo shell tag"
    words="$words tags title version"
    echo "$words"
  ;;
  new|finder|find|shell|last|ls|'done'|keep|gc|title|date|'exec'|home|newgo|tag|tags)
    "_${word}" "$@"
  ;;
  version)
    echo 'tt 2.7'
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
