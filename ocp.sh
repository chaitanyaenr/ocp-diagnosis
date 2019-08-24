#!/bin/bash

set -eo pipefail

function help () {
	printf "\n"
        printf "Usage: source tool_env.sh; $0\n"
        printf "\n"
        printf "Options supported:\n"
	printf "\t run_collection=str,            str=true or false\n"
        printf "\t workload_image=str,            str=Image to use\n"
	printf "\t cleanup=str,                   str=true or false\n"
        printf "\t kubeconfig_path=str,           str=path to the kubeconfig\n"
        printf "\t repo_location=str,             str=path to the cogwheel repo\n"
        printf "\t properties_file_path=str,      str=path to the properties file\n"
}


# help
if [[ "$#" -ne 0 ]]; then
	help
	exit 1
fi

# Defaults
namespace=ocp-diagnosis
counter_time=5
wait_time=25
prometheus_namespace=openshift-monitoring
repo="https://github.com/chaitanyaenr/ocp-diagnosis.git"
export KUBECONFIG=$kubeconfig_path

# Cleanup
function cleanup() {
	oc delete project --wait=true $namespace
	echo "sleeping for $wait_time for the cluster to settle"
	sleep $wait_time
}

function run_collection() {
	# Ensure that the host has the repo cloned
	if [[ ! -d $repo_location/ocp-diagnosis ]]; then
		git clone $repo $repo_location/ocp-diagnosis
	fi

	# Check if the project already exists
	if oc project $namespace &>/dev/null; then
        	echo "Looks like the $namespace already exists, deleting it"
		cleanup
	fi

	# create controller ns, configmap, job to run the scale test
	oc create -f $repo_location/ocp-diagnosis/openshift-templates/ocp-diagnosis-ns.yml
	oc create configmap kube-config --from-literal=kubeconfig="$(cat $kubeconfig_path)" -n $namespace
	oc create configmap workload-config --from-env-file=$properties_file_path -n $namespace
	oc process -p WORKLOAD_IMAGE=$workload_image -f $repo_location/ocp-diagnosis/openshift-templates/ocp-diagnosis-job-template.yml | oc create -n $namespace -f -
	sleep $wait_time
	ocp_diagnosis_pod=$(oc get pods -n $namespace | grep "ocp_diagnosis" | awk '{print $1}')
	counter=0
	while [[ $(oc --namespace=default get pods $ocp_diagnosis_pod -n $namespace -o json | jq -r ".status.phase") != "Running" ]]; do
		sleep $counter_time
		counter=$((counter+1))
		if [[ $counter -ge 120 ]]; then
			echo "Looks like the $cogwheel_pod is not up after 120 sec, please check"
			exit 1
		fi
	done

	# logging
	logs_counter=0
	logs_counter_limit=500
	oc logs -f $cogwheel_pod -n $namespace
	while true; do
        	logs_counter=$((logs_counter+1))
        	if [[ $(oc --namespace=default get pods $oc_diagnosis_pod -n $namespace -o json | jq -r ".status.phase") == "Running" ]]; then
                	if [[ $logs_counter -le $logs_counter_limit ]]; then
				echo "=================================================================================================================================================================="
				echo "Attempt $logs_counter to reconnect and fetch the pod logs"
				echo "=================================================================================================================================================================="
				echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------"
				echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------"
                        	oc logs -f $ocp_diagnosis_pod -n $namespace
                	else
                        	echo "Exceeded the retry limit trying to get the cogwheel logs: $logs_counter_limit, exiting."
                        	exit 1
                	fi
        	else
                	echo "Job completed"
                	break
        	fi
	done

	# check the status of the cogwheel pod
	while [[ $(oc --namespace=default get pods $ocp_diagnosis_pod -n $namespace -o json | jq -r ".status.phase") != "Succeeded" ]]; do
		if [[ $(oc --namespace=default get pods $ocp_diagnosis_pod -n $namespace -o json | jq -r ".status.phase") == "Failed" ]]; then
   			echo "JOB FAILED"
			echo "CLEANING UP"
   			cleanup
   			exit 1
   		else        
    			sleep $wait_time
        	fi
	done
	echo "JOB SUCCEEDED"
}

# run collection
if [[ "$run_collection" == true ]]; then
	run_collection
fi

# cleanup
if [[ "$run_collection" == true ]] && [ "$cleanup" == true ]]; then
	echo "CLEANING UP"
        cleanup
fi
