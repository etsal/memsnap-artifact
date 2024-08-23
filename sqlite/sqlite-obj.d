#!/usr/sbin/dtrace -s

#pragma D option quiet
self uint64_t start, current;

sas:::start
{
    self->current = self->start = timestamp;
    @tavg["tracked"] = avg(arg0);
    @tavg["removed"] = avg(arg1);
    @tavg["attempted"] = avg(arg2);
    @tavg["copied"] = avg(arg3);

    @tcnt["objsnap-count"] = count();
}

sas:::protect
{
    @tavg["protect"] = avg(timestamp - self->current);
    self->current = timestamp;
}

sas:::write
{
    @tsum["pages-total"] = sum(arg0);
    @tavg["pages"] = avg(arg0);

    @tavg["block"] = avg(timestamp - self->current);
    @tavg["objsnap"] = avg(timestamp - self->start);
}

END
{
    printa(@tavg);
    printa(@tcnt);
    printa(@tsum);
    printf("PID\t\t%d\n", $1);
}
