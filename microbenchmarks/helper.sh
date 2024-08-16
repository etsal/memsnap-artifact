ZDISKS="/dev/$DISK1 /dev/$DISK2"
SDISKS="$DISK1 $DISK2"
STRIPE="st0"
SPATH="/dev/stripe/st0"
ZPOOL="microbench"
MNT="testmnt"

ginit()
{
	gstripe create -s 65536 $STRIPE $SDISKS
}

gfini()
{
	gstripe destroy $STRIPE
}

zinit()
{
	clean
	zpool create -f $ZPOOL $ZDISKS
	zfs create $ZPOOL/$MNT

	zfs set mountpoint="/$MNT" $ZPOOL/$MNT
	zfs set recordsize=64k $ZPOOL

	zfs set sync=standard $ZPOOL
	zfs set checksum=off $ZPOOL/$MNT
}

zfini()
{
	zfs destroy -r $ZPOOL/$MNT
	zpool destroy $ZPOOL
}

finit()
{
	clean
	ginit
	newfs $SPATH  > /dev/null

	mount -t ufs $SPATH "/$MNT"
}

ffini()
{
	umount "/$MNT"
	gfini
}

sinit()
{
	clean
	ginit
   	newfs_sls $SPATH > /dev/null 

    	kldload slos
	mount -t slsfs $SPATH "/$MNT"
   	kldload sls
}

sfini()
{
   	kldunload sls
	umount "/$MNT"
   	kldunload slos
	gfini
}

clean()
{
	pkill dtrace
	wait 1

	sfini > /dev/null 2> /dev/null
	ffini > /dev/null 2> /dev/null
	sfini_old > /dev/null 2> /dev/null
	sfini_objsnap > /dev/null 2> /dev/null
	zfini > /dev/null 2> /dev/null
}

sinit_old()
{
	clean
	ginit
   	../aurora-original/tools/newfs_sls/newfs_sls $SPATH > /dev/null 

    	kldload ../aurora-original/slos/slos.ko
	mount -t slsfs $SPATH "/$MNT"
    	kldload ../aurora-original/sls/sls.ko
}

sfini_old()
{
   	kldunload sls
	umount "/$MNT"
   	kldunload slos
	gfini
}

sinit_objsnap()
{
	kldload objsnap
	objinit /dev/$DISK >/dev/null 2>/dev/null
	kldload memsnap
	mount -t msnp msnp "/$MNT"

}

sfini_objsnap()
{
	umount "/$MNT"
	kldunload memsnap
	kldunload objsnap
}
