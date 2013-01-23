#!/bin/bash
# NOTE:
#     busybox's 'expr' can't process long long, so use 'let' embedded in bash.
#     busybox's 'hexdump' can't process large files(> 2G)
#     busybox's 'hexdump' can't process ' ' correctly
#     if any problem, please contackt niqingliang@insigma.com.cn

G_FILE="/dev/jilong/debugger"
G_BS="4"
G_LINE_BYTES_NUM="16"
G_COUNT="64"
G_SPACE="_"
G_BS_SPACE=""

G_BASE_NAME="`basename $0`"
G_EXE_NAME="`echo "${G_BASE_NAME}" | sed 's/\([^.][^.]*\)\.\(.*\)/\1/'`"
print_help()
{
	echo "${G_EXE_NAME} - memory display"
	echo "Usage:"
	echo "        ${G_EXE_NAME} [.b, .w, .l] [options] address [# of objects]"
	echo "Options:"
	echo "    -l  <line_block_num>   how many blocks in one line"
}

################################### process exe name
G_EXE_OPT="`echo "${G_BASE_NAME}" | sed 's/\([^.][^.]*\)\.\(.*\)/\2/'`"
if [ "${G_EXE_OPT}" != "${G_BASE_NAME}" ]; then
case ${G_EXE_OPT} in
	b )
		G_BS="1"
		G_BS_SPACE="${G_SPACE}${G_SPACE}"
		;;
	w )
		G_BS="2"
		G_BS_SPACE="${G_SPACE}${G_SPACE}${G_SPACE}${G_SPACE}"
		;;
	l )
		G_BS="4"
		G_BS_SPACE="${G_SPACE}${G_SPACE}${G_SPACE}${G_SPACE}${G_SPACE}${G_SPACE}${G_SPACE}${G_SPACE}"
		;;
	? )
		print_help
		exit 1
		;;
esac
fi

################################### parse options
while getopts ":l:" opt
do
        case $opt in
                l )
                        G_LINE_BYTES_NUM="$OPTARG"
			let "G_LINE_BYTES_NUM=${G_BS}*${OPTARG}"
			;;
                ? )
                        print_help
                        exit 1
                        ;;
        esac
done
shift $(($OPTIND - 1))

L_TMP=0
let "L_TMP=${G_LINE_BYTES_NUM}%${G_BS}"
if [ ${L_TMP} -ne 0 ]; then
	echo "ERROR: one block can't be displayed in single line"
	exit 1
fi

#################################### parse args
if [ $# -lt 1 -o 2 -lt $# ]; then
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
if [ 2 -le $# ]; then
	G_COUNT="`printf "%d\n" $2`"
	if [ $? != 0 ]; then
		echo "ERROR: you have specified an invalid count."
		print_help
		exit 4
	fi
fi

# check alignment
L_ISALIGN=0
let "L_ISALIGN=${G_ADDR}%${G_BS}"
if [ "${L_ISALIGN}" != "0" ]; then
	echo "ERROR: your address is not aligned to the block size (${G_BS}Bytes)!"
	exit 5
fi

# read and display

L_LINE_BLOCK_NUM=0
let "L_LINE_BLOCK_NUM=${G_LINE_BYTES_NUM}/${G_BS}"
L_BLOCK_CHARS_NUM=0
let "L_BLOCK_CHARS_NUM=2*${G_BS}"

################################################### display header
if [ ${G_LINE_BYTES_NUM} -le 16 ]; then
echo "${L_LINE_BLOCK_NUM} ${G_BS}" | awk '{
	LBN=$1
	BS=$2
	i=0
	j=0
	printf("base \\ off:  ")
	for (i = 0; i < LBN; ++i) {
		for (j = 0; j < BS; ++j) {
			printf("%X ", i * BS + j)
		}
		printf(" ")
	}
	printf(" ")
	for (i = 0; i < LBN * BS; ++i) {
		printf("%X", i)
	}
	printf("\n")
	}'
else
echo "${L_LINE_BLOCK_NUM} ${L_BLOCK_CHARS_NUM}" | awk "{
	i=0
	printf(\"base \\\ off:  \")
	for (i = 0; i < ${L_LINE_BLOCK_NUM}; ++i) {
		printf(\"%-${L_BLOCK_CHARS_NUM}X \", i*${G_BS})
	}
	printf(\" \")
	for (i = 0; i < ${L_LINE_BLOCK_NUM}; ++i) {
		printf(\"%-${G_BS}X\", i*${G_BS})
	}
	printf(\"\n\")
	}"
fi
#echo "print header done"

get_line_addr()
{
	local tmp=0
	let "tmp=$1*${G_LINE_BYTES_NUM}"
	echo `printf "%08X\n" ${tmp}`
}

dsp_single_line()
{
	# pre
	local L_HD_PRE_BLOCKS=0
	local L_REG_HEX_PRE=""
	local L_REG_ASC_PRE=""
	local L_DD_POSTFIX=""
	if [ $2 -gt 0 ]; then
		let "L_HD_PRE_BLOCKS=$2/${G_BS}"
		L_REG_HEX_PRE="${L_HD_PRE_BLOCKS}/ \" ${G_BS_SPACE}\""
		L_REG_ASC_PRE="${L_HD_PRE_BYTES}/ \"_\""
		L_DD_POSTFIX="| dd bs=1 skip=$2 2>/dev/null"
	fi
	# self
	local L_HD_BLOCKS=0
	let "L_HD_BLOCKS=$3/${G_BS}"

	local L_REG_HEX_SELF="${L_HD_BLOCKS}/${G_BS} \" %0${L_BLOCK_CHARS_NUM}X\""
	local L_REG_ASC_SELF="$3/1 \"%1_p\""
	# post
	local L_HD_POST_BLOCKS=0
	local L_REG_HEX_POST=""
	local L_REG_ASC_POST=""
	if [ $4 -gt 0 ]; then
		let "L_HD_POST_BLOCKS=$4/${G_BS}"
		L_REG_HEX_POST="${L_HD_POST_BLOCKS}/ \" ${G_BS_SPACE}\""
		L_REG_ASC_POST="$4/ \"_\""
	fi
	L_DD_SKIP_BLOCKS=0
	let "L_DD_SKIP_BLOCKS=$1*${G_LINE_BYTES_NUM}/${G_BS}+$2/${G_BS}"
	L_DD_BLOCKS=0
	let "L_DD_BLOCKS=$3/${G_BS}"
	# display
	dd if=${G_FILE} bs=${G_BS} count=${L_DD_BLOCKS} skip=${L_DD_SKIP_BLOCKS} 2>/dev/null\
		| hexdump -v \
			-n $3 \
			-e "${L_REG_HEX_PRE} ${L_REG_HEX_SELF} ${L_REG_HEX_POST}" \
			-e "\" |\" ${L_REG_ASC_PRE} ${L_REG_ASC_SELF} ${L_REG_ASC_POST} \"|\"" \
		| awk "{
			printf(\"0x%s: %s\n\", \"`get_line_addr $1`\", \$0)
			}"
}


L_DD_SKIP=0
let "L_DD_SKIP=${G_ADDR}/${G_LINE_BYTES_NUM}"
L_DD_END=0
let "L_DD_END=(${G_ADDR}+${G_BS}*${G_COUNT})/${G_LINE_BYTES_NUM}"

######################### only one line
if [ ${L_DD_SKIP} -eq ${L_DD_END} ]; then
	L_HD_PRE_BYTES=0
	let "L_HD_PRE_BYTES=${G_ADDR}%${G_LINE_BYTES_NUM}"
	L_HD_BYTES=0
	let "L_HD_BYTES=(${G_ADDR}+${G_BS}*${G_COUNT})%${G_LINE_BYTES_NUM}"
	L_HD_POST_BYTES=0
	let "L_HD_POST_BYTES=${G_LINE_BYTES_NUM}-${L_HD_BYTES}"

	let "L_HD_BYTES=${L_HD_BYTES}-${L_HD_PRE_BYTES}"

	dsp_single_line "${L_DD_SKIP}" "${L_HD_PRE_BYTES}" "${L_HD_BYTES}" "${L_HD_POST_BYTES}"

else
	######################### the first line
	L_HD_PRE_BYTES=0
	let "L_HD_PRE_BYTES=${G_ADDR}%${G_LINE_BYTES_NUM}"
	L_HD_BYTES=0
	let "L_HD_BYTES=${G_LINE_BYTES_NUM}-${L_HD_PRE_BYTES}"

	if [ ${L_HD_PRE_BYTES} -ne 0 ]; then
		dsp_single_line "${L_DD_SKIP}" "${L_HD_PRE_BYTES}" "${L_HD_BYTES}" "0"
		let "L_DD_SKIP=${L_DD_SKIP}+1"
	fi
	########################## the full lines
	while [ ${L_DD_SKIP} -lt ${L_DD_END} ]; do
		dsp_single_line "${L_DD_SKIP}" "0" "${G_LINE_BYTES_NUM}" "0"
		let "L_DD_SKIP=${L_DD_SKIP}+1"
	done
	######################### the last line
	L_HD_BYTES=0
	let "L_HD_BYTES=(${G_ADDR}+${G_BS}*${G_COUNT})%${G_LINE_BYTES_NUM}"
	L_HD_POST_BYTES=0
	let "L_HD_POST_BYTES=${G_LINE_BYTES_NUM}-${L_HD_BYTES}"

	if [ ${L_HD_BYTES} -gt 0 ]; then
		dsp_single_line "${L_DD_SKIP}" "0" "${L_HD_BYTES}" "${L_HD_POST_BYTES}"
	fi
fi

