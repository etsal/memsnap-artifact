#!/usr/sbin/dtrace -s

#pragma D option quiet
int tsstart, tsenter, tscow, tsend;

fbt::slsckpt_dataregion:entry
{
    tsstart = timestamp;
}

sls:::enter
{
    tsenter = timestamp;
    @tavg["stopping threads"] = avg(tsenter - tsstart);
}

sls:::cow
{
    tscow = timestamp;
    @tavg["shadow creation"] = avg(tscow - tsenter);
}

sls:::wait
{
    tswrite = timestamp;
    @tavg["write IO"] = avg(tswrite - tscow);
}

sls:::cleanup
{
    tswrite = timestamp;
    @tavg["shadow collapse"] = avg(tswrite - tscow);
    @tavg["Total"] = avg(tswrite - tsenter);
}

END
{
    printa(@tavg);
}
