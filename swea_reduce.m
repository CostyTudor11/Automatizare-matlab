function r = swea_reduce(m, cfg, f, calc)
% m: [Vpp1 Vpp2 CRMS1 CRMS2 CMEAN1 CMEAN2 FREQ1 FRR_seconds]
if nargin<4, calc=swea_numeric_formulas(); end
% Valorile brute raman in CSV chiar daca reducerea este invalidata.
r = struct('vinAC',NaN,'voutAC',NaN,'gain',NaN,'gainDB',NaN, ...
    'phase',NaN,'status',"OK");
flags = strings(0,1);
if any(~isfinite(m(1:7))) || any(abs(m(1:7))>1e20) || any(m(1:4)<=0)
    r.status = "INVALID_AMPLITUDE_OR_FREQUENCY";
    return
end
ac2 = m(3:4).^2-m(5:6).^2;
if any(ac2<=0)
    r.status = "INVALID_AC_RMS";
    return
end
r.vinAC = sqrt(ac2(1));
r.voutAC = sqrt(ac2(2));
r.gain = r.voutAC/r.vinAC;
r.gainDB = calc.gainDB(r.vinAC,r.voutAC);
if abs(m(7)/f-1)>cfg.frequencyTolerance
    flags(end+1) = "FREQUENCY_MISMATCH";
    r.gain = NaN; r.gainDB = NaN;
end
if abs(m(1)/cfg.vinVpp-1)>cfg.inputTolerance
    flags(end+1) = "INPUT_NOT_AT_TARGET";
end
shapeRatio = m(1:2)./(2*sqrt(2)*sqrt(ac2));
if any(abs(shapeRatio-1)>cfg.sineRatioTolerance)
    flags(end+1) = "CHECK_WAVEFORM_OR_NOISE";
    r.gain=NaN; r.gainDB=NaN;
end
% FRR = intarzierea frontului crescator CH2 fata de CH1.
% Includerea unei perioade intregi nu schimba faza dupa wrap.
if ~isfinite(m(8)) || abs(m(8)*m(7))>1.05
    flags(end+1) = "INVALID_DELAY";
elseif isfinite(r.gainDB)
    r.phase = mod(calc.phaseDeg(m(7),m(8))+180,360)-180;
end
if ~isempty(flags), r.status = strjoin(flags,"|"); end
end
