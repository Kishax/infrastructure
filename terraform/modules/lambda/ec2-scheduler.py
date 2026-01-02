"""
EC2 Scheduler Lambda Function
Starts or stops EC2 instances based on the action parameter.
"""

import json
import boto3
import os
from typing import List, Dict, Any

ec2 = boto3.client('ec2')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for EC2 start/stop operations.

    Expected event format:
    {
        "action": "start" or "stop",
        "instance_ids": ["i-xxxxx", "i-yyyyy", ...]
    }
    """

    try:
        action = event.get('action')
        instance_ids = event.get('instance_ids', [])

        if not action or action not in ['start', 'stop']:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Invalid action. Must be "start" or "stop".'
                })
            }

        if not instance_ids:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'No instance IDs provided.'
                })
            }

        print(f"Action: {action}")
        print(f"Instance IDs: {instance_ids}")

        # Execute action
        if action == 'start':
            response = ec2.start_instances(InstanceIds=instance_ids)
            print(f"Start response: {response}")

            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Successfully started instances: {instance_ids}',
                    'starting_instances': response['StartingInstances']
                })
            }

        elif action == 'stop':
            response = ec2.stop_instances(InstanceIds=instance_ids)
            print(f"Stop response: {response}")

            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Successfully stopped instances: {instance_ids}',
                    'stopping_instances': response['StoppingInstances']
                })
            }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
