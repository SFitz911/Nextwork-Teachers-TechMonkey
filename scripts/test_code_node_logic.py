#!/usr/bin/env python3
# Test the code node logic to see if it works
# This simulates what the n8n code node should do

# Simulate webhook input
webhook_input = {
    "json": {
        "body": {
            "message": "Hello, test",
            "timestamp": 1234567890
        }
    }
}

# The code from the workflow
teachers = ['teacher_a', 'teacher_b', 'teacher_c', 'teacher_d', 'teacher_e']
lastTeacher = webhook_input['json'].get('lastTeacher', 'teacher_e')
currentIndex = teachers.index(lastTeacher) if lastTeacher in teachers else -1
nextIndex = (currentIndex + 1) % len(teachers)
selectedTeacher = teachers[nextIndex]

# Extract message from webhook body
message = ''
if webhook_input['json'].get('body') and isinstance(webhook_input['json']['body'], dict):
    message = webhook_input['json']['body'].get('message', '')
elif isinstance(webhook_input['json'].get('body'), str):
    try:
        import json
        bodyObj = json.loads(webhook_input['json']['body'])
        message = bodyObj.get('message', '')
    except:
        message = webhook_input['json'].get('body', '')
else:
    message = webhook_input['json'].get('message', webhook_input['json'].get('body', {}).get('message', ''))

result = {
    "json": {
        "selectedTeacher": selectedTeacher,
        "lastTeacher": selectedTeacher,
        "message": message
    }
}

print("Code node test result:")
print(f"  Selected Teacher: {result['json']['selectedTeacher']}")
print(f"  Message: {result['json']['message']}")
print(f"  Last Teacher: {result['json']['lastTeacher']}")
