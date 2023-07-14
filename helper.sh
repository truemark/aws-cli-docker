#!/usr/bin/env bash

[[ "${BASH_VERSINFO:-0+x}" -lt 4 ]] && >&2 echo "bash 4 or greater required" && exit 1

# Prints arguments if DEBUG environment variable is set to true
function debug() {
  if [[ -n "${DEBUG+x}" ]] && [[ "${DEBUG}" == "true" ]]; then
    echo "${*}"
  fi
}

# Turns off the AWS pager exporting the AWS_PAGER variable
function aws_pager_off() {
  export AWS_PAGER=""
}

# This function requires the following variables be set
#  AWS_ACCESS_KEY_ID
#  AWS_SECRET_ACCESS_KEY
# This function will export the variables above to make them available to child processes.
function aws_default_authentication() {
  debug "Calling aws_default_authentication()"
  : "${AWS_ACCESS_KEY_ID:?'is a required variable'}"
  : "${AWS_SECRET_ACCESS_KEY:?'is a required variable'}"
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  debug "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
}
# This function can optionally set the following variable
#  AWS_ROLE_SESSION_DURATION (optional, default is 3600)

# This function requires the following variables be set
#  AWS_WEB_IDENTITY_TOKEN or AWS_WEB_IDENTITY_TOKEN_FILE
#  AWS_ROLE_ARN or AWS_OIDC_ROLE_ARN or CODEARTIFACT_OIDC_ROLE_ARN
# If not already set, this function will set AWS_WEB_IDENTITY_TOKEN_FILE and export
# the AWS_WEB_IDENTITY_TOKEN_FILE and AWS_ROLE_ARN variables.
function aws_oidc_authentication() {
  debug "Calling aws_oidc_authentication()"

  # BitBucket has standardized on AWS_OIDC_ROLE_ARN in most their pipes
  if [[ -n "${AWS_OIDC_ROLE_ARN+x}" ]]; then
    AWS_ROLE_ARN="${AWS_OIDC_ROLE_ARN}"
    AWS_ROLE_ARN=${AWS_ROLE_ARN:?'is a required variable or AWS_OIDC_ROLE_ARN must be set'}
    debug "AWS_ROLE_ARN=${AWS_ROLE_ARN}"
  fi

  if [[ -n "${AWS_WEB_IDENTITY_TOKEN+x}" ]]; then
    [[ "${AWS_WEB_IDENTITY_TOKEN}" == "" ]] && >&2 echo "AWS_WEB_IDENTITY_TOKEN was provided and is empty" && exit 1
    AWS_WEB_IDENTITY_TOKEN_FILE="$(mktemp -t web_identity_token.XXXXXXX)"
    chmod 600 "${AWS_WEB_IDENTITY_TOKEN_FILE}"
    echo "${AWS_WEB_IDENTITY_TOKEN}" >> "${AWS_WEB_IDENTITY_TOKEN_FILE}"
  fi

  : "${AWS_WEB_IDENTITY_TOKEN_FILE:?'is a required variable or AWS_WEB_IDENTITY_TOKEN must be set'}"
  debug "AWS_WEB_IDENTITY_TOKEN_FILE=${AWS_WEB_IDENTITY_TOKEN_FILE}"
  export AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN
}

# Unsets variables used by AWS CLI & SDK for authentication
function aws_clear_authentication() {
  debug "Calling aws_clear_authentication()"
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN
  debug "Cleared authentication variables"
}

# Pushes authentication variables into the exported variable AWS_AUTHENTICATION_HISTORY
function aws_push_authentication_history() {
  debug "Calling aws_push_authentication_history()"
  [[ -z "${AWS_AUTHENTICATION_HISTORY+x}" ]] && declare -a arr
  [[ -n "${AWS_AUTHENTICATION_HISTORY+x}" ]] && mapfile -t arr <<< "${AWS_AUTHENTICATION_HISTORY}"
  local line=""
  [[ -n "${AWS_ACCESS_KEY_ID+x}" ]] && line="${line}export AWS_ACCESS_KEY_ID=\"${AWS_ACCESS_KEY_ID}\";"
  [[ -n "${AWS_SECRET_ACCESS_KEY+x}" ]] && line="${line}export AWS_SECRET_ACCESS_KEY=\"${AWS_SECRET_ACCESS_KEY}\";"
  [[ -n "${AWS_SESSION_TOKEN+x}" ]] && line="${line}export AWS_SESSION_TOKEN=\"${AWS_SESSION_TOKEN}\";"
  [[ -n "${AWS_WEB_IDENTITY_TOKEN_FILE+x}" ]] && line="${line}export AWS_WEB_IDENTITY_TOKEN_FILE=\"${AWS_WEB_IDENTITY_TOKEN_FILE}\";"
  [[ -n "${AWS_ROLE_ARN+x}" ]] && line="${line}export AWS_ROLE_ARN=\"${AWS_ROLE_ARN}\";"
  arr+=("${line}")
  AWS_AUTHENTICATION_HISTORY="$(IFS=$'\n'; echo "${arr[*]}")"
  export AWS_AUTHENTICATION_HISTORY
  debug "Pushed entry onto AWS_AUTHENTICATION_HISTORY"
}

# Pops authentication variables from AWS_AUTHENTICATION_HISTORY and unsets the variable if empty
function aws_pop_authentication_history() {
  debug "Calling aws_pop_authentication_history()"
  : "${AWS_AUTHENTICATION_HISTORY:?'variable is required'}"
  mapfile -t arr <<< "${AWS_AUTHENTICATION_HISTORY}"
  aws_clear_authentication
  eval "${arr[*]: -1}"
  unset 'arr[${#arr[@]}]'
  if [[ "${#arr[@]}" == "0" ]]; then
    unset AWS_AUTHENTICATION_HISTORY
  else
    AWS_AUTHENTICATION_HISTORY="$(IFS=$'\n'; echo "${arr[*]}")"
    export AWS_AUTHENTICATION_HISTORY
  fi
  debug "Popped entry off AWS_AUTHENTICATION_HISTORY"
}

# This function can optionally set the following variable
#  AWS_ROLE_SESSION_DURATION (optional, default is 3600)
# This function requires the following variables be set
#  AWS_ASSUME_ROLE_ARN
#  AWS_ROLE_SESSION_NAME
# This function optionally accepts the following variable
#  AWS_ROLE_SESSION_DURATION
# This function will export the following variables
#  AWS_ACCESS_KEY_ID
#  AWS_SECRET_ACCESS_KEY
#  AWS_SESSION_TOKEN
#  AWS_AUTHENTICATION_HISTORY
function aws_assume_role() {
  debug "Calling aws_assume_role()"
  : "${AWS_ROLE_SESSION_NAME:?'variable is required'}"
  : "${AWS_ASSUME_ROLE_ARN:?'variable is required'}"
  ! command -v aws &> /dev/null && echo "aws command is missing" && exit 1
  ! command -v jq &> /dev/null && echo "jq command is missing" && exit 1

  # Fill in replacement variables
  local assume_role_arn_expanded
  assume_role_arn_expanded="$(eval "echo -n ${AWS_ASSUME_ROLE_ARN}")"
  debug "assume_role_arn_expanded=${assume_role_arn_expanded}"

  # Save the current state
  aws_push_authentication_history

  # Get the STS credentials and set them up for use
  local aws_sts_result
  local duration="${AWS_ROLE_SESSION_DURATION:-3600}"
  aws_sts_result=$(aws sts assume-role --role-arn "${assume_role_arn_expanded}" --role-session-name "${AWS_ROLE_SESSION_NAME}" --duration-seconds "${duration}")
  aws_clear_authentication
  AWS_ACCESS_KEY_ID=$(echo "${aws_sts_result}" | jq -r .Credentials.AccessKeyId)
  AWS_SECRET_ACCESS_KEY=$(echo "${aws_sts_result}" | jq -r .Credentials.SecretAccessKey)
  AWS_SESSION_TOKEN=$(echo "${aws_sts_result}" | jq -r .Credentials.SessionToken)
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
}

# Calls aws_assume_role if AWS_ASSUME_ROLE_ARN is set
function if_aws_assume_role() {
  debug "Calling if_aws_assume_role()"
  if [[ -n "${AWS_ASSUME_ROLE_ARN+x}" ]] && [[ "${AWS_ASSUME_ROLE_ARN}" != "" ]]; then
    aws_assume_role
  else
    debug "Skipping assume role"
  fi
}

# Entry function for AWS authentication which either uses default
# authentication or OIDC depending on what's set
#   AWS Default authentication requires:
#    - AWS_ACCESS_KEY_ID
#    - AWS_SECRET_ACCESS_KEY
#   AWS OIDC authentication requires:
#    - AWS_WEB_IDENTITY_TOKEN or AWS_WEB_IDENTITY_TOKEN_FILE
#    - AWS_ROLE_ARN
function aws_authentication() {
  debug "Calling aws_authentication()"
  if [[ -n "${AWS_WEB_IDENTITY_TOKEN+x}${AWS_WEB_IDENTITY_TOKEN_FILE+x}${AWS_ROLE_ARN+x}${AWS_OIDC_ROLE_ARN+x}" ]]; then
    debug "Using aws_oidc_authentication"
    aws_oidc_authentication
  elif [[ -n "${AWS_ACCESS_KEY_ID+x}" ]]; then
    debug "Using aws_default_authentication"
    aws_default_authentication
  else
    debug "Skipping AWS authentication"
  fi
}

# Exports variable AWS_ACCOUNT_ID containing the current caller's account ID
function aws_account_id() {
  debug "Calling aws_account_id()"
  debug "Obtaining current AWS account ID"
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
  export AWS_ACCOUNT_ID
  debug "AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
}

# Executes aws_account_id if AWS_ACCESS_KEY_ID is set
function if_aws_account_id() {
  debug "Calling if_aws_account_id()"
  if [[ -n "${AWS_ACCESS_KEY_ID+x}" ]]; then
    aws_account_id
  fi
}

# Obtains all AWS acount IDs in the caller's AWS organization, optionally filters
# them and then exports AWS_ACCOUNT_IDS containing the filtered result set.
#
# This function has the following optional variables as inputs which are used to
# filter down the list of accounts retrieved from the AWS organization
#   - AWS_EXCLUDE_ACCOUNT_IDS
#   - AWS_EXCLUDE_OU_IDS
function aws_organization_account_ids() {
  debug "Calling aws_organization_account_ids()"
  debug "Obtaining accounts from organization"
  AWS_ACCOUNT_IDS="$(aws organizations list-accounts --query 'Accounts[].[Id]' --output text --max-items 10000)"

  # Remove current account from list
  local id
  id=$(aws sts get-caller-identity --query 'Account' --output text)
  AWS_ACCOUNT_IDS="$(echo "${AWS_ACCOUNT_IDS}" | grep -v "${id}")"

  # Remove any accounts provided as arguments to the function
  for id in "${@}"; do
    AWS_ACCOUNT_IDS="$(echo "${AWS_ACCOUNT_IDS}" | grep -v "${id}")"
  done

  # Remove any accounts provided in AWS_EXCLUDE_ACCOUNT_IDS
  if [[ -n "${AWS_EXCLUDE_ACCOUNT_IDS+x}" ]]; then
    for id in ${AWS_EXCLUDE_ACCOUNT_IDS}; do
      AWS_ACCOUNT_IDS="$(echo "${AWS_ACCOUNT_IDS}" | grep -v "${id}")"
    done
  fi

  # Remove any accounts from OUs provided in AWS_EXCLUDE_OU_IDS
  if [[ -n "${AWS_EXCLUDE_OU_IDS+x}" ]]; then
    for oid in ${AWS_EXCLUDE_OU_IDS}; do
      for id in $(aws organizations list-accounts-for-parent --parent-id "${oid}" --query 'Accounts[].[Id]' --output text --max-items 10000); do
        AWS_ACCOUNT_IDS="$(echo "${AWS_ACCOUNT_IDS}" | grep -v "${id}")"
      done
    done
  fi

  export AWS_ACCOUNT_IDS
  debug "AWS_ACCOUNT_IDS=${AWS_ACCOUNT_IDS}"
}

# Unlocks a repository with git-crypt. One of the following variables must be set
#  GIT_CRYPT_KEY - base64 encoded symmetric encryption key
#  GIT_CRYPT_KEY_FILE - location of the encryption key
function git_crypt_unlock() {
  debug "Calling git_crypt_unlock()"
  ! command -v git-crypt &> /dev/null && echo "git-crypt command is missing" && exit 1
  ! command -v base64 &> /dev/null && echo "base64 command is missing" && exit 1
  if [[ -n "${GIT_CRYPT_KEY+x}" ]] && [[ "${GIT_CRYPT_KEY}" != "" ]]; then
    keyfile="$(mktemp -t git_crypt_key.XXXXXXX)"
    chmod 600 "${keyfile}"
    echo -n "${GIT_CRYPT_KEY}" | base64 -d >> "${keyfile}"
    debug "Running git-crypt unlock \"${keyfile}\""
    git-crypt unlock "${keyfile}"
    rm -f "${keyfile}"
    return
  fi
  : "${GIT_CRYPT_KEY_FILE:?'is a required variable or GIT_CRYPT_KEY must be set to a non empty string'}"
  debug "GIT_CRYPT_KEY_FILE=${GIT_CRYPT_KEY_FILE}"
  git-crypt unlock "${GIT_CRYPT_KEY_FILE}"
}

# Calls git_crypt_unlock if GIT_CRYPT_KEY or GIT_CRYPT_KEY_FILE is set
function if_git_crypt_unlock() {
  debug "Calling if_git_crypt_unlock()"
  if [[ -n "${GIT_CRYPT_KEY+x}" ]] && [[ "${GIT_CRYPT_KEY}" != "" ]]; then
    git_crypt_unlock
  elif [[ -n "${GIT_CRYPT_KEY_FILE+x}" ]] && [[ "${GIT_CRYPT_KEY_FILE}" != "" ]]; then
    git_crypt_unlock
  else
    debug "Skipping git-crypt unlock"
  fi
}

# Changes the current directory if LOCAL_PATH is set
function if_local_path() {
  debug "Calling if_local_path()"
  if [[ -n "${LOCAL_PATH+x}" ]]; then
    debug "Changing working directories"
    cd "${LOCAL_PATH}" || exit 1
    debug "LOCAL_PATH=${LOCAL_PATH}"
  fi
}

function parse_repository_arn() {
  if [[ -n "${value}" ]]; then ## if called from if_codeartifact
    debug "Parsing repository arn for repository: ${value}"
    # parse the ARN to get the region, domain, and repository
    CODEARTIFACT_REGION=$(echo "${value}" | sed 's/arn:aws:codeartifact://' | sed 's/:.*//')
    CODEARTIFACT_DOMAIN=$(echo "${value}" | sed 's/arn:aws:codeartifact:.*:repository\///' | sed 's/\/.*//')
    CODEARTIFACT_REPO=$(echo "${value}" | sed 's/arn:aws:codeartifact:.*:repository\/.*\///')

  elif [[ "${CODEARTIFACT_REPOSITORY_ARN}" ]]; then ## if called from codeartifact_*_login
    debug "Parsing repository arn for repository: ${CODEARTIFACT_REPOSITORY_ARN}"
    # parse the ARN to get the region, domain, and repository
    CODEARTIFACT_REGION=$(echo "${CODEARTIFACT_REPOSITORY_ARN}" | sed 's/arn:aws:codeartifact://' | sed 's/:.*//')
    CODEARTIFACT_DOMAIN=$(echo "${CODEARTIFACT_REPOSITORY_ARN}" | sed 's/arn:aws:codeartifact:.*:repository\///' | sed 's/\/.*//')
    CODEARTIFACT_REPO=$(echo "${CODEARTIFACT_REPOSITORY_ARN}" | sed 's/arn:aws:codeartifact:.*:repository\/.*\///')
  else
    debug "No repository ARN detected."
  fi
}


function codeartifact_npm_login() {
  debug "Calling codeartifact_npm_login()"
  parse_repository_arn

  if [[ -n "${CODEARTIFACT_REGION}" ]] && [[ -n "${CODEARTIFACT_DOMAIN}" ]] && [[ -n "${CODEARTIFACT_REPO}" ]]; then
    ## if namespace found, login w/ --namespace option
    if [[ -n "${CODEARTIFACT_NPM_NAMESPACE}" ]]; then
      debug "Calling aws codeartifact login with npm namespace: ${CODEARTIFACT_NPM_NAMESPACE}"
      (aws codeartifact login --namespace "${CODEARTIFACT_NPM_NAMESPACE}" --tool npm --repository "${CODEARTIFACT_REPO}" --domain "${CODEARTIFACT_DOMAIN}" --region "${CODEARTIFACT_REGION}")

    ## if no namespace found login w/o --namespace option
    elif [[ -z "${CODEARTIFACT_NPM_NAMESPACE}" ]]; then
      debug "Calling aws codeartifact login without namespace"
      (aws codeartifact login --tool npm --repository "${CODEARTIFACT_REPO}" --domain "${CODEARTIFACT_DOMAIN}" --region "${CODEARTIFACT_REGION}")
    fi
  else
    debug "Required codeartifact login variables not found."
  fi
}

function if_codeartifact_npm_login() {
  debug "Calling if_codeartifact_npm_login()"
  if [[ $(command -v npm) ]]; then
    codeartifact_npm_login
  fi
}

function codeartifact_dotnet_login() {
  debug "Calling codeartifact_dotnet_login()"
  parse_repository_arn

  if [[ -n "${CODEARTIFACT_REGION}" ]] && [[ -n "${CODEARTIFACT_DOMAIN}" ]] && [[ -n "${CODEARTIFACT_REPO}" ]]; then
    (aws codeartifact login --tool dotnet --repository "${CODEARTIFACT_REPO}" --domain "${CODEARTIFACT_DOMAIN}" --region "${CODEARTIFACT_REGION}")
  else
    debug "Required codeartifact login variables not found."
  fi
}

function if_codeartifact_dotnet_login() {
  debug "Calling if_codeartifact_dotnet_login()"
  if [[ $(command -v dotnet) ]]; then
    codeartifact_dotnet_login
  fi
}

function codeartifact_maven_login() {
  debug "Calling codeartifact_maven_login()"
  debug "Note: Maven not supported by aws codeartifact login command; generating token."
  parse_repository_arn
  if_codeartifact_legacy
}

function if_codeartifact_maven_login() {
  debug "Calling if_codeartifact_maven_login()"
  if [[ $(command -v mvn) ]]; then
    codeartifact_maven_login
  fi
}

# retained for backwards compatibility
# Get authorization token for aws codeartifact
function codeartifact_legacy() {
  debug "Calling codeartifact_legacy()"
  if [ ! -d codeartifact ]; then
    mkdir codeartifact
  fi
  echo "export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token --domain "${AWS_CODEARTIFACT_DOMAIN}" \
    --domain-owner "${AWS_ACCOUNT_ID}" \
    --region "${AWS_DEFAULT_REGION}" \
    --query authorizationToken --output text)" > codeartifact/token

  debug "CODEARTIFACT_AUTH_TOKEN saved to file: codeartifact/token"
}

# retained for backwards compatibility
# Calls codeartifact_legacy if AWS_CODEARTIFACT_{DOMAIN,REPO} are set
function if_codeartifact_legacy() {
  debug "Calling if_codeartifact_legacy()"
  if [[ -n "${AWS_CODEARTIFACT_REPO+x}" ]] && [[ -n "${AWS_CODEARTIFACT_DOMAIN+x}" ]] ; then
    debug "Detected account: ${AWS_ACCOUNT_ID}"
    debug "Detected region: ${AWS_DEFAULT_REGION}"
    debug "Detected domain: ${AWS_CODEARTIFACT_DOMAIN}"
    debug "Detected repo: ${AWS_CODEARTIFACT_REPO}"

    codeartifact_legacy

  # Calls codeartifact_legacy if CODEARTIFACT_{REGION,DOMAIN} are set
  elif [[ -n "${CODEARTIFACT_DOMAIN+x}" ]] && [[ -n "${CODEARTIFACT_REGION+x}" ]]; then
    AWS_DEFAULT_REGION="${CODEARTIFACT_REGION}"
    AWS_CODEARTIFACT_DOMAIN="${CODEARTIFACT_DOMAIN}"

    debug "Detected account: ${AWS_ACCOUNT_ID}"
    debug "Detected region: ${AWS_DEFAULT_REGION}"
    debug "Detected domain: ${AWS_CODEARTIFACT_DOMAIN}"

    codeartifact_legacy
  else
    debug "Required codeartifact variables not found."
  fi
}

# Supports the following environment variables
# - CODEARTIFACT_REPOSITORY_ARN & CODEARTIFACT_*_REPOSITORY_ARN
# - CODEARTIFACT_NPM_NAMESPACE & CODEARTIFACT_*_NPM_NAMESPACE
# - CODEARTIFACT_OIDC_ROLE_ARN & CODEARTIFACT_*_OIDC_ROLE_ARN
# - AWS_CODEARTIFACT_ASSUME_ROLE_ARN & AWS_CODEARTIFACT_*_ASSUME_ROLE_ARN

function if_codeartifact() {
  (
    debug "Calling if_codeartifact()"
    CODEARTIFACT_ARN_SUFFIX="_REPOSITORY_ARN"
    CODEARTIFACT_ARN_COUNT=0
    for repository_arn in "${!CODEARTIFACT_@}"; do
      if [[ "${repository_arn}" == *"${CODEARTIFACT_ARN_SUFFIX}" ]]; then
        CODEARTIFACT_ARN_COUNT=$((CODEARTIFACT_ARN_COUNT+=1))
        value="${!repository_arn}"
        parse_repository_arn

        # Extract the value from the CODEARTIFACT_*_REPOSITORY_ARN variable
        local x
        x="${repository_arn#CODEARTIFACT_}"
        x="${x%_REPOSITORY_ARN}"

        debug "Checking for npm namespace match"
        # Check if there is a matching CODEARTIFACT_*_NPM_NAMESPACE variable
        npm_namespace_var="CODEARTIFACT_${x}_NPM_NAMESPACE"
        if [[ -n "${!npm_namespace_var}" ]]; then
          CODEARTIFACT_NPM_NAMESPACE=${!npm_namespace_var}
        fi

        debug "Checking for oidc role arn match"
        # Check if there is a matching CODEARTIFACT_*_OIDC_ROLE_ARN variable
        oidc_role_var="CODEARTIFACT_${x}_OIDC_ROLE_ARN"
        if [[ -n "${!oidc_role_var}" ]]; then
          debug "Calling aws_oidc_authentication"
          AWS_OIDC_ROLE_ARN=${!oidc_role_var}
          aws_oidc_authentication
        elif [[ -n "${CODEARTIFACT_OIDC_ROLE_ARN}" ]]; then
          AWS_OIDC_ROLE_ARN=${CODEARTIFACT_OIDC_ROLE_ARN}
          aws_oidc_authentication
        fi

        debug "Checking for assume role arn match"
        assume_role_var="AWS_CODEARTIFACT_${x}_ASSUME_ROLE_ARN"
        # Check if there is a matching AWS_CODEARTIFACT_*_ASSUME_ROLE_ARN variable
        if [[ -n "${!assume_role_var}" ]]; then
          debug "Calling aws_assume_role"
          AWS_ASSUME_ROLE_ARN=${!assume_role_var}
          aws_assume_role
        elif [[ -n "${AWS_CODEARTIFACT_ASSUME_ROLE_ARN}" ]]; then
          debug "Calling aws_assume_role"
          AWS_ASSUME_ROLE_ARN=${AWS_CODEARTIFACT_ASSUME_ROLE_ARN}
          aws_assume_role
        fi

        debug "Calling if_codeartifact_dotnet_login for ARN: ${value}"
        if_codeartifact_dotnet_login
        debug "Calling if_codeartifact_maven_login for ARN: ${value}"
        if_codeartifact_maven_login
        debug "Calling if_codeartifact_npm_login for ARN: ${value}"
        if_codeartifact_npm_login
      fi
    done

    if [[ "${CODEARTIFACT_ARN_COUNT}" -eq 0 ]]; then
      debug "CODEARTIFACT_*_REPOSITORY_ARN(s) not found."
    fi
  )
}

function ecr_login() {
  (
    debug "Calling ecr_login()"
    if [[ -n "${AWS_ECR_OIDC_ROLE_ARN+x}" ]]; then
      debug "Detected AWS_ECR_OIDC_ROLE_ARN: ${AWS_ECR_OIDC_ROLE_ARN}"
      AWS_OIDC_ROLE_ARN=${AWS_ECR_OIDC_ROLE_ARN}
      aws_oidc_authentication
    fi
    if [[ -n "${AWS_ECR_ASSUME_ROLE_ARN+x}" ]]; then
      debug "Detected AWS_ECR_ASSUME_ROLE_ARN: ${AWS_ECR_ASSUME_ROLE_ARN}"
      AWS_ASSUME_ROLE_ARN=${AWS_ECR_ASSUME_ROLE_ARN}
      aws_assume_role
    fi
    debug "Detected AWS_ECR_ACCOUNT_ID: ${AWS_ECR_ACCOUNT_ID}"
    debug "Detected AWS_ECR_REGION: ${AWS_ECR_REGION}"
    aws ecr get-login-password --region "${AWS_ECR_REGION}" | docker login --username AWS --password-stdin "${AWS_ECR_ACCOUNT_ID}.dkr.ecr.${AWS_ECR_REGION}.amazonaws.com"
  )
}

function if_ecr_login() {
  debug "Calling if_ecr_login()"
  if [[ -n "${AWS_ECR_REGION+x}" ]] && [[ -n "${AWS_ECR_ACCOUNT_ID+x}" ]]; then
    ecr_login
  fi
}

function initialize() {
  aws_pager_off
  aws_authentication
  if_aws_assume_role
  if_aws_account_id
  if_git_crypt_unlock
  if_local_path
  if_ecr_login
  if_codeartifact
  if_codeartifact_legacy
}
