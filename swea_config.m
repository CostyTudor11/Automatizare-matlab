function cfg = swea_config()
% Configuratia utilizatorului. Implicit: DEMO, fara acces la aparate.
cfg.mode = "demo";                   % "demo" sau "usb"
cfg.dut = "TL082_gain2";
cfg.fStart = 1;
cfg.fStop = 5e6;
cfg.pointsPerDecade = 100;
cfg.frequencyOverride = [];          % ex. [10 1000 100000] pentru proba initiala
cfg.waveform = "SINE";               % acest test Bode este definit pentru sinus
cfg.vinVpp = 0.5;
cfg.offsetV = 0;
cfg.expectedGain = 2;                % doar scala initiala, nu rezultatul masurat
cfg.supplyV = [-10 10];              % metadate; scriptul NU controleaza sursa
cfg.probe = [1 1];                   % trebuie sa coincida cu pozitia fizica
cfg.generatorResource = "";          % gol: detectie USB dupa model
cfg.scopeResource = "";
cfg.outputRoot = fullfile(pwd, 'rezultate_SwEA');
cfg.cyclesOnScreen = 5;
cfg.horizontalDivisions = 10;         % verificat prin ACQ:POIN? / ACQ:SRAT?
cfg.settleCycles = 2;
cfg.minSettleS = 0.10;                % valoare initiala de validat pe banc
cfg.extraSettleS = 0;                 % se mareste pentru DUT cu tranzitorii lente
cfg.minTimeoutS = 10;
cfg.maxAttempts = 3;
cfg.minSamplesPerCycle = 50;
cfg.inputTolerance = 0.05;
cfg.frequencyTolerance = 0.005;
cfg.sineRatioTolerance = 0.10;
cfg.cutoffDropDB = 10*log10(2);
cfg.plateauBandHz = [10 1000];        % referinta masurata, modificabila
cfg.plateauToleranceDB = 0.25;        % abatere maxima fata de mediana
cfg.maxCutoffGapDecades = 0.03;       % fara interpolare peste goluri mari
% DEMO: model ideal cu un pol, A0=2, fc=1.5 MHz. NU model validat TL082.
cfg.demoGain = 2;
cfg.demoPoleHz = 1.5e6;
end
