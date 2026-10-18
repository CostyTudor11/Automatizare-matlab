%% SwEA - parametrii pe care ii modifici
clear; clc;

mod_lucru = "usb";                % "demo" fara aparate; "usb" pentru masurare
Vin_Vpp = 0.500;                    % amplitudinea ceruta generatorului [Vpp]
f_min = 1;                         % [Hz]
f_max = 5e6;                       % [Hz]
puncte_pe_decada = 100;
semnal = "SINE";                   % metoda Bode implementata foloseste sinus
R_feedback = 10e3;                 % [ohm]
R_masa = 10e3;                     % [ohm]
sonde = [1 1];                     % CH1, CH2: pozitiile fizice x1 sau x10

%% Formule simbolice: se convertesc o singura data in functii numerice
assert(exist('syms','file')==2, ...
    'Pentru syms este necesar Symbolic Math Toolbox.');
syms V_intrare V_iesire Rf Rg frecventa positive
syms intarziere real

amplificare = V_iesire / V_intrare;
amplificare_dB = 20*log(amplificare)/log(sym(10));
amplificare_nominala = 1 + Rf/Rg;
faza_grade = -360*frecventa*intarziere;
scadere_la_taiere_dB = 20*log(sqrt(sym(2)))/log(sym(10));

calc.gainDB = matlabFunction(amplificare_dB,'Vars',[V_intrare V_iesire]);
calc.phaseDeg = matlabFunction(faza_grade,'Vars',[frecventa intarziere]);

%% Transmiterea setarilor si pornirea automatizarii
cfg = swea_config();
cfg.frequencyOverride = [];
cfg.mode = mod_lucru;
cfg.vinVpp = Vin_Vpp;
cfg.fStart = f_min;
cfg.fStop = f_max;
cfg.pointsPerDecade = puncte_pe_decada;
cfg.waveform = semnal;
cfg.probe = sonde;
cfg.expectedGain = double(subs(amplificare_nominala,[Rf Rg],[R_feedback R_masa]));
cfg.cutoffDropDB = double(scadere_la_taiere_dB);
cfg.plateauBandHz = [10 1000];        % banda plata folosita ca referinta
cfg.outputRoot = fullfile(fileparts(mfilename('fullpath')),'rezultate_SwEA');

% Daca detectia automata nu gaseste exact un aparat, copiezi din visadevlist:
cfg.generatorResource = "";
cfg.scopeResource = "";

[rezultate, folder_rezultate] = run_swea(cfg,calc);
fprintf('Deschide graficul: %s\n',fullfile(folder_rezultate,'bode.png'));

