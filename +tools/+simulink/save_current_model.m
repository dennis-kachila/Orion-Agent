function result = save_current_model(modelName, savePath)
    % SAVE_CURRENT_MODEL Save the active model to disk
    % 
    % Inputs:
    %   modelName - (Optional) Name of model to save, defaults to current model
    %   savePath - (Optional) Path to save the model, defaults to current path
    %
    % Output:
    %   result - Structure containing save operation status
    
    try
        % Get current model if not specified
        if nargin < 1 || isempty(modelName)
            modelName = bdroot;
            if isempty(modelName)
                error('No model is currently open');
            end
        end
        
        % Check if model is loaded
        if ~bdIsLoaded(modelName)
            error('Model %s is not loaded', modelName);
        end
        
        fprintf('Saving model: %s\n', modelName);
        
        % Handle save path
        if nargin < 2 || isempty(savePath)
            % Save to current path
            fprintf('Saving to current path\n');
            save_system(modelName);
            
            % Get actual save path
            modelPath = which(modelName);
            if isempty(modelPath)
                [~, ~, modelExt] = fileparts(get_param(modelName, 'FileName'));
                if isempty(modelExt)
                    modelExt = '.slx';
                end
                modelPath = fullfile(pwd, [modelName, modelExt]);
            end
        else
            % Save to specific path
            fprintf('Saving to path: %s\n', savePath);
            
            % Check if path is a directory or filename
            [~, ~, ext] = fileparts(savePath);
            if isempty(ext) || (ext ~= '.slx' && ext ~= '.mdl')
                % It's a directory, construct full path
                if ~exist(savePath, 'dir')
                    mkdir(savePath);
                end
                
                % Get the original file extension or default to .slx
                origFile = get_param(modelName, 'FileName');
                [~, ~, origExt] = fileparts(origFile);
                if isempty(origExt)
                    origExt = '.slx';
                end
                
                modelPath = fullfile(savePath, [modelName, origExt]);
            else
                % It's a filename, use as is
                modelPath = savePath;
            end
            
            % Save to the specified path
            save_system(modelName, modelPath);
        end
        
        fprintf('Model saved to: %s\n', modelPath);
        
        % Get a snapshot of the model
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'modelName', modelName, ...
                       'modelPath', modelPath, ...
                       'snapshot', pngBase64);
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'error', errorMsg);
        
        fprintf('Error saving model: %s\n', errorMsg);
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end