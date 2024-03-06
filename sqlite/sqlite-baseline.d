#!/usr/sbin/dtrace -s

#pragma D option quiet
int timestart;

BEGIN {
	timestart = timestamp;
}

syscall::read:entry
/pid == $1/
{
    timestart = timestamp;
}

syscall::read:return
/pid == $1/
{
	@tavg["read"] = avg(timestamp - timestart);
	@tcnt["read-count"] = count();
}

syscall::write:entry
/pid == $1/
{
    timestart = timestamp;
}

syscall::write:return
/pid == $1/
{
	@tavg["write"] = avg(timestamp - timestart);
	@tcnt["write-count"] = count();
}

syscall::fsync:entry
/pid == $1/
{
    timestart = timestamp;
}

syscall::fsync:return
/pid == $1/
{
	@tavg["fsync"] = avg(timestamp - timestart);
	@tcnt["fsync-count"] = count();
}

syscall::ioctl:entry
/pid == $1/
{
    timestart = timestamp;
}

syscall::ioctl:return
/pid == $1/
{
	@tavg["memsnap"] = avg(timestamp - timestart);
	@tcnt["memsnap-count"] = count();
}

END
{
    printa(@tavg);
    printa(@tcnt);
}
