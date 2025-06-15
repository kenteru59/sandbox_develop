import boto3

client = boto3.client('organizations')

# 異なるAWSアカウント/ロールのクレデンシャル取得を実行する
def sts_assume_role(account_id):
    role_arn = "arn:aws:iam::%s:role/AWSControlTowerExecution" % account_id
    session_name = "create-alias"

    client = boto3.client('sts')

    # AssumeRoleで一時クレデンシャルを取得
    response = client.assume_role(
        RoleArn=role_arn,
        RoleSessionName=session_name
    )
    
    iam_client = boto3.client(
        'iam',
        aws_access_key_id=response['Credentials']['AccessKeyId'],
        aws_secret_access_key=response['Credentials']['SecretAccessKey'],
        aws_session_token=response['Credentials']['SessionToken'],
    )


    return iam_client
 
# アカウントのエイリアスを取得する   
def get_account_aliases(account_id):
    iam = sts_assume_role(account_id)

    res = []
    # List account aliases through the pagination interface
    paginator = iam.get_paginator('list_account_aliases')
    for response in paginator.paginate():
        res = response["AccountAliases"]
    return res
    

# エイリアスが存在するアカウントIDのリストを取得する
def get_account_ids():
    # 全組織のアカウント情報を取得する
    pagenator = client.get_paginator('list_accounts')
    response_iterator = pagenator.paginate()
    
    row_value = []
    for response in response_iterator:
        for acct in response['Accounts']:
            # 取得するアカウント情報のリスト化
            row_value.append(acct['Id'])
    
    res = ""
    # アカウントIDのリストを空白区切りの文字列にする
    for index,value in enumerate(row_value):
        # 先頭の要素はスキップする
        if index == 0:
            res = value
            continue
        res = res + " " + value

    return res

def lambda_handler(event, context):
    account_list = get_account_ids()
    return {"accounts": account_list,"nuke_dry_run": "false"}  