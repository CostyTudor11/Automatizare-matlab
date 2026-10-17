function result = swea_cutoff(f,gainDB,cfg)
% Taiere superioara raportata la mediana platoului masurat.
% Interpolare liniara in dB fata de log10(f), fara extrapolare.
f=f(:); gainDB=gainDB(:);
result=table(NaN,"UNDETERMINED",'VariableNames',{'Cutoff_Hz','Status'});
assert(numel(f)==numel(gainDB) && all(f>0) && all(diff(f)>0), ...
    'Date invalide pentru calculul frecventei de taiere.');
band=f>=cfg.plateauBandHz(1) & f<=cfg.plateauBandHz(2);
valid=isfinite(gainDB);
ref=band & valid;
if nnz(ref)<10 || nnz(ref)<0.8*nnz(band) || ...
        log10(max(f(ref))/min(f(ref)))<0.9
    result.Status="INSUFFICIENT_PLATEAU_DATA"; return
end
referenceDB=median(gainDB(ref));
if max(abs(gainDB(ref)-referenceDB))>cfg.plateauToleranceDB
    result.Status="PLATEAU_NOT_FLAT"; return
end
threshold=referenceDB-cfg.cutoffDropDB;
lastRef=find(ref,1,'last');
indices=find(valid & (1:numel(f))'>=lastRef);
g=gainDB(indices)-threshold;
cross=find(g(1:end-1)>0 & g(2:end)<=0);
if isempty(cross)
    result.Status="NO_CUTOFF_IN_SWEEP"; return
end
% Un raspuns cu reveniri peste prag necesita interpretare, nu un fc unic.
if numel(cross)>1 || any(g(cross(1)+1:end)>0)
    result.Status="MULTIPLE_THRESHOLD_CROSSINGS"; return
end
i=indices(cross); j=indices(cross+1);
if j~=i+1 || log10(f(j)/f(i))>cfg.maxCutoffGapDecades
    result.Status="INVALID_DATA_NEAR_CUTOFF"; return
end
fraction=(threshold-gainDB(i))/(gainDB(j)-gainDB(i));
result.Cutoff_Hz=10^(log10(f(i))+fraction*log10(f(j)/f(i)));
result.Status="OK";
if any(~valid), result.Status="OK_WITH_INVALID_POINTS_ELSEWHERE"; end
end
