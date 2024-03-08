#!/usr/sbin/dtrace -s

#pragma D option quiet
int memsnap_start;

fbt::slsfs_sas_trace_commit:entry
/pid == $1/
{
    self->start = timestamp;
    @tcnt["memsnap-count"] = count()
}

fbt::slsfs_sas_trace_commit:return
/pid == $1/
{
    @tavg["memsnap"] = avg(timestamp - self->start);
}


END
{
    printa(@tavg);
    printa(@tcnt);
}
