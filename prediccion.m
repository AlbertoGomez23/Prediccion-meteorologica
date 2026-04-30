% -------------------------------------------------------------------------
% FUNCION: prediccion
%
% DESCRIPCION:
% Esta función se encarga del proceso de generación del fichero
% miprediccion.txt
%
% FUNCIONAMIENTO:
% 1. Carga el Modelo.mat
% 2. Descarga los datos para realizar una predicción a 42/43 horas (de OM
% descargamos a 48 ya que nuestra predicción real del modelo sera a 42/43 horas
% ya que entrenamos con datos de predicciones de AEMET que llegan solo a
% 42/43
% horas, pero rellenaremos las restantes con predicciones de OM)
% 3. Realiza la predicción
% 4. Generamos el fichero miprediccion.txt con el formato que se pide
% -------------------------------------------------------------------------

function prediccion()
    disp('Iniciando el proceso de predicción...');
    
    try
        % 1. CARGAMOS EL MODELO
        if ~isfile('modelo.mat')
            error('No se encuentra modelo.mat. Ejecuta entrenamiento() primero.');
        end
        modelo = load('modelo.mat');
        
        % 2. CONFIGURACIÓN DE LAS APIS
        api_key = strtrim(fileread('api_aemet.txt'));
        opciones_aemet = weboptions('HeaderFields', {'api_key', api_key}, 'Timeout', 30);
        opciones_texto = weboptions('ContentType', 'text', 'CharacterEncoding', 'UTF-8');
        id_municipio = '11031'; % San Fernando
        lat = 36.4667;
        lon = -6.1983;
        
        % 3. DESCARGA OPEN-METEO (3 días para asegurar las 48h)
        disp('Descargando predicciones frescas de Open-Meteo...');
        url_om = sprintf('https://api.open-meteo.com/v1/forecast?latitude=%f&longitude=%f&hourly=temperature_2m,windspeed_10m,precipitation&forecast_days=3&timezone=Europe/Madrid', lat, lon);        
        opciones_om = weboptions('CertificateFilename', '');
        prediccion_om = webread(url_om, opciones_om);
        
        % 4. DESCARGA AEMET PREDICCIÓN HORARIA
        disp('Descargando predicciones frescas de AEMET...');
        url_pred_aemet = sprintf('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/%s', id_municipio);
        respuesta_pred_aemet = webread(url_pred_aemet, opciones_aemet);
        texto_pred_aemet = webread(respuesta_pred_aemet.datos, opciones_texto);
        datos_pred_aemet = jsondecode(texto_pred_aemet);
        
        % 5. EXTRAER AEMET A UN DICCIONARIO (MAP)
        % Para buscar por horas rápidamente
        map_aemet_t = containers.Map('KeyType', 'char', 'ValueType', 'double');
        map_aemet_v = containers.Map('KeyType', 'char', 'ValueType', 'double');
        map_aemet_p = containers.Map('KeyType', 'char', 'ValueType', 'double');
        
        dias_pred = datos_pred_aemet(1).prediccion.dia;
        for d = 1:length(dias_pred)
            if iscell(dias_pred), dia_actual = dias_pred{d}; else, dia_actual = dias_pred(d); end
            fecha_base = dia_actual.fecha;
            if iscell(fecha_base), fecha_base = fecha_base{1}; end
            fecha_corta = extractBefore(char(fecha_base), 11); 
            
            if ~isfield(dia_actual, 'temperatura'), continue; end
            temps_aemet = dia_actual.temperatura;
            
            if isfield(dia_actual, 'vientoAndRachaMax'), vientos_aemet = dia_actual.vientoAndRachaMax;
            elseif isfield(dia_actual, 'viento'), vientos_aemet = dia_actual.viento;
            else, vientos_aemet = []; end
            
            if isfield(dia_actual, 'precipitacion'), precs_aemet = dia_actual.precipitacion;
            else, precs_aemet = []; end
            
            for h = 1:length(temps_aemet)
                try
                    if iscell(temps_aemet), t_dato = temps_aemet{h}; else, t_dato = temps_aemet(h); end
                    hora_str = char(t_dato.periodo);
                    fecha_hora_pred = sprintf('%sT%s:00', char(fecha_corta), hora_str);
                    
                    % Valor Temp
                    val_t = t_dato.value; if iscell(val_t), val_t = val_t{1}; end
                    if ischar(val_t) || isstring(val_t), temp_val = str2double(val_t); else, temp_val = double(val_t(1)); end
                    
                    % Valor Viento
                    viento_val = 0.0;
                    for v = 1:length(vientos_aemet)
                        if iscell(vientos_aemet), v_dato = vientos_aemet{v}; else, v_dato = vientos_aemet(v); end
                        if strcmp(char(v_dato.periodo), hora_str) && isfield(v_dato, 'velocidad')
                            val_v = v_dato.velocidad; if iscell(val_v), val_v = val_v{1}; end
                            if ischar(val_v) || isstring(val_v), viento_val = str2double(val_v); else, viento_val = double(val_v(1)); end
                            break;
                        end
                    end
                    
                    % Valor Prec
                    prec_val = 0.0;
                    for p = 1:length(precs_aemet)
                        if iscell(precs_aemet), p_dato = precs_aemet{p}; else, p_dato = precs_aemet(p); end
                        if strcmp(char(p_dato.periodo), hora_str) && isfield(p_dato, 'value')
                            val_p = p_dato.value; if iscell(val_p), val_p = val_p{1}; end
                            if ischar(val_p) || isstring(val_p), prec_val = str2double(val_p); else, prec_val = double(val_p(1)); end
                            break;
                        end
                    end
                    
                    % Guardamos en diccionarios
                    map_aemet_t(fecha_hora_pred) = temp_val;
                    map_aemet_v(fecha_hora_pred) = viento_val;
                    map_aemet_p(fecha_hora_pred) = prec_val;
                catch
                    continue;
                end
            end
        end
        
        % 6. PREPARAR EL REGISTRO TEMPORAL (Las 48 horas siguientes)
        disp('Aplicando modelo de Machine Learning...');
        pred_final_T = zeros(1, 48);
        pred_final_V = zeros(1, 48);
        pred_final_P = zeros(1, 48);

        ultima_hora_aemet = ''; % <-- Variable para rastrear el corte hasta donde llega la predicción del modelo real
        horas_de_prediccion_reales = 0;
        % Calculamos qué hora es "ahora" redondeando hacia abajo
        t_actual = datetime('now', 'TimeZone', 'Europe/Madrid');
        t_actual.Minute = 0; t_actual.Second = 0;
        
        tiempos_om = prediccion_om.hourly.time;
        if iscell(tiempos_om), tiempos_om = string(tiempos_om); end
        
        for i = 1:48
            % Calculamos la fecha/hora objetivo (i horas en el futuro)
            t_obj = t_actual + hours(i);            
            str_obj = datestr(t_obj, 'yyyy-mm-ddTHH:MM');
            
            % Buscamos el índice en Open-Meteo
            idx_om = find(strcmp(tiempos_om, str_obj));
            if isempty(idx_om)
                % Salvavidas por si OM falla
                pred_final_T(i) = NaN; pred_final_V(i) = NaN; pred_final_P(i) = NaN;
                continue; 
            end
            
            om_T = prediccion_om.hourly.temperature_2m(idx_om);
            om_V = prediccion_om.hourly.windspeed_10m(idx_om);
            om_P = prediccion_om.hourly.precipitation(idx_om);
            
            % Comprobamos si AEMET llega a esta hora
            if isKey(map_aemet_t, str_obj)
                horas_de_prediccion_reales = horas_de_prediccion_reales + 1;
                ultima_hora_aemet = str_obj; % Asi sabremos hasta que hora llega nuestro modelo realmente

                aemet_T = map_aemet_t(str_obj);
                aemet_V = map_aemet_v(str_obj);
                aemet_P = map_aemet_p(str_obj);
                
                % Aplicamos el modelo => Fórmula: (OM * coef1) + (AEMET * coef2) + Intercepto
                pred_final_T(i) = [om_T, aemet_T, 1] * modelo.coefs_temp;
                pred_final_V(i) = [om_V, aemet_V, 1] * modelo.coefs_viento;
                pred_final_P(i) = [om_P, aemet_P, 1] * modelo.coefs_prec;
                
                % Si hay algun valor negativo lo ponemos a cero
                if pred_final_V(i) < 0, pred_final_V(i) = 0; end
                if pred_final_P(i) < 0, pred_final_P(i) = 0; end
            else
                % Si ya no hay datos de AEMET, pasamos la predicción de OM directa
                pred_final_T(i) = om_T;
                pred_final_V(i) = om_V;
                pred_final_P(i) = om_P;
            end
        end
        
        % Mostrar por pantalla el resultado del rastreo
        if ~isempty(ultima_hora_aemet)
            fprintf(' -> Modelo combinado aplicado con éxito.\n');
            fprintf(' -> Datos de AEMET disponibles hasta: %s\n', ultima_hora_aemet);
            fprintf(' -> El resto de horas se rellenaron con Open-Meteo puro.\n');
            fprintf(" -> Hora hasta la que llega la predicción real de nuestro modelo (ya que la API de la AEMET no envia predicciones de 48 horas): %d\n", horas_de_prediccion_reales);

        else
            fprintf(' -> AVISO: No se encontraron datos de AEMET para combinar.\n');
        end
        
        % 7. GENERACIÓN DEL FICHERO miprediccion.txt
        disp('Generando miprediccion.txt...');
        fid = fopen('miprediccion.txt', 'w');
        if fid == -1, error('No se pudo crear miprediccion.txt'); end
        
        % Línea 1: Fecha y hora exacta en el formato pedido
        fprintf(fid, '%s\n', datestr(now, 'dd-mm-yyyy hh:MM'));
        
        % Líneas 2, 3 y 4: 48 valores separados por espacios
        % Utilizamos 1:end-1 para poner espacio, y end para el salto de linea
        fprintf(fid, '%.1f ', pred_final_T(1:end-1)); fprintf(fid, '%.1f\n', pred_final_T(end));
        fprintf(fid, '%.1f ', pred_final_V(1:end-1)); fprintf(fid, '%.1f\n', pred_final_V(end));
        fprintf(fid, '%.1f ', pred_final_P(1:end-1)); fprintf(fid, '%.1f\n', pred_final_P(end));
        
        fclose(fid);
        disp('Proceso completado => Archivo miprediccion.txt generado con éxito.');
        
    catch e
        fprintf('\n[ERROR EN PREDICCION]: %s\n', e.message);
        if exist('fid', 'var') && fid ~= -1, fclose(fid); end
    end
end