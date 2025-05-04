function result = simulate_model(modelName, simTime, outputParams)
    % SIMULATE_MODEL Run a simulation of the specified model
    % 
    % Inputs:
    %   modelName - Name of the model to simulate
    %   simTime - (Optional) Simulation stop time, defaults to model settings
    %   outputParams - (Optional) Structure of simulation parameters
    %
    % Output:
    %   result - Structure containing simulation results
    
    try
        % Validate input
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
        
        % Set up simulation options
        simOpts = simget(modelName);
        
        % Override stop time if specified
        if nargin >= 2 && ~isempty(simTime)
            fprintf('Setting simulation stop time to %s\n', num2str(simTime));
            simOpts = simset(simOpts, 'StopTime', num2str(simTime));
        end
        
        % Override other simulation parameters if specified
        if nargin >= 3 && ~isempty(outputParams) && isstruct(outputParams)
            paramFields = fieldnames(outputParams);
            for i = 1:length(paramFields)
                paramName = paramFields{i};
                paramValue = outputParams.(paramName);
                
                % Convert to string if numeric
                if isnumeric(paramValue)
                    if isscalar(paramValue)
                        paramValue = num2str(paramValue);
                    else
                        paramValue = mat2str(paramValue);
                    end
                end
                
                fprintf('Setting simulation parameter %s = %s\n', paramName, paramValue);
                simOpts = simset(simOpts, paramName, paramValue);
            end
        end
        
        % Get model configuration
        try
            configSet = getActiveConfigSet(modelName);
            solver = get_param(configSet, 'SolverName');
            solverType = get_param(configSet, 'SolverType');
            stepSize = get_param(configSet, 'FixedStep');
        catch
            solver = 'unknown';
            solverType = 'unknown';
            stepSize = 'auto';
        end
        
        fprintf('Starting simulation of model %s...\n', modelName);
        fprintf('Solver: %s (%s), Step size: %s\n', solver, solverType, stepSize);
        
        % Start timer to measure simulation time
        tic;
        
        % Run the simulation
        simOut = sim(modelName, simOpts);
        
        % Record elapsed time
        elapsedTime = toc;
        fprintf('Simulation completed in %.2f seconds\n', elapsedTime);
        
        % Get model snapshot after simulation
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Extract simulation data if available
        simData = struct();
        
        % Try to get output data from simulation
        if ~isempty(simOut)
            % Get the names of variables in the simulation output
            outputVarNames = fieldnames(simOut);
            
            for i = 1:length(outputVarNames)
                varName = outputVarNames{i};
                
                % Skip internal Simulink fields
                if startsWith(varName, 'simlog_') || ...
                   strcmp(varName, 'ErrorMessage') || ...
                   strcmp(varName, 'tout')
                    continue;
                end
                
                % Check if it's time series data
                if isa(simOut.(varName), 'Simulink.SimulationData.Signal') || ...
                   isa(simOut.(varName), 'timeseries')
                    
                    % Extract time and data
                    try
                        if isa(simOut.(varName), 'Simulink.SimulationData.Signal')
                            timeData = simOut.(varName).Time;
                            signalData = simOut.(varName).Data;
                        else % timeseries
                            timeData = simOut.(varName).Time;
                            signalData = simOut.(varName).Data;
                        end
                        
                        % If data is large, take samples
                        maxSamples = 100; % Maximum number of samples to include
                        if length(timeData) > maxSamples
                            indices = round(linspace(1, length(timeData), maxSamples));
                            timeData = timeData(indices);
                            signalData = signalData(indices, :);
                        end
                        
                        % Store in result
                        simData.(varName).time = timeData;
                        simData.(varName).values = signalData;
                        simData.(varName).sampleCount = length(timeData);
                    catch dataErr
                        % Skip if we can't extract data properly
                        fprintf('Could not extract data for %s: %s\n', varName, dataErr.message);
                    end
                end
            end
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'modelName', modelName, ...
                       'simulationTime', elapsedTime, ...
                       'solver', solver, ...
                       'solverType', solverType, ...
                       'stepSize', stepSize, ...
                       'snapshot', pngBase64);
                   
        % Add simulation data if available
        if ~isempty(fieldnames(simData))
            result.data = simData;
        end
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'error', errorMsg);
        
        fprintf('Error simulating model: %s\n', errorMsg);
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end