#!/bin/bash


show_help() {
	echo "This script will automate converting an ISO image to a Docker image"
	echo
	echo "Syntax: iso_to_dockerimage -f <iso_image_file> [-OPTIONS]"
	echo
	echo "Examples:"
	echo "iso_to_dockerimage -f <iso_image_file>"
	echo "iso_to_dockerimage -f <iso_image_file> -n <docker_imag_name>"
	echo "iso_to_dockerimage -f <iso_image_file> -n <docker_imag_name> -d <target_directory>"
	echo
	echo "Options:"
	echo "-h  --help	Display this help menu"
	echo "-f  --file	Specify the ISO image file path"
	echo "-n  --name	Specify the name of the Docker image created"
	echo "-d  --directory	Specify the directory where the Docker image will be created"
}


# Get the ISO image path specified
get_iso_image_path() {
	if [[ -z $1 ]]; then
		echo "[ERROR] ISO image file not specified"
		exit 1
	else
		iso_image_path=$1
	fi
}


# Set a name for the docker image
set_docker_image_name() {
	if [[ -z $1 ]]; then
		echo "Invalid Docker image name"
		exit 1
	else
		docker_image_name=$1
	fi
}


# Set the target directory where the docker image will be saved or use the current directory
set_target_dir() {
	if [[ -z $1 ]]; then
		target_dir=$(pwd)
	else
		target_dir=$1
	fi
}


get_options() {
	OPTIONS=$(getopt -o "hf:n:d:" -l "help,file:,name:,directory:" -- "$@")
	eval set -- "$OPTIONS"

	while true; do
		case "$1" in
			-h | --help)
				show_help
				exit 1
				;;

			-f | --file)
				get_iso_image_path $2
				shift 2
				;;

			-n | --name)
				set_docker_image_name $2
				shift 2
				;;

			-d | --directory)
				set_target_dir $2
				shift 2
				;;

			--)
				shift
				break
				;;

			*)
				echo "Invalid option $1"
				exit 1
				;;
		esac
	done
}


main() {
	# Check root privileges
	if [ "$EUID" -ne 0 ]; then
		echo "[ERROR]: You must run this script as root"
		exit 1
	fi

	# Check the used options
	get_options $@

	# Set the Docker image name to the ISO image name
	if [[ -z $docker_image_name ]]; then
		docker_image_name=$(echo $(basename $iso_image_path) | cut -d . -f1 | awk '{print tolower($0)}')
	fi

	# Setup working directories
	rootfs_dir=/tmp/rootfs
	squashfs_dir=/tmp/squashfs

	mkdir $rootfs_dir $squashfs_dir

	mount -o loop $iso_image_path $rootfs_dir

	cd $rootfs_dir

	# Find the squashfs filesystem
	filesystem_squashfs_dir=$(dir $(find . -type f -name "filesystem.squashfs"))

	unsquashfs -f -d $squashfs_dir $rootfs_dir/$filesystem_squashfs_dir

	cd $target_dir

	tar -czf $docker_image_name.tar.gz $squashfs_dir

	# Import archive into Docker
	docker import $docker_image_name.tar.gz $docker_image_name
	docker images --filter=reference="$docker_image_name"

	# Cleanup
	umount $rootfs_dir
	rm $docker_image_name.tar.gz
	rm -rf $rootfs_dir $squashfs_dir

	echo
	echo "========================================================================="
	echo
	echo "Script Executed Successfully!"
	exit 0

}

main $@
