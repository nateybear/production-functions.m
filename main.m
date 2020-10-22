% Optional arguments are the DGP to run (as a scalar int or row vector), measurement
% error (as a scalar double or row vector), and estimation method to use (as a scalar
% string or cell array of strings). See the parseInput function for defaults.
function main(varargin)
    rng(239482398);
    
    inp = parseInput(varargin{:});
    
    totalRuns = length(inp.DGP) * length(inp.MeasureError);
    
    % normalize estimator if just doing one
    estimatorNames = ifelse(ischar(inp.Estimator), { inp.Estimator }, inp.Estimator);
    nEstimators = length(estimatorNames);
    estimatorMap = containers.Map({ 'ACF' 'LP' 'OP' }, { @estimateACF @estimateLP @estimateOP });
    
    % loop over DGP and measure error scenarios
    for idgp = 1:length(inp.DGP)
        dgp = inp.DGP(idgp); % current DGP
        for imErr = 1:length(inp.MeasureError)
            measureError = inp.MeasureError(imErr); % current measureError
            
            % init data structures
            globals = initGlobals(dgp, measureError);
            data = initDataStruct(globals);

            % pipeline to generate monte carlo data
            dataPipeline = makePipe(@generateExogenousShocks, @generateWages,...
                    @calculateInvestmentDemand, @calculateLaborDemand, ...
                    @generateIntermediateInputDemand, @calculateFirmOutput, @keepLastN);
                
            % fns to add measurement error (not in data pipeline b/c it depends on
            % estimation method which var you are adding noise to)
            addInvestmentError = generateMeasureErrorIn('lnInvestment');
            addIntermedInputError = generateMeasureErrorIn('lnIntermedInput');

            % keep track of timings for each run
            [generateData, reportGenerateData] = makeTimed("generating data", dataPipeline, globals.niterations);
            
            
            % set up estimators and estimates as cell arrays
            estimates = cell(1, nEstimators);
            estimators = cell(1, nEstimators);
            reportEstimators = cell(1, nEstimators);
            
            for iEstimator = 1:nEstimators
                method = estimatorNames{iEstimator};
                
                [estimators{iEstimator}, reportEstimators{iEstimator}] = ...
                    makeTimed(sprintf("estimating %s", method), estimatorMap(method), globals.niterations);
                
                estimates{iEstimator} = zeros(globals.niterations, 2);
            end
            
            % show progress bar. you can close it and it will keep running.
            runNumber = (idgp-1) * length(inp.MeasureError) + imErr;
            progressBar = waitbar(0, sprintf("Running simulation (%d/%d)...", runNumber, totalRuns));
            safelyCall = safely(progressBar);
            cleanup = onCleanup(@() safelyCall(@close, progressBar));

            % the actual Monte Carlo---generate data and estimate in a loop
            for iiteration = 1:globals.niterations
                data = generateData(data, globals);
                
                for iEstimator = 1:nEstimators
                    % if doing OP estimation, add error to invesetment, o.w. add it
                    % to intermed input
                    addMeasureError = ifelse(strcmp(estimatorNames{iEstimator}, 'OP'), addInvestmentError, addIntermedInputError);
                    estimates{iEstimator}(iiteration, :) = estimators{iEstimator}(addMeasureError(data, globals), globals);
                end
                
                safelyCall(@waitbar, iiteration/globals.niterations, progressBar);
            end

            % close the progressBar (stupid you have to always check isvalid)
            safelyCall(@close, progressBar);

            % print timings for the run, save estimates to disk
            reportGenerateData();
            for iEstimator = 1:nEstimators
                reportEstimators{iEstimator}();
            
                name = estimatorNames{iEstimator};
                beta = estimates{iEstimator};
                filename = sprintf('%s_DGP%02d_Err%0.1f_%s.mat', name, dgp, measureError, date);
                save(filename, 'beta');
                fprintf('Wrote estimates to %s\n', filename);
                meanEstimate = mean(beta, 1);
                sdEstimate = std(beta, 1);
                fprintf('Estimate betaL (%s): %.4f (%.4f)\n', name, meanEstimate(1), sdEstimate(1));
                fprintf('Estimate betaK (%s): %.4f (%.4f)\n\n', name, meanEstimate(2), sdEstimate(2));
            end
        end
    end
end

function inp = parseInput(varargin)
    p = inputParser();
    addParameter(p, 'DGP', [1 2 3]);
    addParameter(p, 'MeasureError', [0.0 0.1 0.2 0.5]);
    addParameter(p, 'Estimator', { 'ACF' 'LP' 'OP' });
    
    parse(p, varargin{:});
    
    inp = p.Results;
end

% it's annoying to always check if a progress bar is closed or not
function g = safely(progressBar)
    function out = doSafely(f, varargin)
        if isvalid(progressBar)
            out = f(varargin{:});
        end
    end
    g = @doSafely;
end

% matlab has no ternary operator. shame on them.
function out = ifelse(test, ifTrue, ifFalse)
    if test
        out = ifTrue;
    else
        out = ifFalse;
    end
end