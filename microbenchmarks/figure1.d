#!/usr/sbin/dtrace -s

#pragma D option quiet
int tsstart, tsenter, tscow, tsend;

fbt::slsvm_entry_shadow_single:entry
{
	self->trace = 1;
	self->total = 0;
	self->shadowstart = timestamp;
}

fbt::slsvm_entry_shadow_single:return
{
	self->trace = 0;
    	@tavg["protect"] = avg(self->total);
	self->total = 0;

    	@tavg["shadow"] = avg(timestamp - self->shadowstart);
}

sls:::protstart, fbt::slsvm_entry_protect:entry, fbt::slsvm_tracebuf_invalidate:entry
/ self->trace == 1 /
{
   	self->start = timestamp;
}

sls:::protend, fbt::slsvm_entry_protect:return, fbt::slsvm_tracebuf_invalidate:return
/ self->trace == 1 /
{
	self->total += timestamp - self->start;
	self->start = 0;
}

END
{
	printa(@tavg);
}
