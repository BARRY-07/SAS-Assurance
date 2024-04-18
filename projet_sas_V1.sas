
%let chemin=C:\Users\LENOVO\Downloads\donnees_projet_SAS_2024.csv; /* Veuillez changer le chemin */


/* Importation des données */
proc import datafile="&chemin."
     out=donnees_sinistres
     dbms=csv
     replace;
     getnames=no; 
     delimiter=';'; 
     datarow=2; /* Pour ne pas prendre en compte la ligne de noms initiale */
run;

/* Noms des variables */
data donnees_sinistres;
     set donnees_sinistres(rename=(VAR1=ID_ASS VAR2=DATE_SIN VAR3=GARANTIE VAR4=COUT_SIN VAR5=REC_SIN VAR6=PMT_SIN VAR7=PRIME_ANN));
run;


/* 2-Création de la variable BRANCHE */
data donnees_sinistres;
     set donnees_sinistres;
     if 'A' <= GARANTIE <= 'M' then BRANCHE="Dommages aux biens";
     else if 'N' <= GARANTIE <= 'Z' then BRANCHE="Santé des personnes";
run;

/* 3-Création de la variable ID_SIN */
data donnees_sinistres;
     set donnees_sinistres;
     ID_SIN=catx("", substr(put(year(DATE_SIN),4.),3,2), GARANTIE, substr(ID_ASS, length(ID_ASS)-3, 4));
run;


/* 4-Calcul des provisions et des provisions nettes de recours */
data donnees_sinistres;
     set donnees_sinistres;
     PROV_SIN=COUT_SIN-PMT_SIN; /* Reste â payer */
     PROV_SIN_NETTE=PROV_SIN-REC_SIN; /* Net des recours */
     if PROV_SIN_NETTE < 0 then PROV_SIN_NETTE=0; /* La provision nette ne peut pas être négative */
run;

/* 5-a) : Calcul du ratio S/C pour chaque sinistre */
data donnees_sinistres;
     set donnees_sinistres;
     SIN_COT=COUT_SIN/PRIME_ANN; /* Coût du sinistre divisé par la cotisation */
run;

/* 5-b) : Moyenne du ratio S/C par garantie */
proc sql;
     create table moyenne_sc_par_garantie as
     select GARANTIE, mean(SIN_COT) as moyenne_sc
     from donnees_sinistres
     group by GARANTIE;
quit;

/* 5-c) : Moyenne du ratio S/C par branche */
proc sql;
     create table moyenne_sc_par_branche as
     select BRANCHE, mean(SIN_COT) as moyenne_sc
     from donnees_sinistres
     group by BRANCHE;
quit;

/* 5-d) D'après les résultats obtenus, la branche 'Dommages aux biens' 
avec un ratio S/C de 1.42546 est relativement plus rentable que la branche 'Santé des personnes' 
qui a un ratio S/C de 1.53657. Ceci est dû au fait que pour la branche 'Dommages aux biens', 
le montant des sinistres payés est moins élevé par rapport aux cotisations recues que pour 
la branche 'Santé des personnes'. */

/* 6-a) Filtrage des sinistres avec une charge supérieure à  2500*/
data TOP_SIN;
     set donnees_sinistres;
     COUT_SIN = floor(COUT_SIN);
     if COUT_SIN > 2500;
     keep GARANTIE ID_SIN COUT_SIN;
run;

/* 6-b) Tri des sinistres par coût décroissant */
proc sort data=TOP_SIN;
     by descending COUT_SIN;
run;

/* 7-Calcul du coût moyen d'un sinistre par garantie */
proc means data=TOP_SIN noprint nway;
    class GARANTIE;
    var COUT_SIN;
    output out=SIN_MOYENS (drop=_TYPE_ _FREQ_) mean=cout_moyen;
run;

/* 8-Total des provisions nettes par branche */
proc means data=donnees_sinistres noprint nway;
    class BRANCHE;
    var PROV_SIN_NETTE;
    output out=PROV_PAR_BRANCHE (drop=_TYPE_ _FREQ_) sum(PROV_SIN_NETTE)=PROV_TOTALE;
run;

/* 9-Suppression de la table SIN_MOYENS */
proc datasets lib=work nolist;
     delete SIN_MOYENS;
quit;

/* Ajout de la variable DATE_OBS et calcul de l'ancienneté */
data SASUSER.ANCIENNETE_SIN;
    set donnees_sinistres;

    /* Convertion de DATE_SIN en dates normales */
    DATE_SINISTRE = DATE_SIN + '01JAN1960'd;
    format DATE_SINISTRE ddmmyy10.; /*format JOUR/MOIS/ANNEE */

    /*date de rendu du projet et formatage */
    DATE_OBS = '11APR2024'd;
    format DATE_OBS ddmmyy10.;

    /* ancienneté des sinistres en années */
    ANCIENNETE = intck('year', DATE_SINISTRE, DATE_OBS) - (DATE_OBS < DATE_SINISTRE);

    /*tranche d'ancienneté*/
    if ANCIENNETE < 4 then TRANCHE_ANCIENNETE = "Moins de 4 ans";
    else TRANCHE_ANCIENNETE = "4 ans et plus";
run;

/*SYNTHESE: Le nombre de sinistres par branche, garantie et tranche d'ancienneté*/
proc freq data=SASUSER.ANCIENNETE_SIN noprint;
    tables BRANCHE*GARANTIE*TRANCHE_ANCIENNETE / out=SYNTHESE_FINALE;
run;















