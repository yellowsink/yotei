# Using Yotei: Configuring & File Formats

A documentation of how to use all the file formats Yotei uses.

## `/etc/yotei/tasks`

This file is a YAML format with the following structure:

Note: `?` = optional.

root (task[])

task:
 - id (string): a UNIQUE and optionally human-readable identifier for the task
 - run (string): a bash script to run
 - condition (string)?: if exists, runs as a bash script,
   and the run only happens if it returns a 0 exit code
 - every (interval)?: how often to run the task
 - once (date)?: when to run a task
 - at (time)?: an offset from when the task would otherwise run.
   Cannot be more than the interval size if using `every`,
   or one day if using `once`
 - scheduleRule (srule)?: How to handle a task that was due to run but wasnt.
 - as (string)?: the user to run the script as.

### Intervals (`every`)

An integer followed by a keyword.
Keywords are years, months, weeks, days, hours, minutes, seconds.

You can chain more than one of these, and they sum.

You may not use years & months with weeks/days/hours/minutes/seconds.

This is because using years / months requires awareness of the calendar,
and mixing both is technically difficult.

### `once` and `every`
**Only one** of these two can be supplied at once, else the tasks file is invalid.

If `every` is supplied, the job will run whenever the interval specifies.

If `once` is supplied, the task will run on that day (at the specified offset if given)
and then Yotei will make sure it does not run again.

### Schedule rules (`scheduleRule`)

This has three possible values:
 - `drop`: if the task did not run for whatever reason at the set time
   (e.g. Yotei was not running, the system was shut down) then drop the task
   and don't run it at all
 - `single`: if the task did not run one or more times,
   run it once at the next convenience of Yotei.
 - `always`: if the task did not run one or more times,
   run it once for every time it should have ran but did not.

Single is the default.

Always is useful if you have a task where it doesn't matter so much *if* it
runs at that given time, but rather *how many times* it runs in a larger time
period.

Do note that always can be dangerous: if you turn your system off for the night
and have a task set to run every second, when you get back its gonna run that
task a *LOT*.

Maybe only use this one on high uptime e.g. server environments.

Always cannot be used with `once`. Doing this will make the config invalid.

### `as`

The `as` key defines the username of who the task should be ran as.

If Yotei is running as root, this field MUST be provided.

If Yotei is running as a user (`--user`), this field MUST NOT be provided.

## `/etc/yotei/internal`

You do NOT need to know about this to use Yotei.

This is the file Yotei uses to store internal state in.

It is a raw binary file with a structure defined in the comments in `internalcoding.d`
[here](https://github.com/yellowsink/yotei/blob/master/daemon/source/internalcoding.d#L5-L8).

This binary format is expected to be consistent *between point releases* - that is,
released versions of Yotei won't break when encountering a file written *by an older version of*
Yotei.

If you mess with this EXPECT Yotei to break.