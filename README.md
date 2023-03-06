# 予定 (Yotei)

A minimal job scheduler and process supervisor for Linux.

Learn how to config Yotei and what file formats it uses in CONFIG_FORMATS.md

## internal notes and things

All times are represented internally in UTC for simplicity.

All internal state lives on the event loop thread.
If you need to do something that uses global state (e.g. working with tasks)
you should use `queueTask()` to run the relevant code on the event loop thread
(due to message passing this will unblock the thread if it is sleeping).