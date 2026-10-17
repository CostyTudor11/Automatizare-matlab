function [results, outDir] = run_swea(cfg, calc)
% RUN_SWEA
% Masurare Bode: SIGLENT SDG1032X + SDS824X HD.
%
% DEMO:
%   run_swea();
%
% USB:
%   cfg = swea_config();
%   cfg.mode = "usb";
%   run_swea(cfg);
%
% Comenzile USB necesita validare pe aparate.

%% 1. Verificarea configuratiei

if nargin == 0
    cfg = swea_config();
end

if nargin < 2
    calc = swea_numeric_formulas();
end

assert(ismember(cfg.mode,["demo","usb"]), ...
    'mode trebuie sa fie demo sau usb.');

assert(strcmpi(cfg.waveform,"SINE"), ...
    'Acest test Bode necesita semnal sinusoidal.');

validateattributes(cfg.vinVpp,{'numeric'}, ...
    {'scalar','positive','finite','<=',20});

validateattributes(cfg.offsetV,{'numeric'}, ...
    {'scalar','finite'});

assert(cfg.offsetV == 0, ...
    'Prima versiune foloseste offset 0 V.');

assert(numel(cfg.probe) == 2 && ...
    all(ismember(cfg.probe,[1 10])), ...
    'Factorii sondelor trebuie sa fie 1 sau 10.');

%% 2. Frecventele si folderul de rezultate

f = swea_frequencies(cfg);

modeTag = upper(cfg.mode);

if cfg.mode == "demo"
    modeTag = "DEMO_SYNTHETIC";
end

if ~isfolder(cfg.outputRoot)
    mkdir(cfg.outputRoot);
end

[~,uniqueName] = fileparts(tempname(cfg.outputRoot));

outDir = fullfile(cfg.outputRoot, ...
    char(modeTag + "_" + string(cfg.dut) + "_" + ...
    string(datetime('now','Format','yyyyMMdd_HHmmss')) + ...
    "_" + string(uniqueName)));

mkdir(outDir);

save(fullfile(outDir,'config.mat'),'cfg');

writeText(fullfile(outDir,'config.json'), ...
    jsonencode(cfg,'PrettyPrint',true));

logPath = fullfile(outDir,'instrument_log.txt');

appendLog(logPath, ...
    "MODE=" + modeTag + "; faza=iesire minus intrare");

%% 3. Variabilele de lucru

gen = [];
scope = [];

results = table();

scale = [ ...
    chooseScale(cfg.vinVpp/5,cfg.probe(1)), ...
    chooseScale(cfg.vinVpp*cfg.expectedGain/5,cfg.probe(2)) ...
    ];

lastTimeScale = NaN;
lastScale = [NaN NaN];

started = tic;

try

    %% 4. Conectarea si configurarea aparatelor

    if cfg.mode == "usb"

        gen = openInstrument( ...
            cfg.generatorResource,"SDG1032X",cfg,logPath);

        % Capturam obiectul generatorului imediat dupa conectare.
        cleanupGen = onCleanup( ...
            @()stopInstrument(gen,'C1:OUTP OFF')); %#ok<NASGU>

        send(gen,'C1:OUTP OFF',logPath);

        scope = openInstrument( ...
            cfg.scopeResource,"SDS824X HD",cfg,logPath);

        % Capturam obiectul osciloscopului imediat dupa conectare.
        cleanupScope = onCleanup( ...
            @()stopInstrument(scope,':TRIGger:STOP')); %#ok<NASGU>

        configureHardware(gen,scope,cfg,logPath);

        send(gen,'C1:OUTP ON',logPath);

    end

    %% 5. Parcurgerea frecventelor

    for i = 1:numel(f)

        pointStarted = tic;

        attempts = 1;
        actualTimeScale = NaN;
        nSamples = NaN;
        sampleRate = NaN;

        if cfg.mode == "demo"

            % Model demonstrativ cu un singur pol.
            h = cfg.demoGain/(1 + 1i*f(i)/cfg.demoPoleHz);

            vi = cfg.vinVpp;
            vo = vi*abs(h);

            delay = mod(-angle(h)/(2*pi),1)/f(i);

            % Vin_Vpp, Vout_Vpp, Vin_CRMS, Vout_CRMS,
            % Vin_CMean, Vout_CMean, frecventa, intarziere.
            m = [ ...
                vi, vo, ...
                vi/(2*sqrt(2)), vo/(2*sqrt(2)), ...
                0, 0, f(i), delay ...
                ];

        else

            %% Setarea frecventei si a bazei de timp

            send(scope,':TRIGger:STOP',logPath);

            send(gen, ...
                sprintf('C1:BSWV FRQ,%.12g',f(i)),logPath);

            target = nice125( ...
                cfg.cyclesOnScreen/(cfg.horizontalDivisions*f(i)));

            if ~isequal(target,lastTimeScale)

                send(scope, ...
                    sprintf(':TIMebase:SCALe %.12g',target),logPath);

                lastTimeScale = target;

            end

            actualTimeScale = numQuery( ...
                scope,':TIMebase:SCALe?',logPath);

            assert(actualTimeScale > 0 && actualTimeScale < 1e10, ...
                'Baza de timp invalida.');

            pause(max(cfg.minSettleS,cfg.settleCycles/f(i)) ...
                + cfg.extraSettleS);

            %% Achizitia si eventualele repetari

            for attempts = 1:cfg.maxAttempts

                for ch = 1:2

                    if ~isequal(scale(ch),lastScale(ch))

                        send(scope, ...
                            sprintf(':CHANnel%d:SCALe %.12g', ...
                            ch,scale(ch)),logPath);

                        scale(ch) = numQuery(scope, ...
                            sprintf(':CHANnel%d:SCALe?',ch),logPath);

                        assert(isfinite(scale(ch)) && scale(ch) > 0, ...
                            'Scala verticala invalida.');

                        lastScale(ch) = scale(ch);

                    end

                end

                scope.Timeout = ceil(max(cfg.minTimeoutS, ...
                    3*cfg.horizontalDivisions*actualTimeScale + 3/f(i)));

                send(scope,':ACQuire:CSWeep',logPath);
                send(scope,':TRIGger:MODE SINGle',logPath);

                % OPC singur nu dovedeste finalizarea achizitiei.
                assert(strtrim(query(scope,'*OPC?',logPath)) == "1", ...
                    'OPC invalid.');

                waitSingle(scope,scope.Timeout,logPath);

                nAcq = numQuery(scope,':ACQuire:NUMACq?',logPath);

                assert(isfinite(nAcq) && nAcq >= 1, ...
                    'Nu exista achizitie noua valida.');

                nSamples = numQuery(scope,':ACQuire:POINts?',logPath);
                sampleRate = numQuery(scope,':ACQuire:SRATe?',logPath);

                assert(sampleRate/f(i) >= cfg.minSamplesPerCycle, ...
                    'Rata de esantionare insuficienta.');

                assert(nSamples/sampleRate*f(i) >= 2, ...
                    'Fereastra contine sub doua perioade.');

                m = readMeasurements(scope,logPath);

                % Asteptam finalizarea calculelor interne, daca este cazul.
                if ~validMeasurements(m,f(i),cfg)
                    pause(0.1);
                    m = readMeasurements(scope,logPath);
                end

                %% Adaptarea scalelor verticale

                newScale = scale;

                for ch = 1:2

                    if isfinite(m(ch)) && m(ch) > 0 && m(ch) < 100

                        peakBound = abs(m(4+ch)) + m(ch)/2;

                        if peakBound > 3.5*scale(ch)

                            newScale(ch) = chooseScale( ...
                                max(2*scale(ch),peakBound/2.5), ...
                                cfg.probe(ch));

                        elseif m(ch) < 2*scale(ch)

                            newScale(ch) = chooseScale( ...
                                max(m(ch)/5,peakBound/2.5), ...
                                cfg.probe(ch));

                        end

                    end

                end

                if isequal(newScale,scale) && validMeasurements(m,f(i),cfg)
                    break
                end

                if attempts < cfg.maxAttempts
                    scale = newScale;
                end

            end

        end

        %% 6. Calculul castigului si fazei

        r = swea_reduce(m,cfg,f(i),calc);

        if cfg.mode == "demo"
            r.status = "SYNTHETIC_" + r.status;
        end

        if cfg.mode == "usb"

            peakBound = abs(m(5:6)) + m(1:2)/2;

            if any(peakBound > 3.5*scale)

                r.status = r.status + "|SCREEN_RANGE_SUSPECT";

                r.gain = NaN;
                r.gainDB = NaN;
                r.phase = NaN;

            end

        end

        %% 7. Salvarea punctului

        row = table( ...
            i,f(i),m(7),m(1),m(2),m(3),m(4),m(5),m(6), ...
            r.vinAC,r.voutAC,r.gain,r.gainDB,m(8),r.phase, ...
            scale(1),scale(2),actualTimeScale,nSamples,sampleRate, ...
            attempts,toc(pointStarted),modeTag,r.status, ...
            'VariableNames',{ ...
            'Index','FrequencySet_Hz','FrequencyMeasured_Hz', ...
            'Vin_Vpp','Vout_Vpp','Vin_CRMS_V','Vout_CRMS_V', ...
            'Vin_CMean_V','Vout_CMean_V','Vin_ACRMS_V','Vout_ACRMS_V', ...
            'Gain_VV','Gain_dB','DelayRise_s','Phase_deg', ...
            'CH1_Vdiv','CH2_Vdiv','Time_sdiv','Samples','SampleRate_Hz', ...
            'Attempts','MeasurementTime_s','Mode','Status'});

        appendTable(row,fullfile(outDir,'measurements.csv'));

        results = [results; row]; %#ok<AGROW>

        if i == 1 || mod(i,25) == 0 || i == numel(f)

            fprintf('%d/%d | %.6g Hz | %.3f dB | %s | %.1f s\n', ...
                i,numel(f),f(i),r.gainDB,r.status,toc(started));

        end

    end

    %% 8. Oprirea aparatelor inaintea graficelor

    stopInstrument(gen,'C1:OUTP OFF');
    stopInstrument(scope,':TRIGger:STOP');

    %% 9. Salvarea rezultatelor finale

    save(fullfile(outDir,'results.mat'),'results','cfg');

    cutoff = swea_cutoff( ...
        results.FrequencySet_Hz,results.Gain_dB,cfg);

    if cfg.mode == "demo"
        cutoff.Status = "SYNTHETIC_" + cutoff.Status;
    end

    writetable(cutoff,fullfile(outDir,'cutoff.csv'));

    plotResults(results,outDir,modeTag,cutoff);

    disp(cutoff);

    writeText(fullfile(outDir,'completed.txt'), ...
        sprintf('Mode: %s\nPoints: %d\nElapsed_s: %.3f\n', ...
        modeTag,height(results),toc(started)));

catch ME

    % Incercam oprirea aparatelor si pastram rezultatele disponibile.
    stopInstrument(gen,'C1:OUTP OFF');
    stopInstrument(scope,':TRIGger:STOP');

    save(fullfile(outDir,'partial_results.mat'),'results','cfg');

    writeText(fullfile(outDir,'FAILED.txt'), ...
        getReport(ME,'extended','hyperlinks','off'));

    rethrow(ME)

end

fprintf('Rezultate: %s\n',outDir);

end


%% Oprirea unui aparat
function stopInstrument(instrument,command)

if isempty(instrument)
    return
end

try
    writeline(instrument,command);
catch err
    warning('SwEA:Shutdown', ...
        'Comanda %s a esuat: %s',command,err.message);
end

end


%% Deschiderea conexiunii VISA
function v = openInstrument(resource,model,cfg,logPath)

if strlength(resource) == 0

    dev = visadevlist;

    normalized = erase(upper(string(dev.Model)),[" ","-"]);

    match = normalized == erase(upper(model),[" ","-"]) & ...
        startsWith(string(dev.ResourceName),"USB");

    assert(nnz(match) == 1, ...
        'Selectati explicit adresa USB pentru %s; gasite %d.', ...
        model,nnz(match));

    resource = string(dev.ResourceName(find(match,1)));

end

assert(startsWith(resource,"USB"), ...
    'Acest profil necesita resurse USB VISA.');

v = visadev(resource);
v.Timeout = cfg.minTimeoutS;

configureTerminator(v,"LF");

id = query(v,'*IDN?',logPath);
parts = split(strtrim(id),',');

assert(numel(parts) >= 4 && ...
    contains(upper(parts(1)),"SIGLENT") && ...
    erase(upper(parts(2)),[" ","-"]) == erase(upper(model),[" ","-"]), ...
    'Identitate aparat neasteptata: %s',id);

if model == "SDS824X HD"

    token = regexp(char(parts(4)),'\d+','match');
    rev = str2double(token);
    minimum = [1 1 3 1];

    assert(numel(rev) >= 4, ...
        'Firmware necunoscut: verificati manual %s.',parts(4));

    first = find(rev(1:4) ~= minimum,1);

    assert(isempty(first) || rev(first) > minimum(first), ...
        'Firmware sub 1.1.3.1.');

end

fprintf('%s\n',id);

end


%% Configurarea generatorului si osciloscopului
function configureHardware(g,s,c,logPath)

% Generator: sinus, High-Z, fara modulatie, sweep sau burst.
send(g,'C1:OUTP LOAD,HZ,PLRT,NOR',logPath);
send(g,'C1:MDWV STATE,OFF',logPath);
send(g,'C1:SWWV STATE,OFF',logPath);
send(g,'C1:BTWV STATE,OFF',logPath);

send(g,sprintf( ...
    'C1:BSWV WVTP,SINE,FRQ,%.12g,AMP,%.12g,OFST,0', ...
    c.fStart,c.vinVpp),logPath);

basic = query(g,'C1:BSWV?',logPath);
output = query(g,'C1:OUTP?',logPath);

assert(contains(upper(basic),"WVTP,SINE") && ...
    contains(upper(output),"LOAD,HZ"), ...
    'Generatorul nu a confirmat sinus si sarcina High-Z.');

amp = regexp(char(basic), ...
    'AMP,([-+0-9.eE]+)','tokens','once');

assert(~isempty(amp) && ...
    abs(str2double(amp{1})/c.vinVpp - 1) < 1e-4, ...
    'Generatorul nu a confirmat amplitudinea solicitata.');

% Osciloscop: achizitie normala YT.
send(s,':TRIGger:STOP',logPath);
send(s,':ACQuire:MODE YT',logPath);
send(s,':ACQuire:SEQuence OFF',logPath);
send(s,':ACQuire:TYPE NORMal',logPath);
send(s,':ACQuire:MDEPth 10k',logPath);
send(s,':TIMebase:DELay 0',logPath);

% CH1 = intrare; CH2 = iesire.
for ch = 1:2

    prefix = sprintf(':CHANnel%d:',ch);

    send(s,[prefix 'SWITch ON'],logPath);
    send(s,[prefix 'COUPling DC'],logPath);
    send(s,[prefix 'INVert OFF'],logPath);
    send(s,[prefix 'BWLimit FULL'],logPath);
    send(s,[prefix 'OFFSet 0'],logPath);

    send(s,[prefix sprintf('PROBe VALue,%g',c.probe(ch))],logPath);

    probeRead = numQuery(s,[prefix 'PROBe?'],logPath);

    assert(abs(probeRead - c.probe(ch)) < 1e-9, ...
        'Sonda neconfigurata.');

    coupling = strtrim(query(s,[prefix 'COUPling?'],logPath));

    assert(strcmpi(coupling,'DC'), ...
        'Cuplaj incorect.');

end

send(s,':CHANnel3:SWITch OFF',logPath);
send(s,':CHANnel4:SWITch OFF',logPath);

% Trigger pe frontul crescator al intrarii.
send(s,':TRIGger:TYPE EDGE',logPath);
send(s,':TRIGger:EDGE:SOURce C1',logPath);
send(s,':TRIGger:EDGE:SLOPe RISing',logPath);
send(s,':TRIGger:EDGE:COUPling DC',logPath);
send(s,':TRIGger:EDGE:LEVel 0',logPath);
send(s,':TRIGger:EDGE:HOLDoff OFF',logPath);

% Masuratori avansate.
send(s,':MEASure ON',logPath);
send(s,':MEASure:MODE ADVanced',logPath);
send(s,':MEASure:GATE OFF',logPath);
send(s,':MEASure:ADVanced:STATistics OFF',logPath);
send(s,':MEASure:ADVanced:CLEar',logPath);

for ch = 1:2

    send(s,sprintf(':MEASure:THReshold:SOURce C%d',ch),logPath);
    send(s,':MEASure:THReshold:TYPE PERCent',logPath);
    send(s,':MEASure:THReshold:PERCent 90,50,10',logPath);

end

types = ["PKPK","PKPK","CRMS","CRMS","CMEAN","CMEAN","FREQ","FRR"];
sources = [1 2 1 2 1 2 1 1];

for n = 1:numel(types)

    p = sprintf(':MEASure:ADVanced:P%d',n);

    send(s,[p sprintf(':SOURce1 C%d',sources(n))],logPath);

    if n == 8
        send(s,[p ':SOURce2 C2'],logPath);
    end

    send(s,[p ':TYPE ' char(types(n))],logPath);
    send(s,[p ' ON'],logPath);

    measuredType = strtrim(query(s,[p ':TYPE?'],logPath));

    assert(strcmpi(measuredType,types(n)), ...
        'Tipul masurarii P%d nu a fost acceptat.',n);

end

assert(strtrim(query(s,'*OPC?',logPath)) == "1", ...
    'Configurarea nu s-a incheiat.');

end


%% Asteptarea finalizarii achizitiei SINGLE
function waitSingle(s,timeout,logPath)

t = tic;

while toc(t) < timeout

    state = strtrim(query(s,':TRIGger:STATus?',logPath));

    if strcmpi(state,'Stop')
        return
    end

    if strcmpi(state,'Roll')
        error('SwEA:Roll', ...
            'Achizitia este in ROLL, nu YT.');
    end

    pause(0.05);

end

error('SwEA:Timeout', ...
    'SINGLE nu s-a incheiat in %.1f s.',timeout);

end


%% Citirea celor opt masuratori
function m = readMeasurements(s,logPath)

m = nan(1,8);

for n = 1:8

    m(n) = numQuery(s, ...
        sprintf(':MEASure:ADVanced:P%d:VALue?',n),logPath);

end

end


%% Verificarea preliminara a masuratorilor
function ok = validMeasurements(m,f,c)

ok = all(isfinite(m)) && ...
    all(abs(m) < 1e20) && ...
    all(m(1:4) > 0) && ...
    all(m(3:4).^2 > m(5:6).^2) && ...
    abs(m(7)/f - 1) <= c.frequencyTolerance && ...
    abs(m(8)*m(7)) <= 1.05;

end


%% Rotunjire in sus la o valoare din seria 1-2-5
function x = nice125(x)

p = 10^floor(log10(x));

values = p*[1 2 5 10];

x = values(find(values >= x*(1-1e-12),1));

end


%% Alegerea scalei verticale
function s = chooseScale(s,probe)

s = nice125(max(s,0.001*probe));

assert(s <= 10*probe, ...
    'Scala solicitata depaseste profilul implementat.');

end


%% Trimiterea unei comenzi
function send(v,cmd,logPath)

writeline(v,cmd);

appendLog(logPath,"> " + string(cmd));

end


%% Trimiterea unei interogari
function answer = query(v,cmd,logPath)

answer = string(writeread(v,cmd));

appendLog(logPath, ...
    "> " + string(cmd) + " | < " + strtrim(answer));

end


%% Citirea unui raspuns numeric
function x = numQuery(v,cmd,logPath)

x = str2double(strtrim(query(v,cmd,logPath)));

if ~isfinite(x) || abs(x) > 1e20
    x = NaN;
end

end


%% Adaugarea unei linii in jurnal
function appendLog(path,line)

fid = fopen(path,'a');

assert(fid >= 0, ...
    'Nu se poate deschide jurnalul.');

cleanupFile = onCleanup(@()fclose(fid)); %#ok<NASGU>

fprintf(fid,'%s %s\n', ...
    char(datetime('now','Format','HH:mm:ss.SSS')),char(line));

end


%% Scrierea unui fisier text
function writeText(path,text)

fid = fopen(path,'w');

assert(fid >= 0, ...
    'Nu se poate scrie %s.',path);

cleanupFile = onCleanup(@()fclose(fid)); %#ok<NASGU>

fprintf(fid,'%s',text);

end


%% Salvarea progresiva in CSV
function appendTable(t,path)

if isfile(path)

    writetable(t,path, ...
        'WriteMode','append','WriteVariableNames',false);

else

    writetable(t,path);

end

end


%% Graficul Bode final
function plotResults(t,outDir,tag,cutoff)

fig = figure('Visible','off');

cleanupFigure = onCleanup(@()close(fig)); %#ok<NASGU>

yyaxis left

semilogx(t.FrequencySet_Hz,t.Gain_dB,'LineWidth',1.3);

ylabel('Amplificare [dB]');
grid on;

yyaxis right

semilogx(t.FrequencySet_Hz,t.Phase_deg,'LineWidth',1.3);

ylabel('Faza iesire - intrare [grade]');
xlabel('Frecventa [Hz]');

title(tag + " - raspuns in bucla inchisa", ...
    'Interpreter','none');

if startsWith(tag,"DEMO")
    title('DEMO SINTETIC - model ilustrativ cu un pol');
end

if isfinite(cutoff.Cutoff_Hz)

    xline(cutoff.Cutoff_Hz,'--', ...
        sprintf('f_{-3dB} = %.4g Hz',cutoff.Cutoff_Hz));

end

exportgraphics(fig,fullfile(outDir,'bode.png'),'Resolution',180);

savefig(fig,fullfile(outDir,'bode.fig'));

end