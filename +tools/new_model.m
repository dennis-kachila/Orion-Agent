function result = new_model(modelName)
    % NEW_MODEL Creates a new Simulink model and opens it
    % Wrapper for new_system + open_system
    %
    % Input:
    %   modelName - Name for the new Simulink model
    %
    % Output:
    %   result - Structure containing model handle and status
    
    try
        % Check if model already exists
        if bdIsLoaded(modelName)
            close_system(modelName, 0); % Close without saving
        end
        
        if exist([modelName, '.slx'], 'file')
            warning('Model %s already exists. Creating a new instance.', modelName);
        end
        
        % Create new model
        new_system(modelName);
        
        % Open the model
        open_system(modelName);
        
        % Get model handle
        modelHandle = get_param(modelName, 'Handle');
        
        % Create snapshot for visualization
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'modelName', modelName, ...
                       'modelHandle', modelHandle, ...
                       'snapshot', pngBase64);
    catch ME
        % Handle errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg);
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding for snapshot data
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end
