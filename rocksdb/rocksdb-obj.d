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

fbt::allocate_txn_block:entry
{
	self->allocate = timestamp;
}

fbt::allocate_txn_block:return
{
	@tavg["allocation"] = avg(timestamp - self->allocate);
}

fbt::objsnap_io:entry
{
	self->firstio = timestamp;
}

fbt::objsnap_io:return
{
	@tavg["firstio"] = avg(timestamp - self->firstio);
}

fbt::objsnap_wal_log:entry
{
	self->wal = timestamp;
}

fbt::objsnap_wal_log:return
{
	@tavg["wal"] = avg(timestamp - self->wal);
}

fbt::ca_gc:entry
{
	self->gc = timestamp;
}

fbt::ca_gc:return
{
	@tavg["gc"] = avg(timestamp - self->gc);
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
}
