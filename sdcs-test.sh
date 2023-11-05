#!/bin/bash

if [[ $# -ne 1 ]]; then
	echo "Usage:"
	echo "$0 {cache server number}"
	exit 1
fi

cs_num=$1

# TODO: should also set upperbound next year.
[[ $cs_num -le 2 ]] && {
	echo "Error: cache server should be more than 3 ($cs_num provided)"
	exit 2
}

## for macos, the default head/tail break. With GNU head/tail, it is
## easy to capture multilines, for example, `head -n -1` for a big body.
#if [[ $OSTYPE == 'darwin'* ]]; then
#	if `which ghead > /dev/null 2>&1` ; then
#		alias head=ghead
#		alias tail=gtail
#	else
#		echo "please run 'brew install coreutils'."
#		exit 1
#	fi
#fi

PORT_BASE=9526
HOST_BASE=127.0.0.1
MAX_ITER=500

PASS_PROMPT="\e[1;32mPASS\e[0m"
FAIL_PROMPT="\e[1;31mFAIL\e[0m"

function get_cs() {
	port=$(($PORT_BASE + $(shuf -i 1-$cs_num -n 1)))
	echo http://$HOST_BASE:$port
}

function get_key() {
	echo "key-$(shuf -i 1-$MAX_ITER -n 1)"
}

function gen_data_with_idx() {
	local idx=$1

	echo "{\"key-$idx\": \"value $idx\"}"
}

function gen_data_with_key() {
	local key=$1

	echo "{\"$key\":\"value $(echo $key | sed 's/.*-//')\"}"
}

function query_key() {
	local key=$1
	local exist=$2
	local response=$(curl -s -w "\n%{http_code}" $(get_cs)/$key)
	local result=$(echo "$response" | head -n 1)
	local status_code=$(echo "$response" | tail -n 1)

	if [[ $exist == 1 ]]; then
		local expect=$(gen_data_with_key $key)
		if [[ $status_code -ne 200 ]] || [[ "$result" != "$expect" ]]; then
			echo -e "Error:\tInvalid response"
			echo -e "\texpect: 200 $expect"
			echo -e "\tgot: $status_code $result"
			return 1
		fi
	else
		if [[ $status_code -ne 404 ]]; then
			echo "Error: expect status code 404 but got $status_code"
			return 1
		fi
	fi
	return 0
}

function test_set() {
	local i=1

	while [[ $i -le $MAX_ITER ]]; do
		status_code=$(curl -s -o /dev/null -w "%{http_code}" -XPOST -H "Content-type: application/json" -d "$(gen_data_with_idx $i)" $(get_cs))
		if [[ $status_code -ne 200 ]]; then
			echo "Error: expect status code 200 but got $status_code"
			return 1
		fi
		((i++))
	done
	return 0
}

function test_get() {
	local count=$((MAX_ITER / 10))
	local i=0
	while [[ $i -lt $count ]]; do
		if ! query_key $(get_key) 1; then
			return 1
		fi
		((i++))
	done
	return 0
}


deleted_keys=

function test_delete() {
	local count=$((MAX_ITER / 10 * 9))
	local keys=()
	while [[ ${#keys[@]} -lt $count ]]; do
		key="key-$(shuf -i 1-$MAX_ITER -n 1)"
		if ! [[ " ${keys[@]} " =~ " ${key} " ]]; then
			keys+=("$key")
		fi
	done
	deleted_keys=(${keys[@]})

	for key in "${keys[@]}"; do
		local response=$(curl -XDELETE -s -w "\n%{http_code}" $(get_cs)/$key)
		local result=$(echo "$response" | head -n 1)
		local status_code=$(echo "$response" | tail -n 1)
		local expect=1
		if [[ $status_code -ne 200 ]] || [[ "$result" != "$expect" ]]; then
			echo -e "Error:\tInvalid response"
			echo -e "\texpect: $status_code $expect"
			echo -e "\tgot: $status_code $result"
			return 1
		fi
	done

}

function test_get_after_delete() {
	for key in "${deleted_keys[@]}"; do
		query_key $key 0 || return 1
	done

	return 0
}

function test_delete_after_delete() {
	for key in "${deleted_keys[@]}"; do
		local response=$(curl -XDELETE -s -w "\n%{http_code}" $(get_cs)/$key)
		local result=$(echo "$response" | head -n 1)
		local status_code=$(echo "$response" | tail -n 1)
		if [[ $status_code -ne 200 ]] || [[ "$result" != "0" ]]; then
			echo -e "Error:\tInvalid response"
			echo -e "\texpect: 200 0"
			echo -e "\tgot: $status_code $result"
			return 1
		fi
	done
}

function run_test() {
	local test_function=$1
	local test_name=$2

	echo "starting $test_name..."
	if $test_function; then
		echo -e "$test_name ...... ${PASS_PROMPT}"
		return 0
	else
		echo -e "$test_name ...... ${FAIL_PROMPT}"
		return 1
	fi
}

declare -a test_order=(
	"test_set"
	"test_get"
	"test_set again"
	"test_delete"
	"test_get_after_delete"
	"test_delete_after_delete"
)

declare -A test_func=(
	["test_set"]="test_set"
	["test_get"]="test_get"
	["test_set again"]="test_set"
	["test_delete"]="test_delete"
	["test_get_after_delete"]="test_get_after_delete"
	["test_delete_after_delete"]="test_delete_after_delete"
)

pass_count=0
fail_count=0

# NOTE: macos date does not support `date +%s%N`.
TIMEFORMAT="======================================
Run ${#test_order[@]} tests in %R seconds."

time {
for testname in "${test_order[@]}"; do
	if run_test "${test_func[$testname]}" "$testname"; then
		((pass_count++))
	else
		((fail_count++))
	fi
done
}

echo -e "\e[1;32m$pass_count\e[0m passed, \e[1;31m$fail_count\e[0m failed."
