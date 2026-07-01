import os
import json
import urllib.request
from datetime import datetime, timedelta, date

def lambda_handler(event, context):
    client = boto3.client('ce') # Cost Explorer API 로드
    
    # 1. 이번 달 1일부터 오늘까지의 날짜 계산
    today = date.today()
    start_of_month = today.replace(day=1).strftime('%Y-%m-%d')
    end_of_month = (today + timedelta(days=1)).strftime('%Y-%m-%d') 
    
    # 2. AWS에 이번 달 누적 비용 요청 (우리 팀 태그 필터링 포함)
    response = client.get_cost_and_usage(
        TimePeriod={
            'Start': start_of_month,
            'End': end_of_month
        },
        Granularity='MONTHLY',
        Metrics=['UnblendedCost'],
        Filter={
            'Tags': {
                'Key': 'Team',
                'Values': ['team1'] 
            }
        }
    )
    
    # 3. 비용 파싱 (달러 추출)
    try:
        amount = float(response['ResultsByTime'][0]['Total']['UnblendedCost']['Amount'])
    except (IndexError, KeyError):
        amount = 0.0
        
    # 4. 슬랙으로 보낼 메시지 본문 구성
    slack_url = os.environ['SLACK_WEBHOOK_URL']
    message = {
        "text": f"💳 *1팀 프로젝트 dev 환경 실시간 비용 리포트* 💳\n"
                f"• *조회 기간*: {start_of_month} ~ {today.strftime('%Y-%m-%d')}\n"
                f"• *현재까지 누적 비용*: `${amount:.2f} USD` 💸\n"
                f"⚠️ _매일 아침 9시에 정기적으로 정산 요금이 배달됩니다._"
    }
    
    # 5. 슬랙으로 메시지 전송
    req = urllib.request.Request(
        slack_url, 
        data=json.dumps(message).encode('utf-8'),
        headers={'Content-Type': 'application/json'}
    )
    
    with urllib.request.urlopen(req) as res:
        res.read()
        
    return {"statusCode": 200, "body": "Slack billing alert sent successfully!"}