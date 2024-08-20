#!/usr/sbin/dtrace -s

#pragma D option quiet

int tsstart, tsprotect, tswrite, tsblock, tsend;

sas:::start
{
	self->tsstart = timestamp;
}

sas:::protect
{
	self->tsprotect = timestamp;
	@tavg["Resetting tracking"] = avg(self->tsprotect - self->tsstart);
}

sas:::write
{
	self->tswrite = timestamp;
	@tavg["Initiating Writes"] = avg(self->tswrite - self->tsprotect);
}

sas:::block
{
	self->tsblock = timestamp;
	@tavg["Waiting on IO"] = avg(self->tsblock - self->tswrite);
}

fbt::slsfs_sas_trace_commit:return
{
	self->tsend = timestamp;
	@tavg["Total"] = avg(self->tsend - self->tsstart);
}

END
{
    printf("Numbers in ns:\n");
    printa(@tavg);
}
