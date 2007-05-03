#!/bin/sh
#
# $Id: functions.sh,v 1.7 2007/05/03 03:40:27 cph Exp $
#
# Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
#     1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004,
#     2005, 2006, 2007 Massachusetts Institute of Technology
#
# This file is part of MIT/GNU Scheme.
#
# MIT/GNU Scheme is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# MIT/GNU Scheme is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with MIT/GNU Scheme; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301, USA.

# Functions for shell scripts.

maybe_mkdir ()
{
    if [ ! -e "${1}" ]; then
	echo "mkdir ${1}"
	mkdir "${1}"
    fi
}

maybe_link ()
{
    if [ ! -e "${1}" ] && [ ! -L "${1}" ]; then
	echo "ln -s ${2} ${1}"
	ln -s "${2}" "${1}"
    fi
}

maybe_unlink ()
{
    if [ -L "${1}" ] && [ "${1}" -ef "${2}" ]; then
	echo "rm ${1}"
	rm "${1}"
    fi
}

maybe_rm ()
{
    FNS=
    DIRS=
    for FN in "${@}"; do
	if [ ! -L "${FN}" ]; then
	    if [ -f "${FN}" ]; then
		FNS="${FNS} ${FN}"
	    elif [ -d "${FN}" ]; then
		DIRS="${DIRS} ${FN}"
	    fi
	fi
    done
    if [ "${FNS}" ]; then
	echo "rm -f ${FNS}"
	rm -f ${FNS}
    fi
    if [ "${DIRS}" ]; then
	echo "rm -rf ${DIRS}"
	rm -rf ${DIRS}
    fi
}
