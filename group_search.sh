#!/usr/bin/env bash


echo "Let's find the members of a specific group"

read -p "What group do you want to search for?	" group_name

grep -w ${group_name} /etc/group



read -p "Write the users you want to be in the group followed by a comma:	" group_members

awk -F ":" '/wheel/ {print $4}' /etc/group | xargs -I '{}' sed -i s/{}/${group_members}/ /etc/group





