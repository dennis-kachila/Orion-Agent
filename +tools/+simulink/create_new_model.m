function result = create_new_model(modelName, savePath)
    % CREATE_NEW_MODEL Create and open a blank Simulink model
    % 
    % Inputs:
    %   modelName - Name of the model to create
    %   savePath - (Optional) Path to save the model (defaults to current directory)
    %
    % Output:
    %   result - Structure containing model information and status
    
    try
        % Parse inputs
        if nargin < 2 || isempty(savePath)
            savePath = pwd;
        end
        
        % Clean up model name if needed
        modelName = strtrim(modelName);
        if ~endsWith(modelName, '.slx') && ~endsWith(modelName, '.mdl')
            modelName = [modelName, '.slx']; % Default to .slx extension
        end
        
        % Create full path
        fullModelPath = fullfile(savePath, modelName);
        [modelDir, modelNameOnly, ~] = fileparts(fullModelPath);
        
        fprintf('Creating new Simulink model: %s\n', fullModelPath);
        
        % Make sure the directory exists
        if ~exist(modelDir, 'dir')
            fprintf('Creating directory: %s\n', modelDir);
            mkdir(modelDir);
        end
        
        % Close model if it's already open
        if bdIsLoaded(modelNameOnly)
            fprintf('Model %s is already loaded, closing it first\n', modelNameOnly);
            close_system(modelNameOnly, 0); % Don't save
        end
        
        % Check if file already exists
        if exist(fullModelPath, 'file')
            fprintf('Warning: Model file already exists. Will create new model and overwrite.\n');
        end
        
        % Create a new model
        sys = new_system(modelNameOnly);
        open_system(sys);
        
        fprintf('New model created and opened\n');
        
        % Set basic model parameters for better compatibility
        set_param(sys, 'SolverPrmCheckMsg', 'warning');
        set_param(sys, 'SolverType', 'Variable-step');
        
        % Save the model
        fprintf('Saving model to: %s\n', fullModelPath);
        save_system(sys, fullModelPath);
        
        % Get a snapshot of the model if possible
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelNameOnly);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'modelName', modelNameOnly, ...
                       'modelFullPath', fullModelPath, ...
                       'snapshot', pngBase64);
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'error', errorMsg);
        
        fprintf('Error creating model: %s\n', errorMsg);
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end