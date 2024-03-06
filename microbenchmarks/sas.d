#!/usr/sbin/dtrace -s

#pragma D option quiet

int tsstart, tsprotect, tswrite, tsblock, tsend;

sas:::start
{
	tsstart = timestamp;
}

sas:::protect
{
	tsprotect = timestamp;
	@tavg["Resetting tracking"] = avg(tsprotect - tsstart);
}

sas:::write
{
	tswrite = timestamp;
	@tavg["Initiating Writes"] = avg(tswrite - tsprotect);
}

sas:::block
{
	tsblock = timestamp;
	@tavg["Waiting on IO"] = avg(tsblock - tswrite);
}

fbt::slsfs_sas_trace_commit:return
{
	tsend = timestamp;
	@tavg["Total"] = avg(tsend - tsstart);
}

END
{
    printf("Numbers in ns:\n");
    printa(@tavg);
}
