% -------------------------------------------------------------------------
% FUNCION: entrenamiento
%
% DESCRIPCION:
% Esta función se encarga del proceso de entrenamiento de los modelos 
% predictivos (Temperatura, Viento y Precipitación). Genera un archivo 
% llamado 'Modelo.mat' que contiene los modelos entrenados y que será 
% utilizado posteriormente por la función prediccion.m.
% 
% FUNCIONAMIENTO:
% 1. Obtiene los datos recopilados en 'historico.txt'.
% 2. Filtra el histórico para extraer ÚNICAMENTE las predicciones (X) 
%    generadas en las capturas a la mañana (11 AM y 10 AM). 
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

        % 2. DICCIONARIOS PARA LAS 3 VARIABLES
        % KeyType = 'char' → las claves son strings (fechas) 
        % ValueType = 'any' → puedes guardar cualquier cosa (en tu caso un vector [Temp, Viento, Prec])
        datos_reales = containers.Map('KeyType', 'char', 'ValueType', 'any');
        preds_OM = containers.Map('KeyType', 'char', 'ValueType', 'any');
        preds_AEMET = containers.Map('KeyType', 'char', 'ValueType', 'any');

        en_captura = false;

        % 3. EXTRACCIÓN DE DATOS
        for i = 1:length(lineas)
            linea = strtrim(lineas(i)); % Elimina espacios iniciles y finales
            if isempty(linea), continue; end

            % Detectamos si es una captura a de las 11:xx o 10:xx o por la
            % mañana
            if startsWith(linea, '=== CAPTURA:')
                en_captura = contains(linea, {'16:', '13:','12:', '11:', '10:', '9:'});
                continue; % Si la linea es CAPTURA no la procesamos como datos
            end

            % Extraemos Reales (Siempre)
            if startsWith(linea, 'REAL')
                partes = split(linea);
                fch = char(partes(2));
                % Guardamos un vector: [Temp, Viento, Prec]
                datos_reales(fch) = [str2double(partes(3)), str2double(partes(4)), str2double(partes(5))];

            % Extraemos predicciones solo si estamos en captura de las
            % 11:00 o de las 10:00
            elseif en_captura
                if  startsWith(linea, 'PRED_OM')
                    partes = split(linea);                    
                    fch = char(partes(2));
                    if ~isKey(preds_OM, fch) % Para que no sobreescriba
                        preds_OM(fch) = [str2double(partes(3)), str2double(partes(4)), str2double(partes(5))];
                    end                    
                elseif startsWith(linea, 'PRED_AEMET')
                    partes = split(linea);
                    fch = char(partes(2));                
                    if ~isKey(preds_AEMET, fch) % Para que no sobreescriba
                        preds_AEMET(fch) = [str2double(partes(3)), str2double(partes(4)), str2double(partes(5))];
                    end                    
                end
            end
        end
        
        % Nos quedamos con las fechas que estan en los 3 conjuntos
        fechas_comunes = intersect(intersect(keys(preds_OM), keys(preds_AEMET)), keys(datos_reales));
        num_datos = length(fechas_comunes);

        % Ahora preparamos las matrices (X: entradas OM y AEMET, Y: salida Real)
        X_temp = zeros(num_datos, 2);   Y_temp = zeros(num_datos, 1);
        X_viento = zeros(num_datos, 2); Y_viento = zeros(num_datos, 1);
        X_prec = zeros(num_datos, 2);   Y_prec = zeros(num_datos, 1);

        for i = 1:num_datos
            fch = fechas_comunes{i};
            
            valores_reales = datos_reales(fch); % valores son vectores
            valores_om = preds_OM(fch); 
            valores_aemet = preds_AEMET(fch);

            % Rellenamos Temperatura
            X_temp(i, :) = [valores_om(1) valores_aemet(1)];
            Y_temp(i, 1) = [valores_reales(1)];

            % Rellenamos Viento
            X_viento(i, :) = [valores_om(2) valores_aemet(2)];
            Y_viento(i, 1) = [valores_reales(2)];

            % Rellenamos Precipitación
            X_prec(i, :) = [valores_om(3) valores_aemet(3)];
            Y_prec(i, 1) = [valores_reales(3)];
        end

        % -----------------------------------------------------------------
        % LIMPIEZA DE VALORES NULOS (NaNs)
        % Descartamos (fila) completa si hay algún NaN en X o en Y por
        % variable, ya que para cada variable tenemos un modelo.
        % Nunca se pone a 0, porque 0ºC o 0km/h son valores reales que
        % confundirían al modelo.
        % -----------------------------------------------------------------        
        
        % Creamos máscaras lógicas: ~any(isnan(matriz), 2) significa: 
        % "Quédate solo con las filas donde NO haya NINGÚN NaN"
        
        % 1. Limpiamos Temperatura
        filas_validas_temp = ~any(isnan([X_temp, Y_temp]), 2);
        X_temp = X_temp(filas_validas_temp, :);
        Y_temp = Y_temp(filas_validas_temp, :);
        
        % 2. Limpiamos Viento
        filas_validas_viento = ~any(isnan([X_viento, Y_viento]), 2);
        X_viento = X_viento(filas_validas_viento, :);
        Y_viento = Y_viento(filas_validas_viento, :);
                
        % 3. Limpiamos Precipitación
        filas_validas_prec = ~any(isnan([X_prec, Y_prec]), 2);
        X_prec = X_prec(filas_validas_prec, :);
        Y_prec = Y_prec(filas_validas_prec, :);

        % Mostramos cuántos datos útiles nos han quedado para entrenar
        fprintf('Datos útiles Temp: %d | Viento: %d | Prec: %d\n', ...
            size(X_temp,1), size(X_viento,1), size(X_prec,1));

        % -----------------------------------------------------------------        

        % En este punto ya tenemos nuestras matrices de caracteristicas y
        % las salidas limpios

        % Podemos ver como se encuentran estos puntos en el espacio, ya que
        % ajustaremos un modelo polinómico => visualizacionDATOS

        % =========================================================================
        % ENTRENAMIENTO MANUAL (Mediante Pseudo-inversa)
        % =========================================================================
        
        % 1. TEMPERATURA
        A_temp = [X_temp ones(size(X_temp, 1), 1)];
        coefs_temp = pinv(A_temp) * Y_temp;  % aX1 + bX2 + c => a = coef de OM, b = coef de AEMET
        y_temp_pred = A_temp * coefs_temp;

        
        % 2. VIENTO
        A_viento = [X_viento ones(size(X_viento, 1), 1)];
        coefs_viento = pinv(A_viento) * Y_viento; % Coefs diferentes a modelo_Viento, ya que ahi usamos robust on
        y_viento_pred = A_viento * coefs_viento;
        
        % 3. PRECIPITACIÓN
        A_prec = [X_prec ones(size(X_prec, 1), 1)];
        coefs_prec = pinv(A_prec) * Y_prec; 
        y_prec_pred = A_prec * coefs_prec;
        
        % Calculo de errores de entrenamiento
        RMSE_temp_train = sqrt(sum((Y_temp - y_temp_pred).^2)/ size(Y_temp, 1)); % Sale mas o menos como el fitlm, solo que ahi el RMSE la division es entre N - p, siendo p el número de parametros, que son 3 (el intercepto, el peso de OM y el peso de AEMET)
        RMSE_viento_train = sqrt(sum((Y_viento - y_viento_pred).^2)/ size(Y_viento, 1)); % Sale mas o menos como el fitlm, solo que ahi el RMSE la division es entre N - p, siendo p el número de parametros, que son 3 (el intercepto, el peso de OM y el peso de AEMET)        
        RMSE_prec_train = sqrt(sum((Y_prec - y_prec_pred).^2)/ size(Y_prec, 1)); % Sale mas o menos como el fitlm, solo que ahi el RMSE la division es entre N - p, siendo p el número de parametros, que son 3 (el intercepto, el peso de OM y el peso de AEMET)


        save('modelo.mat', 'X_temp', 'Y_temp', 'X_viento', 'Y_viento', 'X_prec', 'Y_prec', 'fechas_comunes', 'num_datos', 'coefs_temp', 'coefs_viento', 'coefs_prec','RMSE_temp_train', 'RMSE_viento_train', 'RMSE_prec_train');
        
    catch e
        fprintf('\n[ERROR EN ENTRENAMIENTO]: %s\n', e.message);
    end
end
