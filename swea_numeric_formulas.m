function calc = swea_numeric_formulas()
% Forme numerice echivalente, pentru apelul direct run_swea si pentru teste.
% SwEA.m genereaza aceleasi functii pornind de la syms.
calc.gainDB = @(vin,vout) 20*log10(vout./vin);
calc.phaseDeg = @(f,delay) -360*f.*delay;
end
