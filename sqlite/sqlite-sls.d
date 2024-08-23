#!/usr/sbin/dtrace -s

#pragma D option quiet
int memsnap_start;

fbt::slsfs_sas_trace_commit:entry
{
    self->start = timestamp;
    @tcnt["memsnap-count"] = count()
}

fbt::slsfs_sas_trace_commit:return
{
    @tavg["memsnap"] = avg(timestamp - self->start);
}


END
{
    printa(@tavg);
    printa(@tcnt);
    printf("PID\t\t%d\n", $1);
}
