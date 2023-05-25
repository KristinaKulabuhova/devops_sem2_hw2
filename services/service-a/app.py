from flask import Flask
import os
import requests

app = Flask(__name__)

@app.route('/')
def route():
    return requests.get(os.environ['SERVICEB_URL']).text

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9090)
