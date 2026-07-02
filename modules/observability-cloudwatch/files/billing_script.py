import boto3
import os
import json
import urllib.request
from datetime import datetime, timedelta, date

def lambda_handler(event, context):
    client = boto3.client('ce') 
    sm_client = boto3.client('secretsmanager')
    
    secret_arn = os.environ['SECRET_ARN']
    secret_response = sm_client.get_secret_value(SecretId=secret_arn)
    slack_url = secret_response['SecretString']

    current_env = os.environ.get('ENV', 'dev')
    
    today = date.today()
    start_of_month = today.replace(day=1).strftime('%Y-%m-%d')
    end_of_month = (today + timedelta(days=1)).strftime('%Y-%m-%d')
    
    response = client.get_cost_and_usage(
        TimePeriod={'Start': start_of_month, 'End': end_of_month},
        Granularity='MONTHLY',
        Metrics=['UnblendedCost'],
        Filter={'Tags': {'Key': 'Team', 'Values': ['team1']}}
    )
    
    try:
        amount = float(response['ResultsByTime'][0]['Total']['UnblendedCost']['Amount'])
    except (IndexError, KeyError):
        amount = 0.0
        
    message = {
        "text": f"💳 *1팀 프로젝트 {current_env.upper()} 환경 실시간 비용 리포트* 💳\n"
                f"• *조회 기간*: {start_of_month} ~ {today.strftime('%Y-%m-%d')}\n"
                f"• *현재까지 누적 비용*: `${amount:.2f} USD` 💸\n"
                f"⚠️ _매일 아침 9시에 정기적으로 정산 요금이 배달됩니다._"
    }
    
    req = urllib.request.Request(
        slack_url, 
        data=json.dumps(message).encode('utf-8'),
        headers={'Content-Type': 'application/json'}
    )
    
    with urllib.request.urlopen(req) as res:
        res.read()
        
    return {"statusCode": 200, "body": "Slack billing alert sent successfully!"}