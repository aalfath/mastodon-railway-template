#!/bin/sh
# Print the base64 tar.gz blob for the Railway start commands.
set -e
cd "$(dirname "$0")"
tar --owner=0 --group=0 --numeric-owner --mtime=@0 -cf - start.sh bootstrap.rb media.ru | gzip -n | base64 -w0
echo
