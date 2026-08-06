from flask import Flask

app = Flask(__name__)

@app.get("/")
def hello():
    return {
        "application": "INSA VCC",
        "status": "running"
    }

app.run(host="0.0.0.0", port=5000)
