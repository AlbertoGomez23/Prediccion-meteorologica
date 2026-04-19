# Predicción Meteorológica - Machine Learning

Este proyecto tiene como objetivo desarrollar un modelo predictivo capaz de mejorar las previsiones meteorológicas (temperatura, velocidad del viento y precipitación) a 48 horas vista en San Fernando (Cádiz), combinando datos reales y predicciones de diferentes fuentes mediante Machine Learning.

## Flujo de Trabajo

### 1. Captura de datos
Se utilizan scripts en MATLAB automatizados para recolectar datos a través de APIs:
- Datos meteorológicos reales de AEMET.
- Predicciones meteorológicas de Open-Meteo.
- Predicciones específicas de AEMET.

### 2. Procesamiento
- Sincronización de zonas horarias (UTC a Local).
- Alineación de horas de predicción entre distintas APIs.
- Limpieza de datos nulos (NaNs) y estructuración de series temporales en un histórico acumulado (`historico.txt`).

### 3. Entrenamiento (Regresión Lineal)
- Uso de la pseudoinversa de Moore-Penrose para calcular los pesos óptimos de cada fuente (AEMET y Open-Meteo).
- Entrenamiento del modelo usando las horas donde coinciden ambas APIs.
- Guardado de los coeficientes en un archivo `.mat` para su uso futuro.

---

## Archivos del Proyecto

* `acumula_datos_diario.m`: Script encargado de conectarse a las APIs, descargar el tiempo actual y las previsiones, y añadir un bloque de texto al final de `historico.txt`.
* `entrenamiento.m`: Lee el histórico, cruza los datos reales con lo que se predijo en el pasado, y entrena el modelo matemático. Genera el archivo `Modelo.mat`.
* `prediccion.m`: Utiliza el modelo entrenado para generar el archivo `miprediccion.txt` con el pronóstico de las próximas 48 horas.
* `historico.txt`: Base de datos en texto plano que actúa como memoria del sistema.

---

## Cómo usar el código

Para que el sistema funcione correctamente, se debe seguir este orden estricto de ejecución en MATLAB:

### Paso 1: Acumular datos (Recopilación)
Antes de ejecutar nada, asegúrate de disponer de una API key válida de AEMET y guárdala en un archivo de texto llamado `api_aemet.txt` en el mismo directorio que los scripts.

Ejecuta la función de recopilación varias veces durante varios días para generar una base de datos lo suficientemente grande. (Idealmente, esto se automatiza con el programador de tareas del Sistema Operativo).

```matlab
acumula_datos_diario()
```

Esto creará o actualizará el archivo `historico.txt`.

### Paso 2: Entrenar el Modelo
Una vez tengas suficientes datos en tu histórico (varios días de capturas), debes entrenar el modelo para que aprenda de los errores pasados de las APIs.

```matlab
entrenamiento()
```

Esto leerá el histórico y generará un archivo llamado `Modelo.mat` que contiene los coeficientes entrenados para la Temperatura, Viento y Precipitación.

### Paso 3: Realizar una Predicción
Con el modelo ya entrenado, puedes predecir las próximas 48 horas.

```matlab
prediccion()
```

El script se descargará el tiempo actual, aplicará los coeficientes de `Modelo.mat` y generará un fichero llamado `miprediccion.txt` con el formato estándar de salida requerido.