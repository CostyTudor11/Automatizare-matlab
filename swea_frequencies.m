function f = swea_frequencies(cfg)
if ~isempty(cfg.frequencyOverride)
    f = cfg.frequencyOverride(:);
else
    validateattributes(cfg.fStart, {'numeric'}, {'scalar','positive','finite'});
    validateattributes(cfg.fStop, {'numeric'}, {'scalar','>=',cfg.fStart,'finite'});
    validateattributes(cfg.pointsPerDecade, {'numeric'}, {'scalar','integer','positive'});
    k = 0:floor(cfg.pointsPerDecade*log10(cfg.fStop/cfg.fStart));
    f = cfg.fStart*10.^(k/cfg.pointsPerDecade);
    if abs(f(end)-cfg.fStop) > 1e-12*cfg.fStop
        f(end+1) = cfg.fStop;
    else
        f(end) = cfg.fStop;
    end
    f = f(:);
end
assert(all(isfinite(f) & f > 0) && all(diff(f)>0), ...
    'Frecventele trebuie sa fie pozitive, finite si strict crescatoare.');
assert(max(f)<=30e6, 'SDG1032X: limita de sinus este 30 MHz.');
end
