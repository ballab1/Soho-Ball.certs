#!/bin/bash

# Use the Unofficial Bash Strict Mode
#set -o errexit
#set -o nounset
#set -o pipefail
IFS=$'\n\t'


declare -rA fields=( ['basic_constraints']='X509v3 Basic Constraints:'
                     ['subject_key_identifier']='X509v3 Subject Key Identifier:'
                     ['authority_key_identifier']='X509v3 Authority Key Identifier:'
                     ['issuer']='Issuer:'
                     ['subject']='Subject:' )


function sort_files() {
    local -n params="${1:?}"
    printf '%s\n' "${params[@]}" | sort
}


for fld in "${!fields[@]}"; do
    eval "declare -A $fld=()"
done
declare file fld val
declare -i line_num num_files=0
declare -a files

cd '/c/Downloads/work.certs/k8s' || exit

while read -r file; do
    (( num_files++ )) ||:
    for fld in "${!fields[@]}"; do
       line_num="$(grep --line-number "${fields[$fld]}" "$file" | cut -d ':' -f 1)"
       [ "${line_num:-0}" = 0 ] && continue
       case "$fld" in
           issuer|subject)
               val="$(sed -n "${line_num}p" "$file" | sed -E -e 's|^\s+'"${fields[$fld]}"' ||')"
               [ "$val" = 'Certificate:' ] && echo "Found 'Certificate' in ${file} section '$fld'"
               # shellcheck disable=SC1087
               eval "$fld['$file']='${val}'"
               ;;
           basic_constraints|subject_key_identifier)
               (( line_num[$fld]++ )) ||:
               val="$(sed -n "${line_num}p" "$file" | sed -E -e 's|^\s+||')"
               [ "$val" = 'Certificate:' ] && echo "Found 'Certificate' in ${file} section '$fld'"
               # shellcheck disable=SC1087
               eval "$fld['$file']='${val}'"
               ;;
           authority_key_identifier)
               (( line_num[$fld]++ )) ||:
               val="$(sed -n "${line_num}p" "$file" | sed -E -e 's|^\s+(keyid:)*||')"
               [ "$val" = 'Certificate:' ] && echo "Found 'Certificate' in ${file} section '$fld'"
               # shellcheck disable=SC1087
               eval "$fld['$file']='${val}'"
               ;;
       esac

    done
done < <(find . -name '*.inf' -type f | awk '{print substr($0, 3)}')

declare -A inspect
printf '# files scanned: %d\n' "$num_files"


inspect=()
for fld in "${!basic_constraints[@]}"; do
    inspect[${basic_constraints[$fld]}]='#'
done
printf '%d %s:\n' "${#inspect[@]}" 'basic_constraints'
for fld in $(printf '%s\n' "${!inspect[@]}" | sort); do
    printf '    %s\n' "$fld"
    files=()
    for x in "${!basic_constraints[@]}"; do
        [ "${basic_constraints[$x]}" = "$fld" ] && files+=("$x")
    done
    for x in $(sort_files 'files'); do
        printf '        %s\n' "$x"
    done
done


inspect=()
for fld in "${!subject_key_identifier[@]}"; do
    inspect[${subject_key_identifier[$fld]}]='#'
done
printf '%d %s:\n' "${#inspect[@]}" 'subject_key_identifier'
for fld in $(printf '%s\n' "${!inspect[@]}" | sort); do
    printf '    %s\n' "$fld"
    files=()
    for x in "${!basic_constraints[@]}"; do
        [ "${basic_constraints[$x]}" = "$fld" ] && files+=("$x")
    done
    for x in $(sort_files 'files'); do
        printf '        %s\n' "$x"
    done
done

inspect=()
for fld in "${!authority_key_identifier[@]}"; do
    inspect[${authority_key_identifier[$fld]}]='#'
done
printf '%d %s:\n' "${#inspect[@]}" 'authority_key_identifier'
for fld in $(printf '%s\n' "${!inspect[@]}" | sort); do
    printf '    %s\n' "$fld"
    files=()
    for x in "${!authority_key_identifier[@]}"; do
        [ "${authority_key_identifier[$x]}" = "$fld" ] && files+=("$x")
    done
    for x in $(sort_files 'files'); do
        printf '        %s\n' "$x"
    done
done


inspect=()
for fld in "${!issuer[@]}"; do
    inspect[${issuer[$fld]}]='#'
done
printf '%d %s:\n' "${#inspect[@]}" 'issuer'
for fld in $(printf '%s\n' "${!inspect[@]}" | sort); do
    printf '    %s\n' "$fld"
    files=()
    for x in "${!issuer[@]}"; do
        [ "${issuer[$x]}" = "$fld" ] && files+=("$x")
    done
    for x in $(sort_files 'files'); do
        printf '        %s\n' "$x"
    done
done


inspect=()
for fld in "${!subject[@]}"; do
    inspect[${subject[$fld]}]='#'
done
printf '%d %s:\n' "${#inspect[@]}" 'subject'
for fld in $(printf '%s\n' "${!inspect[@]}" | sort); do
    printf '    %s\n' "$fld"
    files=()
    for x in "${!subject[@]}"; do
        [ "${subject[$x]}" = "$fld" ] && files+=("$x")
    done
    for x in $(sort_files 'files'); do
        printf '        %s\n' "$x"
    done
done
