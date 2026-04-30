% =========================================================================
% FUNCION: sacar_graficas_presentacion
%
% DESCRIPCION:
% Este script es una herramienta interna y auxiliar diseñada exclusivamente
% para automatizar la obtención de datos de los apartados C y D de la 
% presentación de la práctica (presentacion.pptx). 
% 
% Calcula el error global (RMSE) y la degradación del error en bloques de 
% 12 horas, comparando las predicciones pasadas de Open-Meteo, AEMET y 
% el modelo propio contra los datos meteorológicos reales.
%
% FUNCIONAMIENTO (Backtesting):
% 1. Carga el histórico ('historico.txt') y el modelo ('Modelo.mat').
% 2. Viaja en el tiempo: enfrenta las predicciones que se guardaron en 
%    su día con la realidad que acabó sucediendo.
% 3. Muestra por consola los valores numéricos exactos de error (RMSE).
% 4. Genera cuatro gráficas de barras listas para capturar y pegar en el PPT.
%
% ADVERTENCIA MUY IMPORTANTE:
% Según las instrucciones de la práctica, este código NO DEBE INCLUIRSE 
% en el archivo .zip final que se entrega. Es una herramienta personal 
% de evaluación.
% =========================================================================

% =========================================================================
% SCRIPT TEMPORAL PARA GENERAR GRÁFICAS DE LA PRESENTACIÓN (NO SE ENTREGA)
% =========================================================================
function sacar_graficas_presentacion()
    disp('Cargando datos e iniciando evaluación...');
    
    if ~isfile('modelo.mat') || ~isfile('historico.txt')
        error('Falta modelo.mat o historico.txt en la carpeta.');
    end
    
    modelo = load('modelo.mat');
    lineas = readlines('historico.txt');
    
    % 1. DICCIONARIO DE VERDAD ABSOLUTA (REAL)
    map_reales = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:length(lineas)
        linea = strtrim(lineas(i));
        if startsWith(linea, 'REAL')
            p = split(linea);
            % Guardamos: [Temp, Viento, Prec]
            map_reales(char(p(2))) = [str2double(p(3)), str2double(p(4)), str2double(p(5))];
        end
    end
    
    % 2. MATRICES PARA GUARDAR LOS ERRORES CUADRÁTICOS SEGÚN EL HORIZONTE (1 a 48h)
    % Columnas: 1=OM, 2=AEMET, 3=MI_MODELO
    err_T = cell(48, 3); err_V = cell(48, 3); err_P = cell(48, 3);
    for h = 1:48
        err_T{h,1}=[]; err_T{h,2}=[]; err_T{h,3}=[];
        err_V{h,1}=[]; err_V{h,2}=[]; err_V{h,3}=[];
        err_P{h,1}=[]; err_P{h,2}=[]; err_P{h,3}=[];
    end
    
    % 3. SIMULACIÓN DE PREDICCIONES
    cap_dt = NaT; map_om = containers.Map; map_aemet = containers.Map;
    
    for i = 1:length(lineas)
        linea = strtrim(lineas(i));
        if isempty(linea), continue; end
        
        if startsWith(linea, '=== CAPTURA:')
            % Si ya teníamos una captura cargada, evaluamos sus 48h
            if ~isnat(cap_dt)
                for h = 1:48
                    target_dt = cap_dt + hours(h);
                    fch = datestr(target_dt, 'yyyy-mm-ddTHH:MM');
                    
                    % Solo evaluamos si conocemos la realidad de esa hora
                    if isKey(map_reales, fch) && isKey(map_om, fch)
                        real_val = map_reales(fch);
                        om_val = map_om(fch);
                        
                        aemet_val = [NaN NaN NaN];
                        if isKey(map_aemet, fch), aemet_val = map_aemet(fch); end
                        
                        % Calculo de mi modelo
                        mi_T = om_val(1); mi_V = om_val(2); mi_P = om_val(3);
                        if ~isnan(aemet_val(1))
                            mi_T = [om_val(1), aemet_val(1), 1] * modelo.coefs_temp;
                            mi_V = max(0, [om_val(2), aemet_val(2), 1] * modelo.coefs_viento);
                            mi_P = max(0, [om_val(3), aemet_val(3), 1] * modelo.coefs_prec);
                        end
                        
                        % Guardar Errores Cuadráticos: (Pred - Real)^2
                        err_T{h,1}(end+1)=(om_val(1)-real_val(1))^2; err_V{h,1}(end+1)=(om_val(2)-real_val(2))^2; err_P{h,1}(end+1)=(om_val(3)-real_val(3))^2;
                        err_T{h,3}(end+1)=(mi_T-real_val(1))^2;      err_V{h,3}(end+1)=(mi_V-real_val(2))^2;      err_P{h,3}(end+1)=(mi_P-real_val(3))^2;
                        
                        if ~isnan(aemet_val(1))
                            err_T{h,2}(end+1)=(aemet_val(1)-real_val(1))^2; err_V{h,2}(end+1)=(aemet_val(2)-real_val(2))^2; err_P{h,2}(end+1)=(aemet_val(3)-real_val(3))^2;
                        end
                    end
                end
            end
            
            % Iniciamos nueva captura
            fecha_str = extractBetween(linea, "CAPTURA: ", " ===");
            try cap_dt = datetime(fecha_str, 'InputFormat', 'yyyy-MM-dd HH:mm');
                cap_dt.Minute = 0; cap_dt.Second = 0;
            catch, cap_dt = NaT; end
            map_om = containers.Map('KeyType', 'char', 'ValueType', 'any');
            map_aemet = containers.Map('KeyType', 'char', 'ValueType', 'any');
            
        elseif startsWith(linea, 'PRED_OM')
            p = split(linea); map_om(char(p(2))) = [str2double(p(3)), str2double(p(4)), str2double(p(5))];
        elseif startsWith(linea, 'PRED_AEMET')
            p = split(linea); map_aemet(char(p(2))) = [str2double(p(3)), str2double(p(4)), str2double(p(5))];
        end
    end
    
    % =========================================================================
    % CÁLCULOS Y RESULTADOS POR CONSOLA
    % =========================================================================
    % SOLUCIÓN AL NAN: Añadimos 'omitnan' para que ignore los fallos de la API
    calc_rmse = @(err_list) sqrt(mean(err_list, 'omitnan'));
    
    disp(' '); disp('===== PUNTO C: ESTIMACIÓN GLOBAL DEL ERROR (RMSE) =====');
    disp('              Open-Meteo | AEMET | MI MODELO');
    T_OM = calc_rmse([err_T{:,1}]); T_AE = calc_rmse([err_T{:,2}]); T_MI = calc_rmse([err_T{:,3}]);
    V_OM = calc_rmse([err_V{:,1}]); V_AE = calc_rmse([err_V{:,2}]); V_MI = calc_rmse([err_V{:,3}]);
    P_OM = calc_rmse([err_P{:,1}]); P_AE = calc_rmse([err_P{:,2}]); P_MI = calc_rmse([err_P{:,3}]);
    fprintf('Temperatura:  %7.2f    | %5.2f |  %5.2f\n', T_OM, T_AE, T_MI);
    fprintf('Viento:       %7.2f    | %5.2f |  %5.2f\n', V_OM, V_AE, V_MI);
    fprintf('Precipitación:%7.2f    | %5.2f |  %5.2f\n', P_OM, P_AE, P_MI);
    
    disp(' '); disp('===== PUNTO D: DEGRADACIÓN POR HORIZONTE (MI MODELO) =====');
    disp('                1-12h  | 13-24h | 25-36h | 37-48h');
    
    r_T = zeros(1,4); r_V = zeros(1,4); r_P = zeros(1,4);
    for franja = 1:4
        idx = (franja-1)*12 + 1 : franja*12;
        r_T(franja) = calc_rmse([err_T{idx,3}]);
        r_V(franja) = calc_rmse([err_V{idx,3}]);
        r_P(franja) = calc_rmse([err_P{idx,3}]);
    end
    fprintf('Temperatura:  %6.2f | %6.2f | %6.2f | %6.2f\n', r_T(1), r_T(2), r_T(3), r_T(4));
    fprintf('Viento:       %6.2f | %6.2f | %6.2f | %6.2f\n', r_V(1), r_V(2), r_V(3), r_V(4));
    fprintf('Precipitación:%6.2f | %6.2f | %6.2f | %6.2f\n', r_P(1), r_P(2), r_P(3), r_P(4));

    % =========================================================================
    % GRÁFICAS PARA EL POWERPOINT
    % =========================================================================
    nombres_fuentes = {'Open-Meteo', 'AEMET', 'Mi Modelo'};
    etiquetas_franjas = {'1-12h', '13-24h', '25-36h', '37-48h'};
    
    % FIGURA 1: COMPARATIVA GLOBAL
    figure('Name', 'Comparativa Global', 'Color', 'w');
    datos_globales = [T_OM, T_AE, T_MI; V_OM, V_AE, V_MI; P_OM, P_AE, P_MI];
    b = bar(datos_globales);
    set(gca, 'XTickLabel', {'Temperatura (°C)', 'Viento (km/h)', 'Precipitación (mm)'});
    legend(nombres_fuentes, 'Location', 'northwest');
    title('Error Global (RMSE) por Fuente y Variable');
    ylabel('RMSE'); grid on;
    
    % FIGURA 2: DEGRADACIÓN TEMPERATURA
    figure('Name', 'Degradación Temperatura', 'Color', 'w');
    bar(r_T, 'FaceColor', [0.8500 0.3250 0.0980]);
    set(gca, 'XTickLabel', etiquetas_franjas);
    title('Degradación del Error: Temperatura (°C)');
    ylabel('RMSE'); grid on;
    
    % FIGURA 3: DEGRADACIÓN VIENTO
    figure('Name', 'Degradación Viento', 'Color', 'w');
    bar(r_V, 'FaceColor', [0 0.4470 0.7410]);
    set(gca, 'XTickLabel', etiquetas_franjas);
    title('Degradación del Error: Viento (km/h)');
    ylabel('RMSE'); grid on;
    
    % FIGURA 4: DEGRADACIÓN PRECIPITACIÓN
    figure('Name', 'Degradación Precipitación', 'Color', 'w');
    bar(r_P, 'FaceColor', [0.4660 0.6740 0.1880]);
    set(gca, 'XTickLabel', etiquetas_franjas);
    title('Degradación del Error: Precipitación (mm)');
    ylabel('RMSE'); grid on;
end