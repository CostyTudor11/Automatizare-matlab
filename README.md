# SwEA — Caracterizarea automată a unui amplificator cu TL082

Proiect MATLAB pentru măsurarea automată a răspunsului în frecvență al unui amplificator neinversor cu TL082.

MATLAB controlează prin USB un generator de semnal și un osciloscop, măsoară intrarea și ieșirea circuitului și generează graficul Bode: câștig și fază în funcție de frecvență.

**Rezultatul principal:** baleiaj real între **1 Hz și 5 MHz**, cu **671 de puncte** și o frecvență de tăiere calculată de **2,3224 MHz**.

> Proiectul caracterizează montajul real în buclă închisă, cu sondele conectate. Nu măsoară direct câștigul în buclă deschisă sau GBW-ul intern al TL082.

## Ce face automatizarea

1. Identifică generatorul și osciloscopul.
2. Configurează semnalul sinusoidal și canalele de măsurare.
3. Parcurge frecvențele distribuite logaritmic.
4. Adaptează baza de timp și scalele verticale.
5. Așteaptă stabilizarea și execută o achiziție SINGLE.
6. Citește măsurătorile și calculează câștigul și faza.
7. Salvează progresiv datele în CSV.
8. Încearcă oprirea generatorului la final sau la întrerupere.
9. Calculează frecvența de tăiere și salvează graficul final.

Nu se salvează câte o captură a osciloscopului la fiecare frecvență. Graficul final este construit în MATLAB.

## Echipamente și montaj

| Element | Configurație |
|---|---|
| Amplificator operațional | TL082 |
| Montaj | Neinversor, realizat pe breadboard |
| Alimentare | ±10 V |
| Rezistență de reacție Rf | 10 kΩ |
| Rezistență către masă Rg | 10 kΩ |
| Câștig nominal | 1 + Rf/Rg = 2 V/V ≈ 6,02 dB |
| Generator | SIGLENT SDG1032X |
| Osciloscop | SIGLENT SDS824X HD |
| Semnal | Sinus, 500 mVpp setați pe generator, offset zero |
| Sonde | ×1 pe ambele canale |
| Cuplaj osciloscop | DC |
| Sarcină externă | Sonda osciloscopului |

Rețeaua de reacție încarcă și ea ieșirea amplificatorului.

### Conexiuni

| De la | Către |
|---|---|
| Generator CH1 | Intrarea neinversoare |
| Osciloscop CH1 | Intrarea amplificatorului |
| Osciloscop CH2 | Ieșirea amplificatorului |
| Rf | Între ieșire și intrarea inversoare |
| Rg | Între intrarea inversoare și masa circuitului |
| Masele generatorului și sondelor | Masa comună de 0 V |
| USB Device generator | Laptop |
| USB Device osciloscop | Laptop |

**Masele sondelor se conectează la 0 V, nu la −10 V.**

Verifică pinout-ul capsulei, polaritățile și decuplarea alimentării înainte de pornire. Factorii configurați în MATLAB trebuie să corespundă comutatoarelor fizice ale sondelor.

Sursa de alimentare este configurată manual; scriptul nu o controlează.

## Cerințe software

Proiectul a fost rulat pe Windows 11, în MATLAB R2026b.

Sunt necesare:

- MATLAB;
- Instrument Control Toolbox;
- Symbolic Math Toolbox pentru `SwEA.m`;
- o implementare VISA compatibilă.

În acest proiect s-a folosit NI-VISA. Detectarea aparatelor a fost verificată în NI MAX și apoi în MATLAB.

Componentele „VISA Shared Components” nu confirmă singure existența unei implementări VISA funcționale.

Firmware-urile raportate de aparatele utilizate:

| Aparat | Firmware |
|---|---|
| SDG1032X | `1.01.01.33R8` |
| SDS824X HD | `4.8.12.1.1.6.5` |

Compatibilitatea cu alte modele sau firmware-uri necesită verificarea comenzilor SCPI.

## Organizarea codului

Păstrează toate fișierele MATLAB în același folder.

| Fișier | Rol |
|---|---|
| `SwEA.m` | Script principal: parametri, formule simbolice și pornirea măsurării |
| `swea_config.m` | Setări implicite, toleranțe, timpi și model demonstrativ |
| `run_swea.m` | Comunicație USB, achiziție, salvare și generarea graficului |
| `swea_frequencies.m` | Construirea grilei de frecvențe |
| `swea_reduce.m` | Calculul câștigului/fazei și verificarea datelor |
| `swea_cutoff.m` | Determinarea frecvenței de tăiere |
| `swea_numeric_formulas.m` | Formule numerice pentru apeluri directe și teste |
| `test_swea.m` | Teste fără aparate |

## 1. Verificarea fără aparate

Deschide folderul proiectului în MATLAB și rulează:

```matlab
test_swea
```

Testele verifică grila de frecvențe, calculele, tratarea unor date invalide și generarea fișierelor.

**Aceste teste nu validează aparatele USB.** Rezultatele temporare ale testului sunt șterse automat la ieșire.

Pentru o demonstrație cu rezultate păstrate, setează în `SwEA.m`:

```matlab
mod_lucru = "demo";
```

Apoi apasă Run.

Modelul demonstrativ are câștigul 2 și un pol la 1,5 MHz. Acestea sunt date sintetice, nu măsurători ale circuitului.

Folderele DEMO au prefixul `DEMO_SYNTHETIC`, iar stările măsurătorilor au prefixul `SYNTHETIC_`.

## 2. Verificarea conexiunilor USB

Pornește aparatele și conectează fiecare port USB Device la laptop.

Verifică detectarea în NI MAX, apoi rulează în MATLAB:

```matlab
devices = visadevlist;
disp(devices)
```

Trebuie să apară SDG1032X și SDS824X HD.

În `SwEA.m`, șirurile goale permit identificarea automată după model:

```matlab
cfg.generatorResource = "";
cfg.scopeResource = "";
```

Dacă există mai multe aparate cu același model, completează explicit adresele `ResourceName` returnate de `visadevlist`.

Nu copia adrese USB de la un alt banc: acestea includ identificatori specifici instrumentelor.

## 3. Prima probă pe montaj

Verifică manual montajul cu un sinus de 1 kHz:

- aproximativ 500 mVpp măsurați la intrare;
- aproximativ 1 Vpp la ieșire;
- fără deformare evidentă.

Pentru o probă automată scurtă, rulează în Command Window:

```matlab
cfg = swea_config();

cfg.mode = "usb";
cfg.vinVpp = 0.500;
cfg.offsetV = 0;
cfg.probe = [1 1];

cfg.fStart = 100;
cfg.fStop = 10000;
cfg.frequencyOverride = [100 1000 10000];

[rezultate, folder_rezultate] = run_swea(cfg);

disp(rezultate(:, {'FrequencySet_Hz','Vin_Vpp','Vout_Vpp', ...
    'Gain_dB','Phase_deg','Status'}))
```

Comanda pornește efectiv ieșirea generatorului.

Cu numai trei puncte, mesajul `INSUFFICIENT_PLATEAU_DATA` pentru frecvența de tăiere este explicabil și nu reprezintă o eroare de comunicație.

Verifică oprirea CH1 la final.

## 4. Baleiajul complet din SwEA.m

Setează:

```matlab
mod_lucru = "usb";
Vin_Vpp = 0.500;

f_min = 1;
f_max = 5e6;
puncte_pe_decada = 100;

semnal = "SINE";
R_feedback = 10e3;
R_masa = 10e3;
sonde = [1 1];
```

După `cfg = swea_config();`, păstrează:

```matlab
cfg.frequencyOverride = [];
```

Salvează și apasă **Run în SwEA.m**.

Setările introduse anterior în Command Window nu înlocuiesc parametrii reconstruiți de `SwEA.m`.

La frecvențe joase măsurarea este lentă: la 1 Hz, cinci perioade ocupă cinci secunde, la care se adaugă stabilizarea și comunicația. Nu modifica setările aparatelor în timpul rulării.

La final, verifică dacă generatorul este OFF. Dacă întrerupi măsurarea și ieșirea rămâne activă, oprește-o manual.

Punctele deja scrise în CSV se păstrează. Fișierele finale nu sunt garantate după întrerupere, iar programul nu implementează reluarea automată a unei rulări incomplete.

## Metoda de calcul

Componenta alternativă RMS este estimată separat pentru fiecare canal:

```text
V_AC_RMS = sqrt(V_CRMS^2 - V_CMean^2)
```

Câștigul este:

```text
G = Vout_AC_RMS / Vin_AC_RMS
G_dB = 20 * log10(G)
```

Se folosește intrarea efectiv măsurată, nu valoarea nominală de 500 mVpp.

Vpp este salvat pentru verificări. Programul nu ajustează repetat generatorul pentru a menține exact 500 mVpp la intrarea circuitului.

Faza este definită ca:

```text
faza = faza_iesire - faza_intrare
```

Codul folosește întârzierea dintre fronturile crescătoare și relația:

```text
faza_grade = -360 * frecventa * intarziere
```

Normalizarea fazei este realizată în funcția de prelucrare. Semnul returnat de lanțul de măsurare necesită o verificare experimentală cu o întârziere cunoscută.

### Frecvența de tăiere

Pragul este cu **3,0103 dB sub platoul măsurat**, nu sub maximul curbei.

Banda de referință configurată este 10–1000 Hz. La un baleiaj început la 100 Hz sunt disponibile numai punctele din 100–1000 Hz.

Trecerea pragului este interpolată în dB față de logaritmul frecvenței. Dacă datele nu permit determinarea tăierii, se salvează `NaN` și o stare explicativă.

## Fișiere generate

Rezultatele sunt salvate într-un subfolder unic din `rezultate_SwEA`, lângă `SwEA.m`.

| Fișier | Conținut |
|---|---|
| `measurements.csv` | Datele fiecărei frecvențe și stările verificărilor |
| `cutoff.csv` | Frecvența de tăiere și starea calculului |
| `bode.png` | Grafic final: amplitudine roșie, fază albastră |
| `bode.fig` | Figura editabilă în MATLAB |
| `config.json`, `config.mat` | Configurația rulării |
| `results.mat` | Tabelul rezultatelor și configurația |
| `instrument_log.txt` | Comenzile și răspunsurile instrumentelor |
| `completed.txt` | Modul, numărul de puncte și durata |
| `partial_results.mat`, `FAILED.txt` | Date parțiale și eroarea, dacă excepția este capturată |

Citirea CSV-urilor cu separator explicit:

```matlab
folder = 'calea folderului cu rezultate';

t = readtable(fullfile(folder,'measurements.csv'),'Delimiter',',');
c = readtable(fullfile(folder,'cutoff.csv'),'Delimiter',',');

disp(c)

suspect = string(t.Status) ~= "OK";
disp(t(suspect, {'FrequencySet_Hz','Gain_dB','Phase_deg','Status'}))
```

### Stări importante

| Stare | Semnificație |
|---|---|
| `OK` | Punctul a trecut verificările software |
| `SYNTHETIC_OK` | Date demonstrative |
| `INPUT_NOT_AT_TARGET` | Intrarea se abate de la amplitudinea țintă |
| `CHECK_WAVEFORM_OR_NOISE` | Verificarea Vpp/RMS nu a trecut |
| `FREQUENCY_MISMATCH` | Frecvența măsurată diferă peste toleranță |
| `SCREEN_RANGE_SUSPECT` | Încadrare verticală suspectă |
| `OK_WITH_INVALID_POINTS_ELSEWHERE` | Tăiere calculată, dar există puncte invalide în alte zone |

Stările se pot combina. `INPUT_NOT_AT_TARGET` nu invalidează automat raportul tensiunilor măsurate.

Valorile `NaN` apar ca întreruperi în grafic. Nu sunt înlocuite cu valori inventate.

## Rezultatul principal — 1 Hz–5 MHz

Măsurare efectuată la **18 octombrie 2026**.

| Parametru | Rezultat |
|---|---|
| Număr de puncte | 671 |
| Câștig în bandă | Aproximativ 5,95–5,98 dB |
| Frecvență de tăiere | **2,3224 MHz** |
| Stare tăiere | `OK_WITH_INVALID_POINTS_ELSEWHERE` |
| Maxim observat | Aproximativ 8,05 dB în zona 1,26–1,29 MHz |
| Punct invalid | Aproximativ 3,7154 MHz |
| Stare punct invalid | `INPUT_NOT_AT_TARGET|CHECK_WAVEFORM_OR_NOISE` |

Curba prezintă un maxim înainte de cădere. Cauza nu a fost izolată experimental; maximul nu dovedește singur existența unei oscilații.

### Rulări suplimentare

| Rulare | Interval | Frecvență de tăiere |
|---|---|---|
| Prima | 100 Hz–5 MHz | 2,543 MHz |
| Principală | 1 Hz–5 MHz | 2,3224 MHz |
| Repetare | 100 Hz–5 MHz | 2,4271 MHz |

Cele două rulări cu același interval diferă cu aproximativ 4,6%, raportat la prima. Cauza variației nu a fost stabilită.

Rulările suplimentare sunt păstrate pentru comparație. Valorile lor nu sunt amestecate cu rezultatul principal.

## Limitele proiectului

- Rezultatul include efectele montajului pe breadboard, ale cablurilor și sondelor.
- Modelul și banda sondelor în ×1 nu au fost documentate.
- Nu a fost demonstrată o calibrare completă între canale sau validarea experimentală a semnului fazei.
- Nu a fost realizat un buget formal de incertitudine.
- Starea `OK` confirmă numai verificările implementate, nu precizia absolută.
- Modelul DEMO cu un singur pol nu este un model complet al TL082 și al montajului.
- La frecvențe mari au apărut avertizări de amplitudine și puncte invalidate.

## Depanare

**Aparatele nu apar în MATLAB:** verifică porturile USB Device, cablurile, instalarea VISA și detectarea în NI MAX.

**Apare eroarea `onCleanup` despre variabila `gen`:** folosește versiunea corectată `run_swea.m`, care transmite obiectele explicit funcțiilor de oprire.

**Apar avertizări de rotunjire a timeout-ului:** valoarea poate fi rotunjită în sus cu `ceil`. Aceasta nu accelerează achiziția.

**Graficul are întreruperi:** verifică stările și valorile `NaN` din `measurements.csv`.

**CSV-ul este împărțit în coloane greșite:** folosește explicit `'Delimiter',','` la `readtable`.

## Publicarea pe GitHub

Păstrează separat rezultatele DEMO și USB. Pentru rezultatul principal, publică împreună graficul, CSV-urile și configurația aceleiași rulări.

Verifică înainte de publicare căile locale și seriile aparatelor din configurații și jurnale. Aceste informații pot identifica mediul de lucru.