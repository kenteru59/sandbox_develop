import subprocess
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    sts = boto3.client('sts')
    identity = sts.get_caller_identity()
    logger.info("Assumed identity: %s", identity)

    cmd = ['./aws-nuke', 'run', '--config', 'nuke-config.yaml', '--no-dry-run', '--no-prompt']

    try:
        logger.info("Executing aws-nuke: %s", cmd)
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        logger.info("aws-nuke stdout:\n%s", result.stdout)
        logger.info("aws-nuke stderr:\n%s", result.stderr)
        logger.info("aws-nuke completed successfully as identity: %s", identity)
        return {
            "statusCode": 200,
            "body": "aws-nuke completed successfully"
        }
    except subprocess.CalledProcessError as e:
        logger.error("aws-nuke failed (stderr):\n%s", e.stderr)
        logger.error("aws-nuke failed (stdout):\n%s", e.stdout)
        return {
            "statusCode": 500,
            "body": f"aws-nuke failed:\nstderr:\n{e.stderr}\nstdout:\n{e.stdout}"
        }
