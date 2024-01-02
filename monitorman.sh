#! /bin/bash

# Globals & Constants
PRIMARY_MONITOR=$(bspc query -M --names -m primary)
HELP_TEXT="monitorman is a script for easily managing monitors with bspwm and xrandr.
usage: monitorman [options]

Options with capital flags denote actions, options with lower case flags are modifiers to actions and
will either be ignored or error when used on their own.

Only a single action flag may be passed at once

Option arguments are case sensitive.

Options:
	Actions:
	-A <New Monitor Name>: Add Monitor Action - Activates the given monitor with xrandr, adds it to bspwm and re-organizes all desktops across all monitors.
	-R <Existing Monitor Name>: Remove Monitor Action - Deactivates the given monitor with xrandr, removes it from bspwm and re-organizes all desktops across remaining monitors.

	Modifiers:
	-d <N,E,S,W>: Direction modifier.
		When used with:
			-A: Specifies the cardinal direction relative to the reference monitor that the new monitor should be placed. If not passed the new monitor will mirror the reference monitor.
	-h: Display this help menu (this modifier will cancel any other flags).
	-m <Existing Monitor Name>: Reference monitor modifier.
		When used with:
			-A: Specifies the monitor to use as a reference for placement. If not passed the primary monitor will be used.
	-v: Be verbose.
"
TOTAL_ACTIONS=2

# Option variables
addAction=1
removeAction=1
actionArgument=""
direction=""
referenceMonitor=""
verbose="false"

# Error Messages
INVALID_ADD_MONITOR="Please select a valid monitor name. The monitor must be connected (xrandr -q can show this) but must not be on xrandr --listmonitors."
INVALID_REMOVE_MONITOR="Please select a valid monitor name. The monitor must be connected (xrandr -q can show this) and must be on xrandr --listmonitors."
INVALID_DIRECTION="The -d must be given one of [N,E,S,W]. Please enter a valid direction or remove -d to mirror -m."
INVALID_REFERENCE_MONITOR="Please select a valid monitor name. xrandr --listmonitors can be used to find all valid reference monitors."
MULTIPLE_ACTIONS_ERROR="Only one action flag may be passed."

# Get option flags and variables
while getopts ":A:d:hm:R:v" option; do
	case $option in
	A)
		addAction=0
		actionArgument=$OPTARG
		;;
	d)
		direction=$OPTARG
		;;
	h)
		printf '%s\n' "$HELP_TEXT"
		exit 0
		;;
	m)
		referenceMonitor=$OPTARG
		;;
	R)
		removeAction=0
		actionArgument=$OPTARG
		;;
	v)
		verbose="true"
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		exit 1
		;;
	:)
		echo "Missing argument for -$OPTARG" >&2
		exit 1
		;;
	esac
done

# Validate only a single action flag was passed
if [[ $(($addAction + $removeAction)) -lt $(($TOTAL_ACTIONS - 1)) ]]; then
	printf '%s\n' "$MULTIPLE_ACTIONS_ERROR"
	exit 1
fi

# Function for sorting and arranging desktops
arrangeDesktops() {
	# Prepare to sort, split, and clean the desktops
	desktops=()
	# Get all desktops and add them to the array
	mapfile -t desktops < <(bspc query -D --names)
	$verbose && echo "Found desktops: ${desktops[@]}"

	monitors=()
	# Get all monitors and add them to the array
	mapfile -t monitors < <(xrandr --listmonitors | grep " [0-9]:" | awk '{ print $4 }')
	$verbose && echo "Found monitors: ${monitors[@]}"

	# Loop through $desktops and assign each to $monitors sequentially
	# e.g. with two monitors desktop 1 goes to monitor 1, desktop 2 goes to monitor 2, desktop 3 goes to monitor 1 etc...
	monitorIndex=0
	monitorsLength=${#monitors[@]}
	for desktop in ${desktops[@]}; do
		# Ignore the default desktop because it will be removed later
		if ! [[ "$desktop" = "Desktop" ]]; then
			bspc desktop "$desktop" -m ${monitors[$monitorIndex]}
			$verbose && echo "Moved desktop ${desktop} to monitor ${monitors[$monitorIndex]}"

			monitorIndex=$(($monitorIndex + 1))
			if [[ $monitorIndex -eq $monitorsLength ]]; then
				monitorIndex=0
			fi
		fi
	done

	# Loop through $monitors and sort the desktops so they are in the proper order
	for monitor in ${monitors[@]}; do
		mapfile -t desktops < <(bspc query -D -m "$monitor" --names)
		$verbose && echo "Found desktops: [${desktops[@]}] on monitor $monitor"
		readarray -td '' desktops < <(printf '%s\0' "${desktops[@]}" | sort -z -n)
		$verbose && echo "Sorted desktops: ${desktops[@]}"

		bspc monitor "$monitor" -o ${desktops[@]}
	done
}

# Add Action
if [[ $addAction -eq 0 ]]; then
	# Validate action argument
	if [[ $(xrandr -q | grep -w "${actionArgument} connected" | wc -l) -eq 0 ||
	$(xrandr --listmonitors | grep -w "$actionArgument" | wc -l) -gt 0 ]]; then
		printf '%s\n' "$INVALID_ADD_MONITOR"
		exit 1
	fi

	# Validate -d and -m modifiers or set defaults
	if ! [[ "$direction" =~ [NESW] ]]; then
		if [[ "$direction" = "" ]]; then
			$verbose && echo "using default value of --same-as for -d"
			direction="--same-as"
		else
			printf '%s\n' "$INVALID_DIRECTION"
			exit 1
		fi
	else
		case "$direction" in
		N)
			direction="--above"
			;;
		E)
			direction="--right-of"
			;;
		S)
			direction="--below"
			;;
		W)
			direction="--left-of"
			;;
		esac

		$verbose && echo "Using value of ${direction} for -d"
	fi

	if [[ "$referenceMonitor" = "" ]]; then
		$verbose && echo "Using default value of ${PRIMARY_MONITOR} for -m"
		referenceMonitor=$PRIMARY_MONITOR
	elif [[ $(xrandr --listmonitors | grep -w "$referenceMonitor" | wc -l) -eq 0 ]]; then
		printf '%s\n' "$INVALID_REFERENCE_MONITOR"
		exit 1
	fi

	# Enable the monitor and position it with xrandr. This will automatically add it to bspwm
	xrandr --output "$actionArgument" --auto "$direction" "$referenceMonitor"

	# Start the second polybar
	polybar secondary &

	arrangeDesktops

	# Delete the default desktop
	bspc desktop Desktop -r

	exit 0
fi

# Remove Action
if [[ $removeAction -eq 0 ]]; then
	# Validate action argument
	if [[ $(xrandr -q | grep -w "${actionArgument} connected" | wc -l) -eq 0 ||
	$(xrandr --listmonitors | grep -w "$actionArgument" | wc -l) -eq 0 ]]; then
		printf '%s\n' "$INVALID_REMOVE_MONITOR"
		exit 1
	fi

	# Kill the second polybar
	xprop -name "polybar-secondary_${actionArgument}" _NET_WM_PID | awk '{print $3}' | xargs kill

	# Disable the monitor with xrandr. We will still need to remove the monitor from bspwm later.
	xrandr --output "$actionArgument" --off

	# Make a placeholder desktop so we can move all of our existing desktops off the monitor to be removed.
	bspc monitor "$actionArgument" -a Desktop

	arrangeDesktops

	# Now we can delete the monitor from bspwm. This will also delete the placeholder desktop we created.
	bspc monitor "$actionArgument" -r

	exit 0
fi
