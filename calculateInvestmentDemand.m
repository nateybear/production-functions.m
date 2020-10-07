function data = calculateInvestmentDemand(data, globals)
    % these are 1/phi_i for each firm
    adjustmentTerm = exp(globals.sigmaPhi * randn(1, globals.nfirms));
    
    % analytical solution to investment problem--these are components
    squareBracketTerm = (globals.betaL^(globals.betaL/(1-globals.betaL))) * ...
        exp(0.5 * globals.betaL^2 * globals.sigmaOptimErrL^2) - ...
        (globals.betaL^(1/(1-globals.betaL))) * exp(0.5 * globals.sigmaOptimErrL^2);
    
    const1 = globals.discountRate * (globals.betaK/(1-globals.betaL)) * ...
        exp(globals.beta0)^(1/(1-globals.betaL)) * squareBracketTerm;
    
    vec1 = (globals.discountRate * (1-globals.deprecRate)).^(0:100).';
    vec2 = cumsum(globals.rhoWage.^(2 * (0:100))).';
    vec3 = globals.sigmaXiOmega^2 * [0 cumsum(globals.rhoOmega.^(2 * (0:99)))].';
    
    expterm3 = exp(0.5 * (-globals.betaL/(1-globals.betaL))^2 * globals.sigmaXiWage^2 * vec2);
    expterm4 = exp(0.5 * (1/(1-globals.betaL))^2 * globals.rhoOmega2^2 * ...
        (globals.sigmaXiOmega1^2 * globals.rhoOmega.^(2 * (0:100)).' + vec3));
    expterm5 = exp((1/(1-globals.betaL)) * globals.sigmaXiOmega2^2 / 2);
    
    
    
    % now for the actual loop step
    % allocate investment matrix and start with
    % a small initial amount of capital
    
    data.lnKapital(1,:) = -100 * ones(1, globals.nfirms);
    
    investment = zeros(1, globals.nfirms);
    
    for period=2:globals.nperiodsTotal
        % N.B. investment here is still from previous period
        data.lnKapital(period, :) = log((1-globals.deprecRate) * ...
            exp(data.lnKapital(period-1, :)) + investment);
        
        expterm1 = exp((1/(1-globals.betaL)) * globals.rhoOmega.^(1:101).' * ...
            data.omegaT(period, :));
        expterm2 = exp(-globals.betaL/(1-globals.betaL) * globals.rhoWage.^(1:101).' * ...
            data.lnWage(period,:));
        
        investment = adjustmentTerm * const1 * expterm5 .* ...
            sum(vec1 .* expterm1 .* expterm2 .* expterm3 .* expterm4, 1);
    end
end