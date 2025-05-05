function result = open_existing_model(modelPath)
    % OPEN_EXISTING_MODEL Open an existing .slx/.mdl model
    % 
    % Input:
    %   modelPath - Path to the model file to open
    %
    % Output:
    %   result - Structure containing model information and status
    
    try
        % Validate input
        if nargin < 1 || isempty(modelPath)
            error('Model path must be specified');
        end
        
        % Use absolute path if relative path is provided
        if ~isempty(modelPath) && ~ispc && modelPath(1) ~= '/' || ispc && ~contains(modelPath, ':')
            modelPath = fullfile(pwd, modelPath);
        end
        
        % Check file extension
        [~, modelName, modelExt] = fileparts(modelPath);
        
        % Add extension if needed
        if isempty(modelExt)
            % Try both .slx and .mdl extensions
            if exist([modelPath, '.slx'], 'file')
                modelPath = [modelPath, '.slx'];
                modelExt = '.slx';
            elseif exist([modelPath, '.mdl'], 'file')
                modelPath = [modelPath, '.mdl'];
                modelExt = '.mdl';
            else
                error('Model file not found: %s (with either .slx or .mdl extension)', modelPath);
            end
        end
        
        fprintf('Opening Simulink model: %s\n', modelPath);
        
        % Check if file exists
        if ~exist(modelPath, 'file')
            error('Model file does not exist: %s', modelPath);
        end
        
        % Check if model is already loaded
        if bdIsLoaded(modelName)
            fprintf('Model %s is already loaded\n', modelName);
            
            % Get the current model info
            isLibrary = bdIsLibrary(modelName);
            try
                modelVersion = get_param(modelName, 'ModelVersion');
            catch
                modelVersion = '';
            end
        else
            % Load the model
            fprintf('Loading model %s\n', modelName);
            load_system(modelPath);
            
            % Get model info
            isLibrary = bdIsLibrary(modelName);
            try
                modelVersion = get_param(modelName, 'ModelVersion');
            catch
                modelVersion = '';
            end
            
            fprintf('Model %s loaded successfully\n', modelName);
        end
        
        % Open model diagram if not already open
        open_system(modelName);
        fprintf('Model diagram opened\n');
        
        % Get a snapshot of the model
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch snapshotError
            fprintf('Warning: Could not create model snapshot: %s\n', snapshotError.message);
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'summary', sprintf('Opened model: %s', modelName), ...
                       'modelName', modelName, ...
                       'modelPath', modelPath, ...
                       'isLibrary', isLibrary, ...
                       'modelVersion', modelVersion, ...
                       'snapshot', pngBase64);
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.safeRedactErrors(ME);
        errorMsg = sprintf('An error occurred: %s\nIf this persists, please check your input or contact support.', errorMsg);
        result = struct('status', 'error', ...
                       'error', errorMsg, ...
                       'summary', sprintf('Failed to open model: %s', errorMsg));
        
        fprintf('Error opening model: %s\n', errorMsg);
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end