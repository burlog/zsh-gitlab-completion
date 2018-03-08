# load functions from git completer to backup standard _git-clone function
_git 2>/dev/null
functions[_old_git-clone]=$functions[_git-clone]

# function to access gitlab api
function gitlab_kancl_call() {
    curl \
        --header "Private-Token: ${GIT_CLONE_ZSH_CMPL_AUTH_TOKEN}" \
        "https://${GIT_CLONE_ZSH_CMPL_HOST}/api/v4/$1" -s 2>/dev/null | jq -r $2 2>/dev/null
}

# function that says the zsh completion system when it should invalidated the cache
_git-clone_caching_policy() {
    local -a oldp
    oldp=("$1"(Nmh+1)) # 1 hour
    (($#oldp))
}

# override _git-clone
function _git-clone() {
    local curcontext="$curcontext" state expl

    local cache_policy
    zstyle -s ":completion:${curcontext}:" cache-policy cache_policy
    if [[ -z "$cache_policy" ]]; then
        zstyle ":completion:${curcontext}:" cache-policy _git-clone_caching_policy
    fi

    case "$words[CURRENT]" in
        *${GIT_CLONE_ZSH_CMPL_HOST}:*)
            # we know how to complete repositories gitlab.kancelar.seznam.cz
            if compset -P 1 "*:"; then
                if compset -P "*/"; then
                    # path phase
                    declare -a repos
                    id="`echo "$words[CURRENT]" | sed 's/[^:]*:\([^/]\+\)\/.*/\1/g'`"
                    if [[ "$words[CURRENT]" =~ ".*/$" ]]; then
                        if _cache_invalid _git-clone_gitlab_kancl_repos-$id || ! _retrieve_cache _git-clone_gitlab_kancl_repos-$id; then
                            repos=("${(@f)$(gitlab_kancl_call "groups/$id/projects?per_page=100&order_by=path&simple=true" ".[]|.path")}")
                            if [[ -z "$repos[1]" ]]; then # jq returns always at least 1 one which (f) turns to array with one empty element
                                repos=("${(@f)$(gitlab_kancl_call "users/$id/projects?per_page=100&simple=true" ".[]|.path")}")
                            fi
                            _store_cache _git-clone_gitlab_kancl_repos-$id repos
                        fi
                        compadd -M 'M:{[:lower:][:upper:]}={[:upper:][:lower:]}' "$@" $repos
                    else
                        prefix="`echo "$words[CURRENT]" | sed 's/[^/]*\/\(.\+\)/\1/g'`"
                        if _cache_invalid _git-clone_gitlab_kancl_repos-$id-prefix-$prefix || ! _retrieve_cache _git-clone_gitlab_kancl_repos-$id-prefix-$prefix; then
                            repos=("${(@f)$(gitlab_kancl_call "groups/$id/projects?per_page=100&order_by=path&simple=true&search=$prefix" ".[]|.path")}")
                            if [[ -z "$repos[1]" ]]; then # jq returns always at least 1 one which (f) turns to array with one empty element
                                repos=("${(@f)$(gitlab_kancl_call "users/$id/projects?per_page=100&simple=true&search=$prefix" ".[]|.path")}")
                            fi
                            _store_cache _git-clone_gitlab_kancl_repos-$id-prefix-$prefix repos
                        fi
                        compadd -M 'M:{[:lower:][:upper:]}={[:upper:][:lower:]}' -M 'l:|=*' "$@" $repos
                    fi
                else
                    # groups phase
                    declare -a groups
                    if [[ "$words[CURRENT]" =~ ".*:$" ]]; then
                        if _cache_invalid _git-clone_gitlab_kancl_groups || ! _retrieve_cache _git-clone_gitlab_kancl_groups; then
                            groups=("${(@f)$(gitlab_kancl_call "namespaces" ".[]|.path")}")
                            _store_cache _git-clone_gitlab_kancl_groups groups
                        fi
                        compadd -M 'M:{[:lower:][:upper:]}={[:upper:][:lower:]}' -S/ "$@" $groups
                    else
                        prefix="`echo "$words[CURRENT]" | sed 's/[^:]*:\(.\+\)/\1/g'`"
                        if _cache_invalid _git-clone_gitlab_kancl_groups-$prefix || ! _retrieve_cache _git-clone_gitlab_kancl_groups-$prefix; then
                            groups=("${(@f)$(gitlab_kancl_call "groups?per_page=100&all_available=true&search=$prefix" ".[]|.path")}")
                            groups+=("${(@f)$(gitlab_kancl_call "users?per_page=100&all_available=true&search=$prefix" ".[]|.username")}")
                            _store_cache _git-clone_gitlab_kancl_groups-$prefix groups
                        fi
                        compadd -M 'M:{[:lower:][:upper:]}={[:upper:][:lower:]}' -M 'l:|=*' -S/ "$@" $groups
                    fi
                fi
            fi
            ;;
        *)
            # if it don't match the known server pass to standard completer
            _old_git-clone "$@"
            ;;
    esac

    return 0
}

