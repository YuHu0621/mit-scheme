#!/bin/sh
#
# $Id: Stage.sh,v 1.3 2001/10/09 21:17:25 cph Exp $
#
# Copyright (c) 2000, 2001 Massachusetts Institute of Technology
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.

# Utility for MIT Scheme compiler staging.

if [ $# -ne 2 ]; then
    echo "usage: $0 <command> <tag>"
    exit 1
fi

DIRNAME="STAGE${2}"

case "${1}" in
make)
    mkdir "${DIRNAME}" && mv -f *.com *.bci "${DIRNAME}/."
    ;;
unmake)
    mv -f "${DIRNAME}"/* . && rmdir "${DIRNAME}"
    ;;
remove)
    rm -rf "${DIRNAME}"
    ;;
copy)
    cp "${DIRNAME}"/* .
    ;;
link)
    ln "${DIRNAME}"/* .
    ;;
*)
    echo "$0: Unknown command ${1}"
    exit 1
    ;;
esac
