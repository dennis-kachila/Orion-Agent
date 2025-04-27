function result = arrange(modelName)
    % ARRANGE Automatically arranges blocks in a Simulink model
    % Wrapper around Simulink.BlockDiagram.arrangeSystem
    %
    % Input:
    %   modelName - Name of the Simulink model
    %
    % Output:
    %   result - Structure containing status and snapshot
    
    try
        % Ensure the model is open
        if ~bdIsLoaded(modelName)
            error('Model %s is not loaded.', modelName);
        end
        
        % Arrange the blocks
        Simulink.BlockDiagram.arrangeSystem(modelName);
        
        % Validate the model
        try
            Simulink.BlockDiagram.validate(modelName);
            validationStatus = 'Model validated successfully';
        catch ME
            validationStatus = ['Model validation issue: ', ME.message];
        end
        
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
                       'validationStatus', validationStatus, ...
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
