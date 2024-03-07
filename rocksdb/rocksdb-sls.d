#!/usr/sbin/dtrace -s

#pragma D option quiet
self uint64_t start, current;

fbt::slsckpt_dataregion:entry
{
    self->start = self->current = timestamp;
    @tcnt["memsnap"] = count();
}

fbt::slsckpt_dataregion:return
{
    @tavg["memsnap"] = avg(timestamp - self->current);
}

sls:::enter
{
    @tavg["enter"] = avg(timestamp - self->current);
    self->current = timestamp;	
}

sls:::cow
{
    @tavg["cow"] = avg(timestamp - self->current);
    self->current = timestamp;	
}

sls:::write
{
    @tavg["write"] = avg(timestamp - self->current);
    self->current = timestamp;	
}

sls:::wait
{
    @tavg["wait"] = avg(timestamp - self->current);
    self->current = timestamp;	
}

sls:::cleanup
{
    @tavg["cleanup"] = avg(timestamp - self->current);
    self->current = timestamp;	
}

sas:::start
{
    self->current = self->start = timestamp;
    @tavg["tracked"] = avg(arg0);
    @tavg["removed"] = avg(arg1);
    @tavg["attempted"] = avg(arg2);
    @tavg["copied"] = avg(arg3);

    @tcnt["sas-count"] = count();
}

sas:::protect
{
    @tavg["protect"] = avg(timestamp - self->current);
    self->current = timestamp;
}

sas:::write
{
    @tavg["write"] = avg(timestamp - self->current);
    @tsum["pages-total"] = sum(arg0);
    @tavg["pages"] = avg(arg0);
    self->current = timestamp;
}

sas:::block
{
    @tavg["block"] = avg(timestamp - self->current);
    self->current = timestamp;

    @tavg["sas"] = avg(timestamp - self->start);
}

END
{
    printa(@tavg);
    printa(@tcnt);
    printa(@tsum);
}
