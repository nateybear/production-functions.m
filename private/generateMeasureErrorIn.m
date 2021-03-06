% generate iid measurement error that is proportional to within-group stddev
function f = generateMeasureErrorIn(var)
    
f = @(data, globals) generateMeasureError(var, data, globals);

end

function data = generateMeasureError(var, data, globals)
 
epsilon = randn(size(data.(var)));

groupMeans = mean(data.(var), 1);
withinvar = mean((data.(var) - groupMeans).^2, 'all');

data.(var) = data.(var) + globals.measureError * sqrt(withinvar) * epsilon;

end