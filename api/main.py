from fastapi import FastAPI
import requests

app = FastAPI()

@app.get("/prayer-times")
def get_prayer_times(city: str = "Cairo", country: str = "Egypt", method: int = 5):
    url = f"https://api.aladhan.com/v1/timingsByCity?city={city}&country={country}&method={method}"
    response = requests.get(url)
    data = response.json()
    prayer_times = data["data"]["timings"]
    formatted_times = {}
    
    for prayer, time in prayer_times.items():
        hour, minute = map(int, time.split(":"))
        period = "AM" if hour < 12 else "PM"
        hour = hour if 1 <= hour <= 12 else (12 if hour % 12 == 0 else hour % 12)
        formatted_times[prayer] = f"{hour}:{minute:02d} {period}"
    
    return {"prayer_times": formatted_times}