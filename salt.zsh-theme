# vim:ft=zsh ts=2 sw=2 sts=2
#
# prompt settings
PROMPT_DATE=${SALT_PROMPT_DATE:-false}
PROMPT_TIME=${SALT_PROMPT_TIME:-true}
PROMPT_VI=${SALT_PROMPT_VI:-true}
PROMPT_VENV=${SALT_PROMPT_VENV:-true}
PROMPT_GIT=${SALT_PROMPT_GIT:-true}
PROMPT_USER_SMART=${SALT_PROMPT_USER_SMART:-true}

SEGMENT_SEPARATOR="${SALT_SEGMENT_SEPARATOR:-}"
ENDL_SEPARATOR="${SALT_ENDL_SEPARATOR:-}"


#disable default venv prompt
"$PROMPT_VENV" && export VIRTUAL_ENV_DISABLE_PROMPT=true

CURRENT_BG='NONE'

# Vi mode indicators
#VICMD_INDICATOR="NORMAL"
#VIINS_INDICATOR="INSERT"
VICMD_INDICATOR="N"
VIINS_INDICATOR="I"

# Status symbols
SYMBOL_CMD_ERR="\u2718"
SYMBOL_ROOT="\u26a1"
SYMBOL_JOB="\u2699"

# Git symbols
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"

autoload -U colors && colors # needed for fg_bold and fg_no_bold

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != "$CURRENT_BG" ]]; then
    print -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    print -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n "$3"
}

# Vi mode
prompt_vi_mode() {
  local color mode
  is_normal() {
    test -n "${${KEYMAP/vicmd/$VICMD_INDICATOR}/(main|viins)/}"  # param expans
  }
  if is_normal; then
    color=green
    mode="$VICMD_INDICATOR"
  else
    color=blue
    mode="$VIINS_INDICATOR"
  fi
  # shellcheck disable=SC2154
  prompt_segment $color white "%{${fg_bold[white]}%}$mode%{${fg_no_bold[white]}%}"
}


# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    print -n " %{%k%F{$CURRENT_BG}%}$ENDL_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ -n "$SSH_CLIENT" ]]; then
    prompt_segment magenta white "%{${fg_bold[white]}%(!.%{%F{white}%}.)%}$USER@%m%{${fg_no_bold[white]}%}"
  else
    if ! "$PROMPT_USER_SMART" || [ "$UID" -ne 1000 ]; then
      prompt_segment yellow magenta "%{${fg_bold[magenta]}%(!.%{%F{magenta}%}.)%}$USER%{${fg_no_bold[magenta]}%}"
    fi
  fi
}

prompt_git() {
  # if not inside git repo do nothing
  if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]; then
    return;
  fi

  local ref dirty mode repo_path clean has_upstream
  local modified untracked added deleted tagged stashed
  local ready_commit git_status bgclr fgclr
  local commits_diff commits_ahead commits_behind has_diverged to_push to_pull

  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  dirty=$(git status --porcelain --ignore-submodules="${GIT_STATUS_IGNORE_SUBMODULES:-dirty}" 2> /dev/null | tail -n1)
  git_status=$(git status --porcelain 2> /dev/null)
  ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
  if [[ -n $dirty ]]; then
    clean=''
    bgclr='yellow'
    fgclr='black'
  else
    clean=' ✔'
    bgclr='green'
    fgclr='white'
  fi

  local upstream; upstream=$(git rev-parse --symbolic-full-name --abbrev-ref "@{upstream}" 2> /dev/null)
  if [[ -n "${upstream}" && "${upstream}" != "@{upstream}" ]]; then has_upstream=true; fi

  local current_commit_hash; current_commit_hash=$(git rev-parse HEAD 2> /dev/null)

  local number_of_untracked_files; number_of_untracked_files=$(\grep -c "^??" <<< "${git_status}")
  # if [[ $number_of_untracked_files -gt 0 ]]; then untracked=" $number_of_untracked_files◆"; fi
  if [[ $number_of_untracked_files -gt 0 ]]; then untracked=" $number_of_untracked_files☀"; fi

  local number_added; number_added=$(\grep -c "^A" <<< "${git_status}")
  if [[ $number_added -gt 0 ]]; then added=" $number_added✚"; fi

  local number_modified; number_modified=$(\grep -c "^.M" <<< "${git_status}")
  if [[ $number_modified -gt 0 ]]; then
    modified=" $number_modified●"
    bgclr='red'
    fgclr='white'
  fi

  local number_added_modified; number_added_modified=$(\grep -c "^M" <<< "${git_status}")
  local number_added_renamed; number_added_renamed=$(\grep -c "^R" <<< "${git_status}")
  if [[ $number_modified -gt 0 && $number_added_modified -gt 0 ]]; then
    modified="$modified$((number_added_modified+number_added_renamed))$PLUSMINUS"
  elif [[ $number_added_modified -gt 0 ]]; then
    modified=" ●$((number_added_modified+number_added_renamed))$PLUSMINUS"
  fi

  local number_deleted; number_deleted=$(\grep -c "^.D" <<< "${git_status}")
  if [[ $number_deleted -gt 0 ]]; then
    deleted=" $number_deleted‒"
    bgclr='red'
    fgclr='white'
  fi

  local number_added_deleted; number_added_deleted=$(\grep -c "^D" <<< "${git_status}")
  if [[ $number_deleted -gt 0 && $number_added_deleted -gt 0 ]]; then
    deleted="$deleted$number_added_deleted$PLUSMINUS"
  elif [[ $number_added_deleted -gt 0 ]]; then
    deleted=" ‒$number_added_deleted$PLUSMINUS"
  fi

  local tag_at_current_commit; tag_at_current_commit=$(git describe --exact-match --tags "$current_commit_hash" 2> /dev/null)
  if [[ -n $tag_at_current_commit ]]; then tagged=" ☗$tag_at_current_commit "; fi

  local number_of_stashes; number_of_stashes="$(git stash list 2> /dev/null | wc -l)"
  if [[ $number_of_stashes -gt 0 ]]; then
    stashed=" ${number_of_stashes##*(  )}⚙"
#    bgclr='magenta'
#    fgclr='white'
  fi

  if [[ $number_added -gt 0 || $number_added_modified -gt 0 || $number_added_deleted -gt 0 ]]; then ready_commit=' ⚑'; fi

  local upstream_prompt=''
  if [[ $has_upstream == true ]]; then
    commits_diff="$(git log --pretty=oneline --topo-order --left-right "${current_commit_hash}...${upstream}" 2> /dev/null)"
    commits_ahead=$(\grep -c "^<" <<< "$commits_diff")
    commits_behind=$(\grep -c "^>" <<< "$commits_diff")
    upstream_prompt="$(git rev-parse --symbolic-full-name --abbrev-ref "@{upstream}" 2> /dev/null)"
    upstream_prompt=$(sed -e 's/\/.*$/ ☊ /g' <<< "$upstream_prompt")
  fi

  has_diverged=false
  if [[ $commits_ahead -gt 0 && $commits_behind -gt 0 ]]; then has_diverged=true; fi
  if [[ $has_diverged == false && $commits_ahead -gt 0 ]]; then
    if [[ $bgclr == 'red' || $bgclr == 'magenta' ]]; then
      to_push=" ${fg_bold[white]}↑$commits_ahead${fg_bold[$fgclr]}"
    else
      to_push=" ${fg_bold[black]}↑$commits_ahead${fg_bold[$fgclr]}"
    fi
  fi
  if [[ $has_diverged == false && $commits_behind -gt 0 ]]; then to_pull=" ${fg_bold[magenta]}↓$commits_behind${fg_bold[$fgclr]}"; fi

  if [[ -e "${repo_path}/BISECT_LOG" ]]; then
    mode=" <B>"
  elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
    mode=" >M<"
  elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
    mode=" >R>"
  fi

  prompt_segment $bgclr $fgclr

  print -n "%{${fg_bold[$fgclr]}%}${ref/refs\/heads\//$BRANCH $upstream_prompt}${mode}$to_push$to_pull$clean$tagged$stashed$untracked$modified$deleted$added$ready_commit%{${fg_no_bold[$fgclr]}%}"
}


# Dir: current working directory
prompt_dir() {
  prompt_segment blue white "%{${fg_bold[white]}%}%~%{${fg_no_bold[white]}%}"
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path ]]; then
    prompt_segment white black " $(basename "$virtualenv_path")"
  fi
}

prompt_date() {
  prompt_segment cyan white "%{${fg_bold[white]}%}%D{%Y-%m-%d}%{${fg_no_bold[white]}%}"
}

prompt_time() {
  prompt_segment cyan white "%{${fg_bold[white]}%}%D{%H:%M}%{${fg_no_bold[white]}%}"
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=""
  [[ $RETVAL -ne 0 ]] && symbols="$symbols%{%F{red}%}$SYMBOL_CMD_ERR $RETVAL"
  [[ $UID -eq 0 ]] && symbols="$symbols%{%F{yellow}%}$SYMBOL_ROOT"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols="$symbols%{%F{cyan}%}$SYMBOL_JOB"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_status
  "$PROMPT_DATE" && prompt_date
  "$PROMPT_TIME" && prompt_time
  prompt_context
  prompt_dir
  "$PROMPT_VENV" && prompt_virtualenv
  "$PROMPT_GIT" && prompt_git
  prompt_end
  CURRENT_BG='NONE'
  print -n "\n"
  "$PROMPT_VI" && prompt_vi_mode
  prompt_end
}

# shellcheck disable=SC2016,SC2034
PROMPT='%{%f%b%k%}$(build_prompt) '
