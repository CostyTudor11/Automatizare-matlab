function test_swea()
% TEST_SWEA verifica algoritmii si rularea DEMO.
% Nu deschide conexiuni USB si nu verifica aparatele.

%% 1. Configuratia si frecventele
cfg = swea_config();
cfg.mode = "demo";

f = swea_frequencies(cfg);

assert(numel(f) == 671);
assert(f(1) == 1 && f(end) == 5e6);
assert(all(diff(f) > 0));

pas_logaritmic = diff(log10(f(1:end-1)));
assert(max(abs(pas_logaritmic - 0.01)) < 1e-12);

%% 2. Castigul si faza, inclusiv cu offset continuu
vin = 0.5 / (2*sqrt(2));
vout = 2*vin;

offset_intrare = 0.03;
offset_iesire = -0.02;

% Ordinea masuratorilor:
% Vin_Vpp, Vout_Vpp, Vin_CRMS, Vout_CRMS,
% Vin_CMean, Vout_CMean, frecventa, intarziere.

m = [0.5, 1, ...
     hypot(vin,offset_intrare), ...
     hypot(vout,offset_iesire), ...
     offset_intrare, offset_iesire, ...
     1000, 1/8000];

r = swea_reduce(m,cfg,1000);

assert(abs(r.gain - 2) < 1e-12);
assert(abs(r.phase + 45) < 1e-10);
assert(r.status == "OK");

% Iesirea conduce intrarea cu 45 de grade.
m(8) = 0.875/1000;
r = swea_reduce(m,cfg,1000);

assert(abs(r.phase - 45) < 1e-10);

%% 3. Detectarea masuratorilor invalide

% Frecventa masurata difera de cea solicitata.
m(7) = 900;
r = swea_reduce(m,cfg,1000);

assert(isnan(r.gainDB));
assert(contains(r.status,"FREQUENCY_MISMATCH"));

% RMS total mai mic decat modulul componentei continue.
m(7) = 1000;
m(3) = 0.001;

r = swea_reduce(m,cfg,1000);
assert(isnan(r.gainDB));

% Raport Vpp/RMS incompatibil cu sinusul asteptat.
m = [0.5, 1, vin, 0.9, 0, 0, 1000, 1/8000];

r = swea_reduce(m,cfg,1000);

assert(isnan(r.gainDB));
assert(contains(r.status,"CHECK_WAVEFORM_OR_NOISE"));

%% 4. Frecventa de taiere pentru un model cunoscut
f_taiere_model = 1.5e6;

h = 2 ./ (1 + 1i*f/f_taiere_model);
castig_dB = 20*log10(abs(h));

c = swea_cutoff(f,castig_dB,cfg);

assert(c.Status == "OK");
assert(abs(c.Cutoff_Hz/f_taiere_model - 1) < 1e-3);

% Castig constant: nu exista taiere in interval.
c = swea_cutoff(f,6*ones(size(f)),cfg);

assert(isnan(c.Cutoff_Hz));
assert(c.Status == "NO_CUTOFF_IN_SWEEP");

% Zona de referinta nu este plata.
castig_modificat = castig_dB;
zona = f >= 10 & f <= 1000;

castig_modificat(zona) = linspace(6,4,nnz(zona));

c = swea_cutoff(f,castig_modificat,cfg);
assert(c.Status == "PLATEAU_NOT_FLAT");

% Date lipsa in apropierea taierii.
castig_modificat = castig_dB;
castig_modificat(f > 1.45e6 & f < 1.6e6) = NaN;

c = swea_cutoff(f,castig_modificat,cfg);
assert(c.Status == "INVALID_DATA_NEAR_CUTOFF");

% Mai multe treceri prin prag.
castig_modificat = castig_dB;
castig_modificat(f > 3e6 & f < 4e6) = 6;

c = swea_cutoff(f,castig_modificat,cfg);
assert(c.Status == "MULTIPLE_THRESHOLD_CROSSINGS");

%% 5. Rulare DEMO si verificarea fisierelor
folder_test = tempname;
mkdir(folder_test);

% Rezultatele temporare ale testului se sterg la iesire.
cleanup = onCleanup(@()rmdir(folder_test,'s')); %#ok<NASGU>

cfg.outputRoot = folder_test;

[rezultate,folder] = run_swea(cfg);

assert(height(rezultate) == 671);
assert(all(rezultate.Status == "SYNTHETIC_OK"));

% Trebuie sa existe un PNG si doua CSV-uri.
assert(numel(dir(fullfile(folder,'*.png'))) == 1);
assert(numel(dir(fullfile(folder,'*.csv'))) == 2);
assert(isfile(fullfile(folder,'completed.txt')));

% Verificam valorile salvate.
taiere = readtable(fullfile(folder,'cutoff.csv'));
masuratori = readtable(fullfile(folder,'measurements.csv'));

assert(abs(taiere.Cutoff_Hz/f_taiere_model - 1) < 1e-3);
assert(height(masuratori) == 671);

fprintf('\nTestele SwEA au trecut.\n');
fprintf('Aceste teste nu valideaza aparatele USB.\n');

end