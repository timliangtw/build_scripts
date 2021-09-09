#!/bin/bash -ex

whoami 
COUNTER=0
while [  $COUNTER -lt 90 ]; do
	echo The counter is $COUNTER
	sleep 1
	let COUNTER=COUNTER+1
done
exit 0;
