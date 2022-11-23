# AWS CLI Docker Image

This project produces a docker image with minimal layers containing the AWS CLI
with added functionality to support automatic role switching with STS, etc.

This repository produces both linyx/amd64 and linux/arm64 docker images on a
variety of distributions.

# How do I use this docker image?

Authentication using an IAM user
```bash
docker run -it --rm \
  -e AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY" \
  truemark/aws-cli:latest
```

Alternative example using an IAM user 
```bash
docker run -it --rm truemark/aws-cli:latest
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
initialize
```

Example using an IAM user and switching roles
```bash
docker run -it --rm \
  -e AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY" \
  -e AWS_ASSUME_ROLE_ARN="YOUR_ROLE_ARN" \
  -e AWS_ROLE_SESSION_NAME="YOUR_SESSION_NAME" \
  truemark/aws-cli:latest
```

Example using OIDC authentication and switching roles
```bash
docker run -it --rm \
  -e AWS_OIDC_ROLE_ARN="YOUR_ACCESS_KEY_ID" \
  -e AWS_WEB_IDENTITY_TOKEN="YOUR_OIDC_TOKEN" \
  -e AWS_ASSUME_ROLE_ARN="YOUR_ROLE_ARN" \
  -e AWS_ROLE_SESSION_NAME="YOUR_SESSION_NAME" \
  truemark/aws-cli:latest
```

# What are all the environment variables supported by this image?

| Environment Variable        | Description                                                                             |
|:----------------------------|:----------------------------------------------------------------------------------------|
 | AWS_ACCESS_KEY_ID           | Optional access key if using default AWS authentication.                                |
 | AWS_SECRET_ACCESS_KEY       | Optional secret access key if using default AWS authentication.                         |
| AWS_SESSION_TOKEN           | Optional session token used with temporary credentials.                                 |
| AWS_WEB_IDENTITY_TOKEN      | Optional OIDC token if using AWS OIDC authentication.                                   |
 | AWS_WEB_IDENTITY_TOKEN_FILE | Optional token file if using AWS OIDC authentication.                                   |
 | AWS_ROLE_ARN                | Optional role to assume if using AWS OIDC authentication.                               |
 | AWS_OIDC_ROLE_ARN           | Alternative variable to AWS_ROLE_ARN.                                                   |
 | AWS_ROLE_SESSION_NAME       | Optional session name used in audit logs used when assuming a role.                     |
 | AWS_ASSUME_ROLE_ARN         | Optional role to assume.                                                                |
 | AWS_EXCLUDE_ACCOUNT_IDS     | Account IDs to exclude when using aws_organization_account_ids function.                |
 | AWS_EXCLUDE_OU_IDS          | AWS Organizational units to exclude when using aws_organization_account_ids.            |
 | GIT_CRYPT_KEY               | Optional base64 encoded git-crypt key used to unlock the git repository with git-crypt. |
 | GIT_CRYPT_KEY_FILE          | Optional git-crypt key file used to unlock the git repository with git-crypt.           |           
 | LOCAL_PATH                  | Optional value to change working directories.                                           |

## Maintainers

 - [erikrj](https://github.com/erikrj)

## License

The contents of this repository are released under the BSD 3-Clause license. See the
license [here](https://github.com/truemark/aws-cli-dockegitr/blob/main/LICENSE.txt).
