#!/bin/bash


#------------------------------------------------------------------------
function inspect() {

    local -r dir="${1:?}"
    local -n params="${2:?}"

    local -A inspect=()
    local -a files
    local fld x
    local -ir len="${#dir}"

    for fld in "${!params[@]}"; do
        if [ "${fld:0:$len}" = "$dir" ]; then
            inspect[${params[$fld]}]='#'
        fi
    done
    printf '    found %d instances of %s:\n' "${#inspect[@]}" "$2"
    for fld in $(printf '%s\n' "${!inspect[@]}" | sort); do
        printf '        %s\n' "$fld"
        files=()
        for x in "${!params[@]}"; do
#            echo -e "dir: $dir\\nfld: $fld\\nx: $x\\nparams[$x]: ${params[$x]}" >&2
            if [ "${params[$x]}" = "$fld" ] && [ "${x:0:$len}" = "$dir" ]; then
                files+=("$x")
            fi
        done
        for x in $(sort_files 'files'); do
            printf '            %s\n' "${x//.inf}"
        done
    done
}

#------------------------------------------------------------------------
function main() {

    local dir file fld val
    local -i line_num num_files=0

    for fld in "${!fields[@]}"; do
        eval "declare -A $fld=()"
    done

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
                   (( line_num++ )) ||:
                   val="$(sed -n "${line_num}p" "$file" | sed -E -e 's|^\s+||')"
                   [ "$val" = 'Certificate:' ] && echo "Found 'Certificate' in ${file} section '$fld'"
                   # shellcheck disable=SC1087
                   eval "$fld['$file']='${val}'"
                   ;;
               authority_key_identifier)
                   (( line_num++ )) ||:
                   val="$(sed -n "${line_num}p" "$file" | sed -E -e 's|^\s+(keyid:)*||')"
                   [ "$val" = 'Certificate:' ] && echo "Found 'Certificate' in ${file} section '$fld'"
                   # shellcheck disable=SC1087
                   eval "$fld['$file']='${val}'"
                   ;;
           esac
        done
    done < <(find . -name '*.inf' -type f | awk '{print substr($0, 3)}')

    printf 'Number of files scanned: %d\n' "$num_files"
    while read -r dir; do
        echo
        echo '==========================================================================='
        echo "$dir"
        for fld in "${!fields[@]}"; do
            inspect "${dir}/" "$fld"
            echo
        done
    done < <(find . -mindepth 1 -maxdepth 1 -type d | awk '{print substr($0, 3)}')
    echo '==========================================================================='
}

#------------------------------------------------------------------------
function sort_files() {

    local -n params="${1:?}"
    printf '%s\n' "${params[@]}" | sort
}

#------------------------------------------------------------------------


declare -rA fields=( ['authority_key_identifier']='X509v3 Authority Key Identifier:'
                     ['basic_constraints']='X509v3 Basic Constraints:'
                     ['issuer']='Issuer:'
                     ['subject']='Subject:'
                     ['subject_key_identifier']='X509v3 Subject Key Identifier:' )

cd '/c/Downloads/work.certs/k8s' || exit
IFS=$'\n\t'

main
