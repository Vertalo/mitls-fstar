#!/usr/bin/env bash

#set -x

target=$1
out_file=$2
threads=$3
branchname=$4

function export_home() {
    local home_path=""
    if command -v cygpath >/dev/null 2>&1; then
        home_path=$(cygpath -m "$2")
    else
        home_path="$2"
    fi

    export $1_HOME=$home_path

    # Update .bashrc file
    token=$1_HOME=
    if grep -q "$token" ~/.bashrc; then
        sed -i -E "s/$token.*/$token$home_path/" ~/.bashrc
    else
        echo "export $1_HOME=$home_path" >> ~/.bashrc
    fi
}

# By default, HACL* master works against F* stable. Can also be overridden.
function fetch_hacl() {
    if [ ! -d hacl-star ]; then
        git clone https://github.com/mitls/hacl-star hacl-star
    fi

    cd hacl-star
    git fetch origin
    local ref=$(if [ -f ../.hacl_version ]; then cat ../.hacl_version | tr -d '\r\n'; else echo origin/master; fi)
    echo Switching to HACL $ref
    git reset --hard $ref
    git clean -fdx
    cd ..
    export_home HACL "$(pwd)/hacl-star"
    export_home EVERCRYPT "$(pwd)/hacl-star/providers"
}

# By default, kremlin master works against F* stable. Can also be overridden.
function fetch_kremlin() {
    if [ ! -d kremlin ]; then
        git clone https://github.com/FStarLang/kremlin kremlin
    fi

    cd kremlin
    git fetch origin
    local ref=$(if [ -f ../.kremlin_version ]; then cat ../.kremlin_version | tr -d '\r\n'; else echo origin/master; fi)
    echo Switching to KreMLin $ref
    git reset --hard $ref
    cd ..
    export_home KREMLIN "$(pwd)/kremlin"
}

function fetch_and_make_kremlin() {
    fetch_kremlin

    # Default build target is minimal, unless specified otherwise
    local target
    if [[ $1 == "" ]]; then
        target="minimal"
    else
        target="$1"
    fi

    make -C kremlin -j $threads $target ||
        (cd kremlin && git clean -fdx && make -j $threads $target)
    OTHERFLAGS='--admit_smt_queries true' make -C kremlin/kremlib -j $threads
    export PATH="$(pwd)/kremlin:$PATH"
}

function fetch_qd() {
    if [ ! -d qd ]; then
        git clone https://github.com/project-everest/quackyducky qd
    fi

    cd qd
    git fetch origin
    local ref=$(if [ -f ../.qd_version ]; then cat ../.qd_version | tr -d '\r\n'; else echo origin/master; fi)
    echo Switching to QuackyDucky $ref
    git reset --hard $ref
    cd ..
    export_home QD "$(pwd)/qd"
}

function fetch_and_make_qd() {
    fetch_qd

    # Default build target is quackyducky, unless specified otherwise
    local target
    if [[ $1 == "" ]]; then
        target="quackyducky"
    else
        target="$1"
    fi

    make -C qd -j $threads $target ||
        (cd qd && git clean -fdx && make -j $threads $target)
}

function fetch_mlcrypto() {
    if [ ! -d mlcrypto ]; then
        git clone https://github.com/project-everest/MLCrypto mlcrypto
    fi

    cd mlcrypto
    git fetch origin
    local ref=$(if [ -f ../.mlcrypto_version ]; then cat ../.mlcrypto_version | tr -d '\r\n'; else echo origin/master; fi)
    echo Switching to MLCrypto $ref
    git reset --hard $ref
    git submodule update
    cd ..
    export_home MLCRYPTO "$(pwd)/mlcrypto"
    export_home OPENSSL "$(pwd)/mlcrypto/openssl"
}

function fetch_and_make_mlcrypto() {
    fetch_mlcrypto
    make -C mlcrypto -j $threads
}

function build_pki_if() {
    if [[ -d src/pki ]]; then
        make -C src/pki -j $threads
    fi
}

function mitls_verify() {
    export_home MITLS "$(pwd)"

    # Figure out the branch
    CI_BRANCH=${branchname##refs/heads/}
    echo "Current branch_name=$CI_BRANCH"

    fetch_and_make_kremlin all &&
    fetch_and_make_qd &&
    # Build LowParse first, it is a dependency of miTLS anyway
    make -C src/lowparse -f Makefile.LowParse -j $threads -k &&
    { echo false > lowparse_examples_success ; } &&
    { echo false > mitls_success ; } && {
        # Perform LowParse CI and miTLS CI in parallel
        {
            # Test LowParse examples
            make -C src/lowparse -f Makefile.LowParseExamples -j $threads -k &&
            { echo true > lowparse_examples_success ; }
        } &
        {
            if echo "$CI_BRANCH" | grep '^taramana_lowparse_ci_' ; then
                echo This is a LowParse CI-only branch. No miTLS CI here.
            else
                # miTLS CI proper starts here
                fetch_hacl &&
                    fetch_and_make_mlcrypto &&
                    # Only building a subset of HACL* for now
                    make -C hacl-star/code extract-c -j $threads &&
                    OTHERFLAGS="--admit_smt_queries true $OTHERFLAGS" make -C hacl-star/providers -j $threads &&
                    make -C hacl-star/secure_api -j $threads &&
                    make -C libs/ffi -j $threads &&
                    build_pki_if &&
                    make -C src/tls -j $threads all -k &&
                    make -C src/tls -j $threads test -k
            fi &&
            { echo true > mitls_success ; }
        } &
        wait
    } &&
    $(cat lowparse_examples_success) &&
    $(cat mitls_success)
}

function mitls_verify_and_hints() {
    mitls_verify && refresh_mitls_hints
}

function refresh_mitls_hints() {
    # We should not generate hints when building on Windows
    if [[ "$OS" != "Windows_NT" ]]; then
        refresh_hints "git@github.com:mitls/mitls-fstar.git" "true" "regenerate hints" "src"
    fi
}

# Note: this performs an _approximate_ refresh of the hints, in the sense that
# since the hint refreshing job takes about 80 minutes, it's very likely someone
# merged to $CI_BRANCH in the meanwhile, which would invalidate some hints. So, we
# reset to origin/$CI_BRANCH, take in our hints, and push. This is short enough that
# the chances of someone merging in-between fetch and push are low.
function refresh_hints() {
    local remote=$1
    local extra="$2"
    local msg="$3"
    local hints_dir="$4"

    # Figure out the branch
    CI_BRANCH=${branchname##refs/heads/}
    echo "Current branch_name=$CI_BRANCH"

    # Add all the hints, even those not under version control
    find $hints_dir -iname '*.hints' -and -not -path '*/.*' -and -not -path '*/dependencies/*' | xargs git add

    # Without the eval, this was doing weird stuff such as,
    # when $2 = "git ls-files src/ocaml-output/ | xargs git add",
    # outputting the list of files to stdout
    eval "$extra"

    git commit --allow-empty -m "[CI] $msg"

    # Memorize that commit
    commit=$(git rev-parse HEAD)

    # Drop any other files that were modified as part of the build (e.g.
    # parse.fsi)
    git reset --hard HEAD

    # Move to whatever is the most recent master (that most likely changed in the
    # meantime)
    git fetch
    git checkout $CI_BRANCH
    git reset --hard origin/$CI_BRANCH

    # Silent, always-successful merge
    export GIT_MERGE_AUTOEDIT=no
    git merge $commit -Xtheirs

    # Push.
    git push $remote $CI_BRANCH
}

function exec_build() {

    result_file="../result.txt"
    local status_file="../status.txt"
    echo -n false >$status_file

    if [ ! -f miTLS_icla.txt ]; then
        echo "I don't seem to be in the right directory, bailing"
        echo Failure >$result_file
        return
    fi

    if [[ $target == "mitls_verify" ]]; then
        echo "target -> mitls_verify"
        mitls_verify && echo -n true >$status_file
    elif [[ $target == "mitls_verify_and_hints" ]]; then
        echo "target -> mitls_verify_and_hints"
        export OTHERFLAGS="--record_hints $OTHERFLAGS"
        mitls_verify_and_hints && echo -n true >$status_file
    else
        echo "Invalid target"
        echo Failure >$result_file
        return
    fi

    if [[ $(cat $status_file) != "true" ]]; then
        echo "Build failed"
        echo Failure >$result_file
    else
        echo "Build succeeded"
        echo Success >$result_file
    fi
}

# Some environment variables we want
export OCAMLRUNPARAM=b
export OTHERFLAGS="--print_z3_statistics --use_hints --query_stats"
export MAKEFLAGS="$MAKEFLAGS -Otarget"

export_home FSTAR "$(pwd)/FStar"
cd mitls-fstar
exec_build
cd ..
