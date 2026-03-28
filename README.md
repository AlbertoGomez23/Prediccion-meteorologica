# Predicción Meteorológica

Este proyecto tiene como objetivo desarrollar un modelo de Machine Learning capaz de predecir variables meteorológicas (temperatura, viento y precipitación) comparando datos reales y predicciones de diferentes fuentes.

## Flujo de trabajo

### Captura de datos
Un script de MATLAB automatizado recolecta cada 12 horas:
- Datos reales de AEMET
- Predicciones de Open-Meteo

### Procesamiento
- Limpieza de datos duplicados  
- Estructuración de las series temporales  
- Construcción de un histórico acumulado  

### Entrenamiento
- Uso de modelos de regresión o redes neuronales  
- Ajuste de las predicciones  
- Mejora de la precisión final del modelo  
