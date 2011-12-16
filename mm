#!/bin/bash
# NOTE:
#     busybox's 'expr' can't process long long, so use 'let' embedded in bash.
#     busybox's 'hexdump' can't process large files(> 2G)
#     busybox's 'hexdump' can't process ' ' correctly
#     only support BE ( 8/16/32 ) (no xxd)
#     if any problem, please contackt niqingliang@insigma.com.cn

G_FILE="/dev/tin_regs_info"
G_BS="4"

G_BASE_NAME="`basename $0`"
G_EXE_NAME="`echo "${G_BASE_NAME}" | sed 's/\([^.][^.]*\)\.\(.*\)/\1/'`"
print_help()
{
	echo "${G_EXE_NAME} - memory modify"
	echo "Usage:"
	echo "        ${G_EXE_NAME} [.b, .w, .l] address"
}

################################### process exe name
G_EXE_OPT="`echo "${G_BASE_NAME}" | sed 's/\([^.][^.]*\)\.\(.*\)/\2/'`"
if [ "${G_EXE_OPT}" != "${G_BASE_NAME}" ]; then
case ${G_EXE_OPT} in
	b )
		G_BS="1"
		;;
	w )
		G_BS="2"
		;;
	l )
		G_BS="4"
		;;
	? )
		print_help
		exit 1
		;;
esac
fi

#################################### parse args
if [ $# -lt 1 -o 1 -lt $# ]; then
	echo "ERROR: your arguments num is not valid."
	print_help
	exit 2
fi

G_ADDR="0"
if [ 1 -le $# ]; then
	G_ADDR="`printf "%d\n" $1`"
	if [ $? != 0 ]; then
		echo "ERROR: you have specified an invalid address."
		print_help
		exit 3
	fi
fi

# check alignment
L_ISALIGN=0
let "L_ISALIGN=${G_ADDR}%${G_BS}"
if [ "${L_ISALIGN}" != "0" ]; then
	echo "ERROR: your address is not aligned to the block size (${G_BS}Bytes)!"
	exit 5
fi

################ sub routine

get_addr()
{
	echo `printf "%08X\n" $1`
}
L_BLOCK_CHARS_NUM=0
let "L_BLOCK_CHARS_NUM=2*${G_BS}"
################ do
L_DD_SKIP=0
let "L_DD_SKIP=${G_ADDR}/${G_BS}"
L_ADDR=${G_ADDR}
while true; do
	# display
	dd if=${G_FILE} bs=${G_BS} count=1 skip=${L_DD_SKIP} 2>/dev/null \
		| hexdump -v \
			-n ${G_BS} \
			-e "1/${G_BS} \"%0${L_BLOCK_CHARS_NUM}X\"" \
		| awk "{
			printf(\"0x%s: %s ? \",  \"`get_addr ${L_ADDR}`\", \$0)
			}"
	# read
	L_NEW_VAL=""
	read -r L_NEW_VAL
	if [ "${L_NEW_VAL}" = "." ]; then
		exit 0
	fi
	# modify
	L_NEW_VAL_HEX="`printf "%0${L_BLOCK_CHARS_NUM}x\n" ${L_NEW_VAL}`"
	if [ $? -ne 0 ]; then
		echo "ERROR: I can't recognize the value you inputed!!"
		exit 3
	fi
	L_NEW_VAL_STR=""
	L_LOOP=0
	while [ ${L_LOOP} -lt ${#L_NEW_VAL_HEX} ]; do
		L_NEW_VAL_STR="${L_NEW_VAL_STR}\\x${L_NEW_VAL_HEX:${L_LOOP}:2}"
		let "L_LOOP+=2"
	done
	echo -e "${L_NEW_VAL_STR}" \
		| dd of=${G_FILE} bs=${G_BS} count=1 skip=${L_DD_SKIP} 2>/dev/null
	if [ $? -ne 0 ]; then
		echo "ERROR: write \"${L_NEW_VAL_STR}\" to `get_addr ${L_ADDR}` error!"
		exit 1
	fi

	# next
	let "L_DD_SKIP+=1"
	let "L_ADDR+=${G_BS}"
done

exit 0
