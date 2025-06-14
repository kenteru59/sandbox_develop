import subprocess
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    cmd = ['./aws-nuke', '-c', 'nuke-config.yaml', '--force']
    try:
        logger.info("Executing aws-nuke: %s", cmd)
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        logger.info("stdout:\n%s", result.stdout)
        logger.info("stderr:\n%s", result.stderr)
        return {"statusCode": 200, "body": "aws-nuke completed successfully"}
    except subprocess.CalledProcessError as e:
        logger.error("aws-nuke failed:\n%s", e.stderr)
        return {"statusCode": 200, "body": "aws-nuke executed with errors"}
