import json

log_file = r"C:\Users\omarr\.gemini\antigravity\brain\7ca763f4-fee9-423c-9fa8-c92e95634f6a\.system_generated\steps\442\output.txt"
with open(log_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

logs = data['result']['result']
for log in logs:
    event = json.loads(log['event_message'])
    if event.get('provider') == 'google' or 'google' in log['event_message'].lower():
        print(json.dumps(log, indent=2))
