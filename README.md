# Weather forecast correction with machine learning

This project builds a predictive model that improves the 48-hour weather
forecasts (temperature, wind speed and precipitation) for San Fernando (Cádiz,
Spain) by combining real observations and forecasts from different sources with
machine learning.

## Workflow

### 1. Data collection
Automated MATLAB scripts collect data through public APIs:
- Real weather observations from AEMET (the Spanish State Meteorological Agency).
- Weather forecasts from Open-Meteo.
- Local forecasts from AEMET.

### 2. Processing
- Time zone synchronization (UTC to local time).
- Alignment of forecast hours across the different APIs.
- Cleaning of missing values (NaNs) and organization of the time series into a
  cumulative history file (`historico.txt`).

### 3. Training (linear regression)
- The Moore-Penrose pseudoinverse is used to compute the optimal weight of each
  source (AEMET and Open-Meteo).
- The model is trained on the hours where both APIs overlap.
- The coefficients are saved to a `.mat` file for later use.

---

## Project files

* `acumula_datos_diario.m`: connects to the APIs, downloads the current weather
  and the forecasts, and appends a new block to `historico.txt`.
* `entrenamiento.m`: reads the history, matches the real observations with what
  was forecast in the past, and trains the model. It generates `modelo.mat`.
* `prediccion.m`: uses the trained model to generate `miprediccion.txt` with the
  forecast for the next 48 hours.
* `sacar_graficas_presentacion.m`: backtesting. It compares the past forecasts
  of Open-Meteo, AEMET and the trained model against the real observations, with
  the global RMSE and how the error grows in 12-hour blocks.
* `historico.txt`: plain-text database that acts as the memory of the system.

The code (identifiers and comments) is written in Spanish.

---

## How to use it

The scripts must be run in MATLAB in this order:

### Step 1: Collect data
First, get a valid AEMET API key and save it in a text file called
`api_aemet.txt` in the same folder as the scripts (the key is not included in
the repository).

Run the collection function several times over several days to build a large
enough dataset (ideally, schedule it with the operating system's task
scheduler).

```matlab
acumula_datos_diario()
```

This creates or updates `historico.txt`.

### Step 2: Train the model
Once the history contains enough data (several days of captures), train the
model so it learns from the past errors of the APIs.

```matlab
entrenamiento()
```

This reads the history and generates `modelo.mat`, which contains the trained
coefficients for temperature, wind and precipitation.

### Step 3: Make a forecast
With the trained model, forecast the next 48 hours.

```matlab
prediccion()
```

The script downloads the current weather, applies the coefficients in
`modelo.mat` and writes `miprediccion.txt` with the forecast.
