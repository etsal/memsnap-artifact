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
