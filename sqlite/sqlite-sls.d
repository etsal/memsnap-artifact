#!/usr/sbin/dtrace -s

#pragma D option quiet
int memsnap_start;

fbt::slsckpt_dataregion:entry
/pid == $1/
{
    memsnap_start = timestamp;
    @tcnt["memsnap-count"] = count()
}

fbt::slsckpt_dataregion:return
/pid == $1/
{
    @tavg["memsnap"] = avg(timestamp - memsnap_start);
}


END
{
    printa(@tavg);
    printa(@tcnt);
}
