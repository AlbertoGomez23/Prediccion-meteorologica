% -------------------------------------------------------------------------
% FUNCION: acumula_datos_diario
%
% DESCRIPCION:
% Esta función descarga datos meteorológicos reales y predicciones desde
% diferentes fuentes (AEMET y Open-Meteo), los procesa y los guarda en un
% archivo llamado "historico.txt". En el fichero se van acumulando los datos
% con marca de fecha y hora para poder analizarlos posteriormente.
%
% FUNCIONAMIENTO:
% - Obtiene datos reales de una estación de AEMET
% - Descarga predicciones de Open-Meteo
% - Descarga predicciones horarias de AEMET
% - Procesa y limpia los datos
% - Guarda toda la información en un histórico acumulado
%
% AUTOMATIZACION:
% Para que esta función se ejecute de forma automática, es necesario
% programarla en la máquina (por ejemplo, usando el programador de tareas
% del sistema operativo o un cron en Linux/Mac) para que se ejecute cada
% cierto tiempo (por ejemplo, cada 12 horas).
% -------------------------------------------------------------------------
function acumula_datos_diario()
    % =================================================================
    % 1. CONFIGURACIÓN INICIAL
    % =================================================================
    api_key = 'TU_API_KEY_DE_AEMET'; 
    opciones_aemet = weboptions('HeaderFields', {'api_key', api_key}, 'Timeout', 30);
    opciones_texto = weboptions('ContentType', 'text', 'CharacterEncoding', 'UTF-8');

    id_estacion = '5972X'; % San Fernando real
    id_municipio = '11031'; % San Fernando predicciones
    lat = 36.4667;
    lon = -6.1983;
    
    disp('Iniciando descarga de datos...');
    
    try
        % 2. OBTENER DATOS REALES DE AEMET
        disp('1. Descargando datos reales (AEMET)...');
        url_obs = sprintf('https://opendata.aemet.es/opendata/api/observacion/convencional/datos/estacion/%s', id_estacion);
        respuesta_obs = webread(url_obs, opciones_aemet);
        texto_obs = webread(respuesta_obs.datos, opciones_texto);
        datos_reales = jsondecode(texto_obs); 
        
        % 3. OBTENER PREDICCIONES OPEN-METEO (Ajustado a hora de Madrid)
        disp('2. Descargando predicciones (Open-Meteo)...');
        url_om = sprintf('https://api.open-meteo.com/v1/forecast?latitude=%f&longitude=%f&hourly=temperature_2m,windspeed_10m,precipitation&forecast_days=2&timezone=Europe/Madrid', lat, lon);
        prediccion_om = webread(url_om);
        
        % 4. OBTENER PREDICCIONES AEMET
        disp('3. Descargando predicciones horarias (AEMET)...');
        url_pred_aemet = sprintf('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/%s', id_municipio);
        respuesta_pred_aemet = webread(url_pred_aemet, opciones_aemet);
        texto_pred_aemet = webread(respuesta_pred_aemet.datos, opciones_texto);
        datos_pred_aemet = jsondecode(texto_pred_aemet);
        
        % 5. GUARDAR TODO
        disp('4. Procesando y guardando en historico.txt...');
        fid = fopen('historico.txt', 'a');
        if fid == -1, error('No se pudo abrir el fichero'); end
        
        fprintf(fid, '=== CAPTURA: %s ===\n', datestr(now, 'yyyy-mm-dd HH:MM'));
        
        % --- AEMET REAL ---
        fprintf(fid, '--- AEMET_REAL (Fecha_Hora Temp(C) Viento(km/h) Prec(mm)) ---\n');
        for i = 1:length(datos_reales)
            try
                if iscell(datos_reales), dato = datos_reales{i}; else, dato = datos_reales(i); end
                fecha_str = dato.fint;
                if ~ischar(fecha_str) && ~isstring(fecha_str), fecha_str = char(fecha_str); end
                
                % CONVERSIÓN A HORA LOCAL (+1 HORA) Y FORMATO LIMPIO
                try
                    fecha_dt = datetime(fecha_str(1:19), 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
                    fecha_dt = fecha_dt + hours(1); % Sumamos 1 hora para que coincida con la web
                    fecha_str = datestr(fecha_dt, 'yyyy-mm-ddTHH:MM');
                catch
                    % Si falla la conversión por algún motivo, dejamos un formato básico
                    fecha_str = fecha_str(1:16); 
                end

                if isfield(dato, 'ta') && ~isempty(dato.ta), temp = dato.ta; else, temp = NaN; end
                if isfield(dato, 'vv') && ~isempty(dato.vv), viento = dato.vv * 3.6; else, viento = NaN; end
                if isfield(dato, 'prec') && ~isempty(dato.prec), prec = dato.prec; else, prec = 0.0; end
                fprintf(fid, 'REAL %s %.1f %.1f %.1f\n', fecha_str, temp, viento, prec);
            catch
                continue; 
            end
        end
        
        % --- OPEN-METEO PREDICCIONES ---
        fprintf(fid, '--- OM_PRED (Fecha_Hora Temp(C) Viento(km/h) Prec(mm)) ---\n');
        tiempos_om = prediccion_om.hourly.time;
        for i = 1:length(tiempos_om)
            if iscell(tiempos_om), fecha_om = tiempos_om{i}; else, fecha_om = tiempos_om(i); end
            fprintf(fid, 'PRED_OM %s %.1f %.1f %.1f\n', char(fecha_om), prediccion_om.hourly.temperature_2m(i), prediccion_om.hourly.windspeed_10m(i), prediccion_om.hourly.precipitation(i));
        end

        % --- AEMET PREDICCIONES ---
        fprintf(fid, '--- AEMET_PRED (Fecha_Hora Temp(C) Viento(km/h) Prec(mm)) ---\n');
        dias_pred = datos_pred_aemet(1).prediccion.dia;
        for d = 1:length(dias_pred)
            if iscell(dias_pred), dia_actual = dias_pred{d}; else, dia_actual = dias_pred(d); end
            
            fecha_base = dia_actual.fecha;
            if iscell(fecha_base), fecha_base = fecha_base{1}; end
            fecha_corta = extractBefore(char(fecha_base), 11); 
            
            if isfield(dia_actual, 'temperatura'), temps_aemet = dia_actual.temperatura; else, continue; end
            
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
                    
                    % Extraer Temperatura
                    val_t = t_dato.value;
                    if iscell(val_t), val_t = val_t{1}; end
                    if ischar(val_t) || isstring(val_t), temp_val = str2double(val_t); else, temp_val = double(val_t(1)); end
                    
                    % Extraer Viento buscando la hora exacta
                    viento_val = 0.0;
                    for v = 1:length(vientos_aemet)
                        if iscell(vientos_aemet), v_dato = vientos_aemet{v}; else, v_dato = vientos_aemet(v); end
                        if strcmp(char(v_dato.periodo), hora_str)
                            if isfield(v_dato, 'velocidad')
                                val_v = v_dato.velocidad;
                                if iscell(val_v), val_v = val_v{1}; end
                                if ischar(val_v) || isstring(val_v), viento_val = str2double(val_v); else, viento_val = double(val_v(1)); end
                            end
                            break;
                        end
                    end
                    
                    % Extraer Lluvia buscando la hora exacta
                    prec_val = 0.0;
                    for p = 1:length(precs_aemet)
                        if iscell(precs_aemet), p_dato = precs_aemet{p}; else, p_dato = precs_aemet(p); end
                        if strcmp(char(p_dato.periodo), hora_str)
                            if isfield(p_dato, 'value')
                                val_p = p_dato.value;
                                if iscell(val_p), val_p = val_p{1}; end
                                if ischar(val_p) || isstring(val_p), prec_val = str2double(val_p); else, prec_val = double(val_p(1)); end
                            end
                            break;
                        end
                    end
                    
                    fprintf(fid, 'PRED_AEMET %s %.1f %.1f %.1f\n', fecha_hora_pred, temp_val, viento_val, prec_val);
                catch
                    continue; 
                end
            end
        end
        
        fprintf(fid, '=== FIN CAPTURA ===\n\n');
        fclose(fid);
        disp('¡Proceso completado con éxito! Revisa tu archivo historico.txt');
        
    catch ME
        disp('Ocurrió un error al descargar o guardar los datos:');
        disp(ME.message);
        if exist('fid', 'var') && fid ~= -1, fclose(fid); end
    end
end