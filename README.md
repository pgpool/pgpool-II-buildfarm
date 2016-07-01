# pgpool-II buildfarm

buildfarm script for pgpool-II

## Usage

### 1. Make a work directory

Set the directory name to SRCDIR in buildfarm.sh. The default is:

    SRCDIR=/var/buildfarm

### 2. Get pgpool-II-buildfarm from github.

Run git clone at the $SRCDIR.

This is avalable from
<https://github.com/pgpool/pgpool-II-buildfarm>

For example:

    $ cd /var/buildfarm
    $ git clone https://github.com/pgpool/pgpool-II-buildfarm.git

### 3. Mail address configuration

Specify the e-mail address to send the result and the sender address to MAILTO and FROM.

    MAILTO=pgpool-buildfarm@your.hostname
    FROM=buildfarm@your.hostname

### 4. Configure cron to run buildfarm.sh and clean.sh periodically
