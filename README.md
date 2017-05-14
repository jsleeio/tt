# tt

## overview

Tool to help you stash (and rediscover!) those temporary files you just need to
put somewhere for a while... Also gives you per-stash shell history if your
shell respects the `$HISTFILE` environment variable, so can be used as a
context-switching aid.

Has a few OSX/macOS-specific features, but the rest should work just fine on
Linux.

Clean-room, improved reimplementation of a tool I implemented while working at
`$a_previous_employer`.

## tasks

### installation

    $ git clone ...
    $ cp tt/tt.sh /usr/local/bin/tt

### help

    $ tt help

### general usage

    $ tt command [:bucket_id]

Most tasks assume that you want to work on the current bucket if you don't
supply a bucket ID.

If you do need to specify a bucket ID, prefix it with a colon, as above.

### create a bucket

    $ tt new 'some random crap'

What just happened here?

1. `$HOME/tt` was created if it didn't exist already (edit the source to change
   this; PRs for config files accepted :-])
2. a SHA256 hash of _(title+date+otherdata)_ was calculated; this is the bucket
   ID
3. `$TTID` is set to the bucket ID
4. `$HOME/tt/$TTID` was created
5. `$HISTFILE` is set to a file inside the bucket
6. a subshell (`$SHELL`) is spawned
7. (macOS/OSX only) the bucket directory has the comment field set to the
   bucket title

```
    $ tt home
    /your/home/tt/4ced50

    $ echo $TTID
    4ced50
```

And if on macOS/OSX, the bucket is discoverable with Spotlight, eg. via
commandline:

    $ mdfind 'kMDItemFinderComment == foo'
    /my_home/tt/4ced50

Exit your shell as per normal when you're done.

### tagging a bucket

    $ tt tag :bucket_id foo bar baz

### displaying bucket tags

    $ tt tags
    bar
    baz
    foo

### listing buckets

    $ tt ls
    DATE        ID      DONE  TITLE
    2017-05-11  4ced50  N     foo

### re-entering an existing bucket

    $ tt shell :4ced50

### marking a bucket for garbage collection

    $ tt done :4ced50

Note the change in the DONE column:

    $ tt ls
    DATE        ID      DONE  TITLE
    2017-05-11  4ced50  Y     foo

### changing your mind

    $ tt keep :4ced50

### display in macOS/OSX Finder

    $ tt finder

### garbage collection

    $ tt gc
    4ced50/.history
    4ced50/.tt_date
    4ced50/.tt_done
    4ced50/.tt_title
    4ced50

## ideas

I will keep refining this. I'm particularly interested in improving integration
with macOS/OSX Finder and Spotlight.

PRs welcomed. 

### shell completion

Probably wouldn't be difficult?

### tagging

Create a subdirectory in a bucket and store tags in there as empty files? Also
if running on macOS/OSX, apply matching native file tagging so the tags can be
  used with Finder/Spotlight.

