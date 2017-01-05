#!/bin/bash

set -euo pipefail

# Set commands here
CC=echo
CXX=clang++

# Format must have "@@" preceding the key and ':' to separate the value
# @@key: value
#
# getValue $key $file
getValue()
{
  key=$1
  file=$2
  value=$(grep $key $file)
  # get value
  value=${value##*@@$key:}
  # trim spaces
  value=$(tr -d ' ' <<< $value)
  echo "$value"
}

# statistics
stat_pass=0
stat_fail=0
list_fail=""

update_pass()
{
  ((stat_pass = stat_pass + 1))
}
update_fail()
{
  ((stat_fail = stat_fail + 1))
}

# compile $input $output
compile()
{
  input=$1
  output=$2
  $CC -c -o $2 $1 > /dev/null
}

# link $input $output
link()
{
  input=$1
  output=$2
  $CC -o $2 $1 > /dev/null
}

# prints ok if output matches expected outcome
ok()
{
  printf "%-10s" "[OK]"
  printf "\n"
}

# prints fail if output does not match expected outcome
fail()
{
  printf "%-10s" "[FAIL]"
  printf "\n"
}

printcol()
{
  printf "%-11s %-30s" "$1:" "${!1}"
}

# combine frequently used together functions
ok_update()
{
  ok
  update_pass
}
fail_update()
{
  file=$1
  fail
  update_fail
  list_fail+="$file\n"
}

for f in *.c *.cpp; do
  linkable=$(getValue "linkable" $f)
  compilable=$(getValue "compilable" $f)
  expect=$(getValue "expect" $f)

  filename=$(basename $f)

  # 1. Try to compile
  # 2. If compilation succeeds, try to link
  # 3. If linking succeeds, try to run

  printf "$f\n"

  printcol "compilable"
  compile $f $filename.o
  res=$?

  if [ "$compilable" == "yes" ] && [ $res -eq 0 ]; then
    ok
    printcol "linkable"
    link $filename.o $filename
    res=$?

    if [ "$linkable" == "yes" ] && [ $res -eq 0 ];  then
      ok
      printcol "expect"
      # ./$filename
      res=$?

      if [ "$expect" == "success" ] && [ $res -eq 0 ]; then
        ok_update
      elif [ "$expect" != "success" ] && [ $res -ne 0 ]; then
        ok_update
      else
        fail_update $f
      fi
    elif [ "$linkable" == "no" ] && [ $res -ne 0 ]; then
      ok_update
    else
      fail_update $f
    fi
  elif [ "$compilable" == "no" ] && [ $res -ne 0 ]; then
    ok_update
  else
    fail_update $f
  fi

  printf "\n"

done

# print stats
printf "%-20s %-10s" "Passed tests:" "$stat_pass"
printf "\n"
printf "%-20s %-10s" "Failed tests:" "$stat_fail"
printf "\n\n"
printf "Failed list:\n$list_fail"
