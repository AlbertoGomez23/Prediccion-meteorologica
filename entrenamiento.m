% -------------------------------------------------------------------------
% FUNCION: entrenamiento
%
% DESCRIPCION:
% Esta función se encarga del proceso de entrenamiento del modelo,
% generando ademas un archivo Modelo.mat con cual se realizaran las 
% correspondientes predicciones.
% 
% OJO: Como las predicciones que haremos seran a las 48 horas próximas
% entrenaremos al modelo con ello, por ejemplo, 
% FUNCIONAMIENTO:
% - Obtiene los datos recopilados en historico.txt
% - 
% - 
% - 
% - 
% -------------------------------------------------------------------------

function entrenamiento()
    % =================================================================
    % 1. Lectura de datos de historico.txt
    % =================================================================
    fid = -1;
    try
        fid = fopen('historico.txt', 'r');
        if fid == -1
            error('No se pudo abrir el archivo: historico.txt')
        end

        % Si el fichero se abrio correctamente ......
        % Leer el archivo y obtener todos los datos necesarios
        
    catch e
        fprintf('Error: %s\n', e.message);
        if fid ~= -1
            fclose(fid);   % cerrar si quedó abierto
        end
    end
end