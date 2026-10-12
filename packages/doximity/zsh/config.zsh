#!/usr/bin/env zsh

cdpath=(. ~ ~/src $WORKSPACE $WORKSPACE/doximity)

export OP_ACCOUNT=doximity.1password.com
export DOXCLI_GITHUB_TOKEN=op://Employee/GitHub/credentials/token
export GITHUB_TOKEN=op://Employee/GitHub/credentials/token

PATH=$PATH:$WORKSPACE/doximity/works-on-my-machine/bin
PATH=$PATH:$HOME/.local/bin

eval "$("/Users/jhoyt/src/doximity/dox-compose/bin/dox-init")"

# [Certiv Scout CA merge v2]
[ -r "/Library/Application Support/ai.certiv.scout/ca-merge.sh" ] && . "/Library/Application Support/ai.certiv.scout/ca-merge.sh"
# [/Certiv Scout CA merge v2]

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
