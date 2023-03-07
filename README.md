# 予定 (Yotei)

A minimal job scheduler and process supervisor for Linux.

Learn how to config Yotei and what file formats it uses in CONFIG_FORMATS.md

## internal notes and things

All times are represented internally in UTC for simplicity.

## Security

In writing Yotei, all due care has been taken to make it safe and secure enough
for you to be comfortable running as root on your system in the background,
and D as a language avoids many pitfalls of languages like C, but that said:

From a mix of "it'll be fine" and convenience this software does some suspicious things
(a couple binary type casts - don't worry, just numbers not full structs and stuff - and
using environment variables in paths).

If you find a vulnerability in Yotei, based on this sort of thing, or else,
please do not hesitate to get in touch via any channel, preferably issues or [email](mailto:yellowsink@riseup.net).