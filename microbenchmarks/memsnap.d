#!/usr/sbin/dtrace -s

#pragma D option quiet
int tsstart, tsenter, tscow, tswrite, tswait, tsend;

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

sls:::write
{
    tswrite = timestamp;
    @tavg["creating IO "] = avg(tswrite - tscow);
}

sls:::wait
{
    tswait = timestamp;
    @tavg["write IO"] = avg(tswrite - tswrite);
}

sls:::cleanup
{
    tsend = timestamp;
    @tavg["shadow collapse"] = avg(tsend - tswait);
    @tavg["Total"] = avg(tsend - tsenter);
}

fbt::sls_memsnap:entry
{
	self->msnp = timestamp;

}

sls:::enter
{
    @tavg["before dataregion"] = avg(timestamp - self->msnp);
}

fbt::sls_memsnap:return
{
    	@tavg["memsnap"] = avg(timestamp - self->msnp);

}
END
{
    printa(@tavg);
}
