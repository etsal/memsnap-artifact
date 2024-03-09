self uint64_t start, current;

postgresql$1:::transaction-start
{
	@start["Start"] = count();
	self->ts  = timestamp;
}

postgresql$1:::transaction-abort
{
	@abort["Abort"] = count();
}

postgresql$1:::transaction-commit
/self->ts/
{
	@commit["Commit"] = count();
	@time["Total time (ns)"] = sum(timestamp - self->ts);
	self->ts=0;
}

/*
postgresql$1:::block-slsget
{
	self->blockts  = timestamp;
}

postgresql$1:::block-slsdone
/self->blockts/
{
	@blockcount["Block Count"] = count();
	@block["Get addr Total time (ns)"] = sum(timestamp - self->blockts);
	self->blockts  = 0;
}

postgresql$1:::transaction-slsstart
{
	@memsnapstart["Memsnap-start"] = count();
	self->memsnapts  = timestamp;
}

postgresql$1:::transaction-slsstop
/self->memsnapts/
{
	@memsnapstop["Memsnap-stop"] = count();
	@memsnaptime["Total time (ns)"] = sum(timestamp - self->memsnapts);
	self->memsnapts=0;
}


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
*/

END
{
	printa(@start);
	printa(@commit);
	printa(@abort);
	printa(@time);
}
