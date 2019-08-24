#!/bin/bash

if [[ "$STORAGE_MODE" == "pbench" ]]; then
	echo "The storage mode is set to $STORAGE_MODE"
	echo "Enabling pbench for collection"
	source /opt/pbench-agent/profile
	pbench-user-benchmark -- /root/ocp-diagnosis/prometheus_dump.sh
	echo "Moving the collected results to pbench server"
	pbench-move-results --prefix=ocp_diagnosis
elif [[ "$STORAGE_MODE" == "s3" ]]; then
	echo "The storage mode is set to $STORAGE_MODE"
	echo "Moving the collected data to Amazon s3"
else
	echo "$STORAGE_MODE is not a supported option, please check"
	exit 1
fi
