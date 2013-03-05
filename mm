#!/bin/sh
# NOTE:
#     busybox's 'expr' can't process long long, so use 'let' embedded in bash.
#     busybox's 'hexdump' can't process large files(> 2G)
#     busybox's 'hexdump' can't process ' ' correctly
#     if any problem, please contact niqingliang2003@gmail.com

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
hex_gen()
{
	local L_REF_DATA="\x01\x23\x45\x67\x89\xab\xcd\xef"

	local L_REF_STR="`echo -e "${L_REF_DATA}" \
		| hexdump -n ${G_BS} \
		-e \"1/${G_BS} \\\"%0${L_BLOCK_CHARS_NUM}x\\\"\"`"

	local L_VAL_HEX="`printf "%0${L_BLOCK_CHARS_NUM}x\n" $1`"
	local L_VAL_ORDER="\x01\x23\x45\x67\x89\xab\xcd\xef"

	local L_LOOP_CNT=0
	while [ ${L_LOOP_CNT} -lt ${L_BLOCK_CHARS_NUM} ]; do
		L_POS=${L_REF_STR:${L_LOOP_CNT}:1}
		let "L_POS=2*${L_POS}+2"
		L_NEW=${L_VAL_HEX:${L_LOOP_CNT}:2}
		L_VAL_ORDER="`echo "${L_VAL_ORDER}" \
			| sed "s/^\(.\{${L_POS}\}\).\{2\}\(.*\)/\1${L_NEW}\2/"`"

		let "L_LOOP_CNT+=2"
	done

	local L_FINAL_STR="`echo -e "${L_VAL_ORDER}" \
		| hexdump -n ${G_BS} \
		-e \"1/${G_BS} \\\"%0${L_BLOCK_CHARS_NUM}x\\\"\"`"

	if [ "${L_FINAL_STR}" != "${L_VAL_HEX}" ]; then
		return 1
	fi

	local L_TMP_CHARS_NUM=0
	let "L_TMP_CHARS_NUM=4*${G_BS}"
	echo -e "${L_VAL_ORDER:0:${L_TMP_CHARS_NUM}}"
}

L_DD_SKIP=0
let "L_DD_SKIP=${G_ADDR}/${G_BS}"
L_ADDR=${G_ADDR}
while true; do
	# display
	dd if=${G_FILE} bs=${G_BS} count=1 skip=${L_DD_SKIP} 2>/dev/null \
		| hexdump -v \
			-n ${G_BS} \
			-e "1/${G_BS} \"%0${L_BLOCK_CHARS_NUM}X\" \"\\n\"" \
		| awk "{
			printf(\"0x%s: %s ? \",  \"`get_addr ${L_ADDR}`\", \$0)
			}"
	# read
	L_NEW_VAL=""
	read -r L_NEW_VAL
	if [ "${L_NEW_VAL}" == "." ]; then
		exit 0
	fi
	# modify
	if [ "${L_NEW_VAL}" != "" ]; then
		hex_gen ${L_NEW_VAL} \
			| dd of=${G_FILE} bs=${G_BS} count=1 seek=${L_DD_SKIP} 2>/dev/null
		if [ $? -ne 0 ]; then
			echo "ERROR: write \"${L_NEW_VAL_STR}\" to `get_addr ${L_ADDR}` error!"
			exit 1
		fi
	fi

	# next
	let "L_DD_SKIP+=1"
	let "L_ADDR+=${G_BS}"
done

exit 0
