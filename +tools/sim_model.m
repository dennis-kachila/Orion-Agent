function result = sim_model(modelName, simTime)
    % SIM_MODEL Simulates a Simulink model and returns results
    % Wrapper around sim with workspace output return
    %
    % Inputs:
    %   modelName - Name of the Simulink model
    %   simTime - Simulation time in seconds (optional, default: 10)
    %
    % Output:
    %   result - Structure containing simulation results and status
    
    try
        % Ensure the model is open
        if ~bdIsLoaded(modelName)
            error('Model %s is not loaded.', modelName);
        end
        
        % Set default simulation time if not provided
        if nargin < 2 || isempty(simTime)
            simTime = 10;
        end
        
        % Set simulation parameters
        set_param(modelName, 'StopTime', num2str(simTime));
        
        % Validate the model before simulation
        try
            Simulink.BlockDiagram.validate(modelName);
        catch ME
            error('Model validation failed: %s', ME.message);
        end
        
        % Simulate the model with workspace outputs
        simOut = sim(modelName, 'ReturnWorkspaceOutputs', 'on');
        
        % Extract output data
        outputData = struct();
        
        % Get all fields from simOut
        fields = fieldnames(simOut);
        for i = 1:length(fields)
            field = fields{i};
            
            % Skip metadata fields
            if strcmp(field, 'ErrorMessage') || strcmp(field, 'SimulationMetadata')
                continue;
            end
            
            % Extract the data
            data = simOut.(field);
            
            % If it's a timeseries, get the time and values
            if isa(data, 'timeseries')
                time = data.Time;
                values = data.Data;
                
                % Limit data points to avoid overwhelming the LLM
                maxDataPoints = 20;
                if length(time) > maxDataPoints
                    indices = round(linspace(1, length(time), maxDataPoints));
                    time = time(indices);
                    values = values(indices, :);
                end
                
                outputData.(field) = struct('time', time, 'values', values);
            else
                % For other types, just store directly
                outputData.(field) = data;
            end
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
                       'simTime', simTime, ...
                       'outputs', outputData, ...
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
