#!/usr/bin/python
import requests
import json
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.poolmanager import PoolManager
import ssl
import sys
import getopt

CONTACTS_CC_SCHEMA = {
	'name': 'contacts',
	'schema': {
		'user_deviceToken': 'string',
		'user_username': 'string',
		'user_usersId': 'string'
	},
	'phi': False
}

CONVERSATIONS_CC_SCHEMA = {
	'name': 'conversations',
	'schema': {
		'sender': 'string',
		'recipient': 'string',
		'sender_id': 'string',
		'recipient_id': 'string',
		'sender_deviceToken': 'string',
		'recipient_deviceToken': 'string'
	},
	'phi': True
}

MESSAGES_CC_SCHEMA = {
	'name': 'messages',
	'schema': {
		'conversationsId': 'string',
		'msgContent': 'string',
		'toPhone': 'string',
		'fromPhone': 'string',
		'timestamp': 'string',
		'isPhi': 'boolean',
		'fileId': 'string'
	},
	'phi': True
}

class MyAdapter(HTTPAdapter):
    def init_poolmanager(self, connections, maxsize, block=False):
        self.poolmanager = PoolManager(num_pools=connections,
                                       maxsize=maxsize,
                                       block=block,
                                       ssl_version=ssl.PROTOCOL_TLSv1)

def usage():
	print('''
HipaaGram Setup Script Usage

python HipaaGramSetup.py --username myusername@email.com --password myP@ssw0rd --appId 185bff27-a5b6-410e-bee3-71db20f51617 --apiKey 5b7a544d-261e-48f6-b254-792d6efa3722
''')

username = None
password = None
app_id = None
api_key = None

try:
	opts, args = getopt.getopt(sys.argv[1:], "u:p:a:k:", ["username=", "password=", "appId=", "apiKey="])
except getopt.GetoptError:
	usage()
	sys.exit(2)

for opt, arg in opts:
	if opt in ('-u', '--username'):
		username = arg
	elif opt in ('-p', '--password'):
		password = arg
	elif opt in ('-a', '--appId'):
		app_id = arg
	elif opt in ('-k', '--apiKey'):
		api_key = arg

if not username or not password or not app_id or not api_key:
	print("\nusername, password, app_id, and api_key are required parameters\n")
	usage()
	sys.exit(2)

# Script to setup an app, and custom classes for HipaaGram

base_url = "https://api.catalyze.io"

headers = {'X-Api-Key': api_key, 'Content-Type': 'application/json', 'Accept': 'application/json'}

s = requests.Session()
s.mount('https://', MyAdapter())

# login to the new app
route = '{}/v2/auth/signin'.format(base_url)
data = {'username': username, 'password': password}
r = s.post(route, data=json.dumps(data), headers=headers)
resp = r.json()
r.raise_for_status()

headers['Authorization'] = 'Bearer {}'.format(resp['sessionToken'])

# create the contacts custom class
route = '{}/v2/classes'.format(base_url)
r = s.post(route, data=json.dumps(CONTACTS_CC_SCHEMA), headers=headers)
resp = r.json()
r.raise_for_status()

# create the conversations custom class
route = '{}/v2/classes'.format(base_url)
r = s.post(route, data=json.dumps(CONVERSATIONS_CC_SCHEMA), headers=headers)
resp = r.json()
r.raise_for_status()

# create the messages custom class
route = '{}/v2/classes'.format(base_url)
r = s.post(route, data=json.dumps(MESSAGES_CC_SCHEMA), headers=headers)
resp = r.json()
r.raise_for_status()

# create the CreateRetrieve default group
route = '{}/v2/groups'.format(base_url)
data = {'name':'CreateRetrieve','default':True}
r = s.post(route, data=json.dumps(data), headers=headers)
resp = r.json()
r.raise_for_status()

create_retrieve_groups_id = resp['groupsId']

# create the Create default group
route = '{}/v2/groups'.format(base_url)
data = {'name':'Create','default':True}
r = s.post(route, data=json.dumps(data), headers=headers)
resp = r.json()
r.raise_for_status()

create_groups_id = resp['groupsId']

# set create permissions for contacts class for the app
route = '{}/v2/acl/custom/contacts/{}'.format(base_url, create_retrieve_groups_id)
data = ['create', 'retrieve']
r = s.post(route, data=json.dumps(data), headers=headers)
resp = r.json()
r.raise_for_status()

# set create permissions for conversations class for the app
route = '{}/v2/acl/custom/conversations/{}'.format(base_url, create_groups_id)
data = ['create']
r = s.post(route, data=json.dumps(data), headers=headers)
resp = r.json()
r.raise_for_status()

# set create permissions for messages class for the app
route = '{}/v2/acl/custom/messages/{}'.format(base_url, create_groups_id)
data = ['create']
r = s.post(route, data=json.dumps(data), headers=headers)
resp = r.json()
r.raise_for_status()

print('\n\nSuccess! Your HipaaGram application is ready to use!')
