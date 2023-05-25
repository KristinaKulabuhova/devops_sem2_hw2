from flask import Flask
import os
import requests

app = Flask(__name__)

@app.route('/')
def route():
	return requests.get('https://reqres.in/api/users').text

if __name__ == '__main__':
	app.run(host='0.0.0.0', port=8080)
