# NAME

App::blacklistrm - something like "blacklistctl remove"

# SYNOPSIS

    use App::blacklistrm;
    App::blacklistrm->run;

# DESCRIPTION

- depends on the output of blacklistctl dump -aw.
- blacklistd is suspended while processing.
- sysrc blacklistd\_flags="-r" to re-read db.
- twists blacklist.db to remove entries.

# AUTHOR

KUBO, Koichi <k@obuk.org>
