#!/usr/sbin/dtrace -s

#pragma D option quiet
int timestart;

BEGIN {
	timestart = timestamp;
}

syscall::write:entry
{
    timestart = timestamp;
}

syscall::write:return
{
	@tavg["write"] = avg(timestamp - timestart);
	@tcnt["write-count"] = count();
}

syscall::fsync:entry
{
    timestart = timestamp;
}

syscall::fsync:return
{
	@tavg["fsync"] = avg(timestamp - timestart);
	@tcnt["fsync-count"] = count();
}

END
{
    printa(@tavg);
    printa(@tcnt);
}
