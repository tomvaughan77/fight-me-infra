# Fight.Me Infrastructure

Yep

## aws-vault

Account ID: `470096912115`
User: `tom`

1. Install aws-vault (using homebrew, works for both mac and wsl linux)

    ```bash
        brew install aws-vault
    ```

2. Add IAM credentials. This is where you'll need to enter your access key and secret (access) key. Replace `my_iam_name` with your account name.

    ```bash
        aws-vault add my_iam_name
    ```

3. Initialise Terraform backend

    ```bash
        aws-vault exec my_iam_name -- terraform init
    ```
