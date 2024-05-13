#!/usr/bin/env python3
import argparse
import requests
import sys
from dateutil import parser as date_parser
from datetime import datetime

def pull_request_was_merged(pull_request, since_date=None):
    response = requests.get(pull_request)
    if response.status_code == 200:
        data = response.json()
        if data.get('status') == 'Merged':
            if since_date:
                closed_date = datetime.fromtimestamp(int(data.get('closed_at')))
                if closed_date >= since_date:
                    return True
                else:
                    return False
            return True
    return False

def main():
    argument_parser = argparse.ArgumentParser(description='Check if a PR has been merged.')
    argument_parser.add_argument('pull_request', type=str, help='The URL of the pull request')
    argument_parser.add_argument('--since', type=str, help='Date to check from, in YYYY-MM-DD format')

    arguments = argument_parser.parse_args()

    since_date = date_parser.parse(arguments.since) if arguments.since else None

    if pull_request_was_merged(arguments.pull_request, since_date):
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()

