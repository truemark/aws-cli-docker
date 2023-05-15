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

# This function requires the following variables be set
#  AWS_WEB_IDENTITY_TOKEN or AWS_WEB_IDENTITY_TOKEN_FILE
#  AWS_ROLE_ARN or AWS_OIDC_ROLE_ARN
# If not already set, this function will set AWS_WEB_IDENTITY_TOKEN_FILE and export
# the AWS_WEB_IDENTITY_TOKEN_FILE and AWS_ROLE_ARN variables.
function aws_oidc_authentication() {
  debug "Calling aws_oidc_authentication()"

  # BitBucket has standardized on AWS_OIDC_ROLE_ARN in most their pipes
  [[ -n "${AWS_OIDC_ROLE_ARN+x}" ]] && AWS_ROLE_ARN="${AWS_OIDC_ROLE_ARN}"
  AWS_ROLE_ARN=${AWS_ROLE_ARN:?'is a required variable or AWS_OIDC_ROLE_ARN must be set'}
  debug "AWS_ROLE_ARN=${AWS_ROLE_ARN}"

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

# This function requires the following variables be set
#  AWS_ASSUME_ROLE_ARN
#  AWS_ROLE_SESSION_NAME
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
  aws_sts_result=$(aws sts assume-role --role-arn "${assume_role_arn_expanded}" --role-session-name "${AWS_ROLE_SESSION_NAME}")
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
  if [[ -n "${AWS_WEB_IDENTITY_TOKEN+x}${AWS_WEB_IDENTITY_TOKEN_FILE+x}${AWS_ROLE_ARN+x}" ]]; then
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

function codeartifact_npm_login() {
  # parse the ARN to get the region, domain, and repository
  CODEARTIFACT_REGION=$(echo "${CODEARTIFACT_REPOSITORY_ARN}" | sed 's/arn:aws:codeartifact://' | sed 's/:.*//')
  CODEARTIFACT_DOMAIN=$(echo "${CODEARTIFACT_REPOSITORY_ARN}" | sed 's/arn:aws:codeartifact:.*:repository\///' | sed 's/\/.*//')
  CODEARTIFACT_REPO=$(echo "${CODEARTIFACT_REPOSITORY_ARN}" | sed 's/arn:aws:codeartifact:.*:repository\/.*\///')
  # TODO Using a sub-shell do the following: (sub-shell is needed to prevent leaking of variables)
  # TODO  sts assume into CODEARTIFACT_OIDC_ROLE_ARN or CODEARTIFACT_OIDC_ROLE_ARN if not set
  # TODO aws codeartifact login --namespace ${CODEARTIFACT_NPM_NAMESPACE} --tool npm --repository youngliving --domain ${CODEARTIFACT_DOMAIN} --region ${CODEARTIFACT_REGION}
  # TODO You need to modify this method to loop over CODEARTIFACT_*_OIDC_ROLE_ARN, CODEARTIFACT_*_NPM_NAMESPACE, CODEARTIFACT_*_REPOSITORY_ARN and do the necessary things
}

function if_codeartifact_npm_login() {
  # TODO execute codeartifact_npm_login if CODEARTIFACT_REPOSITORY_ARN CODEARTIFACT_NPM_NAMESPACE are set and npm is installed
}

function codeartifact_dotnet_login() {
  # TODO Implement me
}

function if_codeartifact_dotnet_login() {
  # TODO execute codeartifact_dotnet_login if CODEARTIFACT_REPOSITORY_ARN variables and dotnet are installed
}

function codeartifact_maven_login() {
  # TODO Implement me
}

function if_codeartifact_maven_login() {
  # TODO Implement me
}

# TODO Get rid of me
# Get authorization token for aws codeartifact
function codeartifact_login() {
  # aws codeartifact login --namespace yl --tool npm --repository youngliving --domain yl --profile yl-devops --region us-west-2
  # aws codeartifact login --tool dotnet --repository youngliving --domain yl --domain-owner 534914120180
  # aws codeartifact list-package-versions --domain my_domain --domain-owner 111122223333 --repository my_repo --format maven --namespace com.company.framework --package my-package-name
  debug "Calling codeartifact_login()"
  mkdir codeartifact
  echo "export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token --domain ${AWS_CODEARTIFACT_DOMAIN} \
    --domain-owner ${AWS_ACCOUNT_ID} \
    --region ${AWS_DEFAULT_REGION} \
    --query authorizationToken --output text)" > codeartifact/token

  debug "CODEARTIFACT_AUTH_TOKEN saved to file: codeartifact/token"
}

# TODO Get rid of me
# Calls codeartifact_login if AWS_CODEARTIFACT_{DOMAIN,REPO} are set
function if_codeartifact_login() {
  debug "Calling if_codeartifact_login()"
  if [[ -n "${AWS_CODEARTIFACT_REPO+x}" ]] && [[ -n "${AWS_CODEARTIFACT_DOMAIN+x}" ]] ; then
    debug "Detected account: ${AWS_ACCOUNT_ID}"
    debug "Detected region: ${AWS_DEFAULT_REGION}"
    debug "Detected domain: ${AWS_CODEARTIFACT_DOMAIN}"
    debug "Detected repo: ${AWS_CODEARTIFACT_REPO}"

    codeartifact_login
  else
    debug "Codeartifact variables not detected"
  fi
}

function initialize() {
  aws_pager_off
  aws_authentication
  if_aws_assume_role
  if_aws_account_id
  if_git_crypt_unlock
  if_local_path
  if_codeartifact_login
}
