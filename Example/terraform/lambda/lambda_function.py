import json

def lambda_handler(event, context):
    # Get S3 object details
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    # Extract number from filename (remove extension)
    number_str = key.split('.')[0]
    
    try:
        n = int(number_str)
    except ValueError:
        print(f"Filename {key} is not a valid number.")
        return {
            'statusCode': 400,
            'body': f"Filename {key} is not a valid number."
        }

    # Loop and print "Hello World"
    for i in range(n + 1):
        print(f"{i}: Hello World")

    return {
        'statusCode': 200,
        'body': json.dumps(f"Looped from 0 to {n}")
    }
