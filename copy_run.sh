#!/bin/sh

USERNAME=${USERNAME-"root"}
HOST=${HOST-"fd56:b4dc:4b1e::1"}
IDENTITY=${IDENTITY-"$HOME/.ssh/freifunk_rsa"}
TARGET=${TARGET-"~"}

COPY="scp -q -i $IDENTITY $1 $USERNAME@$HOST:$TARGET"
RUN="ssh -q -i $IDENTITY $USERNAME@$HOST $TARGET/$1 ${*:2}"

printf "."
$COPY
printf "\r:\n"
$RUN
