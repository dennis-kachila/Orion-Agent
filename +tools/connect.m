function result = connect(modelName, sourcePath, destPath)
    % CONNECT Connect two blocks in a Simulink model
    % Wrapper around add_line with error handling
    %
    % Inputs:
    %   modelName - Name of the Simulink model
    %   sourcePath - Path to source block/port
    %   destPath - Path to destination block/port
    %
    % Output:
    %   result - Structure containing line handle and status
    
    try
        % Ensure the model is open
        if ~bdIsLoaded(modelName)
            error('Model %s is not loaded.', modelName);
        end
        
        % Add port number if not specified
        if ~contains(sourcePath, ':')
            % Try to get the first output port
            blockPorts = get_param(sourcePath, 'PortHandles');
            if ~isempty(blockPorts.Outport)
                sourcePath = [sourcePath, '/1'];
            else
                error('Source block %s has no output ports.', sourcePath);
            end
        end
        
        if ~contains(destPath, ':')
            % Try to get the first input port
            blockPorts = get_param(destPath, 'PortHandles');
            if ~isempty(blockPorts.Inport)
                destPath = [destPath, '/1'];
            else
                error('Destination block %s has no input ports.', destPath);
            end
        end
        
        % Connect the blocks
        lineHandle = add_line(modelName, sourcePath, destPath, 'autorouting', 'on');
        
        % Create snapshot for visualization
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'lineHandle', lineHandle, ...
                       'sourcePath', sourcePath, ...
                       'destPath', destPath, ...
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
