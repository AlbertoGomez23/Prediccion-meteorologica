% -------------------------------------------------------------------------
% FUNCION: entrenamiento
%
% DESCRIPCION:
% Esta función se encarga del proceso de entrenamiento de los modelos 
% predictivos (Temperatura, Viento y Precipitación). Genera un archivo 
% llamado 'Modelo.mat' que contiene los modelos entrenados y que será 
% utilizado posteriormente por la función prediccion.m.
% 
% JUSTIFICACIÓN DEL DISEÑO (36h vs 48h):
% Tras analizar la API de AEMET, se comprobó que el horizonte de predicción
% horaria concurrente con Open-Meteo alcanza un máximo fiable de ~36-40h. 
% Por ello, el modelo de Machine Learning se entrena para predecir las 
% primeras 36 horas con alta precisión (fusionando AEMET y OM). Las horas 
% 37 a 48 del fichero final se rellenarán utilizando la salida directa de 
% Open-Meteo.
%
% FUNCIONAMIENTO:
% 1. Obtiene los datos recopilados en 'historico.txt'.
% 2. Filtra el histórico para extraer ÚNICAMENTE las predicciones (X) 
%    generadas en las capturas de las 11:00 AM. Esto garantiza consistencia 
%    en el horizonte temporal (aprox. 36 horas vista, cubriendo todo el 
%    día actual y el siguiente completo).
% 3. Busca el valor REAL (Y / Ground Truth) correspondiente a cada una de 
%    esas horas predichas en el documento.
% 4. Alinea los datos (Predicción OM, Predicción AEMET, Valor Real) 
%    descartando las filas donde falte alguna fuente (NaNs).
% 5. Entrena los modelos para cada variable y los guarda en 'Modelo.mat'.
% -------------------------------------------------------------------------

function entrenamiento()
    disp('Iniciando el proceso de entrenamiento...');

    try
        % 1. LECTURA DEL ARCHIVO
        % Usamos readlines para leer todo el archivo de golpe
        if ~isfile('historico.txt')
            error('No se encuentra el archivo historico.txt en esta carpeta.');
        end
        lineas = readlines('historico.txt');
    catch e
        fprintf('\n[ERROR EN ENTRENAMIENTO]: %s\n', e.message);
    end
end